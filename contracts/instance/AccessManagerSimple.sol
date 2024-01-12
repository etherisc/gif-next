// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {IAccessManagerSimple} from "./IAccessManagerSimple.sol";

type Delay is uint112;

// @dev as oz5 AccessManager but without multicall and without timing logic
contract AccessManagerSimple is Context, IAccessManagerSimple {
    // Structure that stores the details for a target contract.
    struct TargetConfig {
        mapping(bytes4 selector => uint64 roleId) allowedRoles;
        uint112 adminDelay;
        bool closed;
    }

    // Structure that stores the details for a role/account pair. This structures fit into a single slot.
    struct Access {
        // Timepoint at which the user gets the permission.
        // If this is either 0 or in the future, then the role permission is not available.
        uint48 since;
        // Delay for execution. Only applies to restricted() / execute() calls.
        Delay delay;
    }

    // Structure that stores the details of a role.
    struct Role {
        // Members of the role.
        mapping(address user => Access access) members;
        // Admin who can grant or revoke permissions.
        uint64 admin;
        // Guardian who can cancel operations targeting functions that need this role.
        uint64 guardian;
        // Delay in which the role takes effect after being granted.
        Delay grantDelay;
    }

    // Structure that stores the details for a scheduled operation. This structure fits into a single slot.
    struct Schedule {
        // Moment at which the operation can be executed.
        uint48 timepoint;
        // Operation nonce to allow third-party contracts to identify the operation.
        uint32 nonce;
    }

    uint64 public constant ADMIN_ROLE = type(uint64).min; // 0
    uint64 public constant PUBLIC_ROLE = type(uint64).max; // 2**64-1

    mapping(address target => TargetConfig mode) private _targets;
    mapping(uint64 roleId => Role) private _roles;
    mapping(bytes32 operationId => Schedule) private _schedules;

    // Used to identify operations that are currently being executed via {execute}.
    // This should be transient storage when supported by the EVM.
    bytes32 private _executionId;

    /**
     * @dev Check that the caller is authorized to perform the operation, following the restrictions encoded in
     * {_getAdminRestrictions}.
     */
    modifier onlyAuthorized() {
        _checkAuthorized();
        _;
    }

    constructor(address initialAdmin) {
        if (initialAdmin == address(0)) {
            revert AccessManagerInvalidInitialAdmin(address(0));
        }

        // admin is active immediately and without any execution delay.
        _grantRole(ADMIN_ROLE, initialAdmin, 0, 0);
    }

    // =================================================== GETTERS ====================================================
    /// @inheritdoc IAccessManagerSimple
    function canCall(
        address caller,
        address target,
        bytes4 selector
    ) public view virtual returns (bool immediate, uint32 delay) {
        if (isTargetClosed(target)) {
            return (false, 0);
        // } else if (caller == address(this)) {
        //     // Caller is AccessManager, this means the call was sent through {execute} and it already checked
        //     // permissions. We verify that the call "identifier", which is set during {execute}, is correct.
        //     return (_isExecuting(target, selector), 0);
        } else {
            uint64 roleId = getTargetFunctionRole(target, selector);
            (bool isMember, uint32 currentDelay) = hasRole(roleId, caller);
            return isMember ? (currentDelay == 0, currentDelay) : (false, 0);
        }
    }

    /// @inheritdoc IAccessManagerSimple
    function expiration() public view virtual returns (uint32) {
        return 1 weeks;
    }

    /// @inheritdoc IAccessManagerSimple
    function minSetback() public view virtual returns (uint32) {
        return 5 days;
    }

    /// @inheritdoc IAccessManagerSimple
    function isTargetClosed(address target) public view virtual returns (bool) {
        return _targets[target].closed;
    }

    /// @inheritdoc IAccessManagerSimple
    function getTargetFunctionRole(address target, bytes4 selector) public view virtual returns (uint64) {
        return _targets[target].allowedRoles[selector];
    }

    /// @inheritdoc IAccessManagerSimple
    function getTargetAdminDelay(address target) public view virtual returns (uint32) {
        // return _targets[target].adminDelay.get();
    }

    /// @inheritdoc IAccessManagerSimple
    function getRoleAdmin(uint64 roleId) public view virtual returns (uint64) {
        return _roles[roleId].admin;
    }

    /// @inheritdoc IAccessManagerSimple
    function getRoleGuardian(uint64 roleId) public view virtual returns (uint64) {
        return _roles[roleId].guardian;
    }

    /// @inheritdoc IAccessManagerSimple
    function getRoleGrantDelay(uint64 roleId) public view virtual returns (uint32) {
        // return _roles[roleId].grantDelay.get();
    }

    /// @inheritdoc IAccessManagerSimple
    function getAccess(
        uint64 roleId,
        address account
    ) public view virtual returns (uint48 since, uint32 currentDelay, uint32 pendingDelay, uint48 effect) {
        Access storage access = _roles[roleId].members[account];

        since = access.since;
        // (currentDelay, pendingDelay, effect) = access.delay.getFull();

        return (since, currentDelay, pendingDelay, effect);
    }

    /// @inheritdoc IAccessManagerSimple
    function hasRole(
        uint64 roleId,
        address account
    ) public view virtual returns (bool isMember, uint32 executionDelay) {
        if (roleId == PUBLIC_ROLE) {
            return (true, 0);
        } else {
            (uint48 hasRoleSince, uint32 currentDelay, , ) = getAccess(roleId, account);
            // return (hasRoleSince != 0 && hasRoleSince <= Time.timestamp(), currentDelay);
            return (hasRoleSince != 0 && hasRoleSince <= uint48(block.timestamp), currentDelay);
        }
    }

    // =============================================== ROLE MANAGEMENT ===============================================
    /// @inheritdoc IAccessManagerSimple
    function labelRole(uint64 roleId, string calldata label) public virtual onlyAuthorized {
        if (roleId == ADMIN_ROLE || roleId == PUBLIC_ROLE) {
            revert AccessManagerLockedRole(roleId);
        }
        emit RoleLabel(roleId, label);
    }

    /// @inheritdoc IAccessManagerSimple
    function grantRole(uint64 roleId, address account, uint32 executionDelay) public virtual onlyAuthorized {
        _grantRole(roleId, account, getRoleGrantDelay(roleId), executionDelay);
    }

    /// @inheritdoc IAccessManagerSimple
    function revokeRole(uint64 roleId, address account) public virtual onlyAuthorized {
        _revokeRole(roleId, account);
    }

    /// @inheritdoc IAccessManagerSimple
    function renounceRole(uint64 roleId, address callerConfirmation) public virtual {
        if (callerConfirmation != _msgSender()) {
            revert AccessManagerBadConfirmation();
        }
        _revokeRole(roleId, callerConfirmation);
    }

    /// @inheritdoc IAccessManagerSimple
    function setRoleAdmin(uint64 roleId, uint64 admin) public virtual onlyAuthorized {
        _setRoleAdmin(roleId, admin);
    }

    /// @inheritdoc IAccessManagerSimple
    function setRoleGuardian(uint64 roleId, uint64 guardian) public virtual onlyAuthorized {
        _setRoleGuardian(roleId, guardian);
    }

    /// @inheritdoc IAccessManagerSimple
    function setGrantDelay(uint64 roleId, uint32 newDelay) public virtual onlyAuthorized {
        // _setGrantDelay(roleId, newDelay);
    }

    /**
     * @dev Internal version of {grantRole} without access control. Returns true if the role was newly granted.
     *
     * Emits a {RoleGranted} event.
     */
    function _grantRole(
        uint64 roleId,
        address account,
        uint32 grantDelay,
        uint32 executionDelay
    ) internal virtual returns (bool) {
        if (roleId == PUBLIC_ROLE) {
            revert AccessManagerLockedRole(roleId);
        }

        bool newMember = _roles[roleId].members[account].since == 0;
        uint48 since;

        if (newMember) {
            since = uint48(block.timestamp); // Time.timestamp() + grantDelay;
            _roles[roleId].members[account] = Access({since: since, delay: Delay.wrap(0)});
        }
        // else {
        //     // No setback here. Value can be reset by doing revoke + grant, effectively allowing the admin to perform
        //     // any change to the execution delay within the duration of the role admin delay.
        //     (_roles[roleId].members[account].delay, since) = _roles[roleId].members[account].delay.withUpdate(
        //         executionDelay,
        //         0
        //     );
        // }

        emit RoleGranted(roleId, account, executionDelay, since, newMember);
        return newMember;
    }

    /**
     * @dev Internal version of {revokeRole} without access control. This logic is also used by {renounceRole}.
     * Returns true if the role was previously granted.
     *
     * Emits a {RoleRevoked} event if the account had the role.
     */
    function _revokeRole(uint64 roleId, address account) internal virtual returns (bool) {
        if (roleId == PUBLIC_ROLE) {
            revert AccessManagerLockedRole(roleId);
        }

        if (_roles[roleId].members[account].since == 0) {
            return false;
        }

        delete _roles[roleId].members[account];

        emit RoleRevoked(roleId, account);
        return true;
    }

    /**
     * @dev Internal version of {setRoleAdmin} without access control.
     *
     * Emits a {RoleAdminChanged} event.
     *
     * NOTE: Setting the admin role as the `PUBLIC_ROLE` is allowed, but it will effectively allow
     * anyone to set grant or revoke such role.
     */
    function _setRoleAdmin(uint64 roleId, uint64 admin) internal virtual {
        if (roleId == ADMIN_ROLE || roleId == PUBLIC_ROLE) {
            revert AccessManagerLockedRole(roleId);
        }

        _roles[roleId].admin = admin;

        emit RoleAdminChanged(roleId, admin);
    }

    /**
     * @dev Internal version of {setRoleGuardian} without access control.
     *
     * Emits a {RoleGuardianChanged} event.
     *
     * NOTE: Setting the guardian role as the `PUBLIC_ROLE` is allowed, but it will effectively allow
     * anyone to cancel any scheduled operation for such role.
     */
    function _setRoleGuardian(uint64 roleId, uint64 guardian) internal virtual {
        if (roleId == ADMIN_ROLE || roleId == PUBLIC_ROLE) {
            revert AccessManagerLockedRole(roleId);
        }

        _roles[roleId].guardian = guardian;

        emit RoleGuardianChanged(roleId, guardian);
    }

    /**
     * @dev Internal version of {setGrantDelay} without access control.
     *
     * Emits a {RoleGrantDelayChanged} event.
     */
    // function _setGrantDelay(uint64 roleId, uint32 newDelay) internal virtual {
    //     if (roleId == PUBLIC_ROLE) {
    //         revert AccessManagerLockedRole(roleId);
    //     }

    //     uint48 effect;
    //     (_roles[roleId].grantDelay, effect) = _roles[roleId].grantDelay.withUpdate(newDelay, minSetback());

    //     emit RoleGrantDelayChanged(roleId, newDelay, effect);
    // }

    // ============================================= FUNCTION MANAGEMENT ==============================================
    /// @inheritdoc IAccessManagerSimple
    function setTargetFunctionRole(
        address target,
        bytes4[] calldata selectors,
        uint64 roleId
    ) public virtual onlyAuthorized {
        for (uint256 i = 0; i < selectors.length; ++i) {
            _setTargetFunctionRole(target, selectors[i], roleId);
        }
    }

    /**
     * @dev Internal version of {setTargetFunctionRole} without access control.
     *
     * Emits a {TargetFunctionRoleUpdated} event.
     */
    function _setTargetFunctionRole(address target, bytes4 selector, uint64 roleId) internal virtual {
        _targets[target].allowedRoles[selector] = roleId;
        emit TargetFunctionRoleUpdated(target, selector, roleId);
    }

    /// @inheritdoc IAccessManagerSimple
    function setTargetAdminDelay(address target, uint32 newDelay) public virtual onlyAuthorized {
        // _setTargetAdminDelay(target, newDelay);
    }

    /**
     * @dev Internal version of {setTargetAdminDelay} without access control.
     *
     * Emits a {TargetAdminDelayUpdated} event.
     */
    // function _setTargetAdminDelay(address target, uint32 newDelay) internal virtual {
    //     uint48 effect;
    //     (_targets[target].adminDelay, effect) = _targets[target].adminDelay.withUpdate(newDelay, minSetback());

    //     emit TargetAdminDelayUpdated(target, newDelay, effect);
    // }

    // =============================================== MODE MANAGEMENT ================================================
    /// @inheritdoc IAccessManagerSimple
    function setTargetClosed(address target, bool closed) public virtual onlyAuthorized {
        _setTargetClosed(target, closed);
    }

    /**
     * @dev Set the closed flag for a contract. This is an internal setter with no access restrictions.
     *
     * Emits a {TargetClosed} event.
     */
    function _setTargetClosed(address target, bool closed) internal virtual {
        if (target == address(this)) {
            revert AccessManagerLockedAccount(target);
        }
        _targets[target].closed = closed;
        emit TargetClosed(target, closed);
    }

    // ============================================== DELAYED OPERATIONS ==============================================
    /// @inheritdoc IAccessManagerSimple
    function getSchedule(bytes32 id) public view virtual returns (uint48) {
        // uint48 timepoint = _schedules[id].timepoint;
        // return _isExpired(timepoint) ? 0 : timepoint;
    }

    /// @inheritdoc IAccessManagerSimple
    function getNonce(bytes32 id) public view virtual returns (uint32) {
        // return _schedules[id].nonce;
    }

    /// @inheritdoc IAccessManagerSimple
    function schedule(
        address target,
        bytes calldata data,
        uint48 when
    ) public virtual returns (bytes32 operationId, uint32 nonce) {
        // address caller = _msgSender();

        // // Fetch restrictions that apply to the caller on the targeted function
        // (, uint32 setback) = _canCallExtended(caller, target, data);

        // uint48 minWhen = Time.timestamp() + setback;

        // // if call with delay is not authorized, or if requested timing is too soon
        // if (setback == 0 || (when > 0 && when < minWhen)) {
        //     revert AccessManagerUnauthorizedCall(caller, target, _checkSelector(data));
        // }

        // // Reuse variable due to stack too deep
        // when = uint48(Math.max(when, minWhen)); // cast is safe: both inputs are uint48

        // // If caller is authorised, schedule operation
        // operationId = hashOperation(caller, target, data);

        // _checkNotScheduled(operationId);

        // unchecked {
        //     // It's not feasible to overflow the nonce in less than 1000 years
        //     nonce = _schedules[operationId].nonce + 1;
        // }
        // _schedules[operationId].timepoint = when;
        // _schedules[operationId].nonce = nonce;
        // emit OperationScheduled(operationId, nonce, when, caller, target, data);

        // // Using named return values because otherwise we get stack too deep
    }

    /**
     * @dev Reverts if the operation is currently scheduled and has not expired.
     * (Note: This function was introduced due to stack too deep errors in schedule.)
     */
    // function _checkNotScheduled(bytes32 operationId) private view {
    //     uint48 prevTimepoint = _schedules[operationId].timepoint;
    //     if (prevTimepoint != 0 && !_isExpired(prevTimepoint)) {
    //         revert AccessManagerAlreadyScheduled(operationId);
    //     }
    // }

    /// @inheritdoc IAccessManagerSimple
    // Reentrancy is not an issue because permissions are checked on msg.sender. Additionally,
    // _consumeScheduledOp guarantees a scheduled operation is only executed once.
    // slither-disable-next-line reentrancy-no-eth
    function execute(address target, bytes calldata data) public payable virtual returns (uint32) {
        // address caller = _msgSender();

        // // Fetch restrictions that apply to the caller on the targeted function
        // (bool immediate, uint32 setback) = _canCallExtended(caller, target, data);

        // // If caller is not authorised, revert
        // if (!immediate && setback == 0) {
        //     revert AccessManagerUnauthorizedCall(caller, target, _checkSelector(data));
        // }

        // bytes32 operationId = hashOperation(caller, target, data);
        // uint32 nonce;

        // // If caller is authorised, check operation was scheduled early enough
        // // Consume an available schedule even if there is no currently enforced delay
        // if (setback != 0 || getSchedule(operationId) != 0) {
        //     nonce = _consumeScheduledOp(operationId);
        // }

        // // Mark the target and selector as authorised
        // bytes32 executionIdBefore = _executionId;
        // _executionId = _hashExecutionId(target, _checkSelector(data));

        // // Perform call
        // Address.functionCallWithValue(target, data, msg.value);

        // // Reset execute identifier
        // _executionId = executionIdBefore;

        // return nonce;
    }

    /// @inheritdoc IAccessManagerSimple
    function cancel(address caller, address target, bytes calldata data) public virtual returns (uint32) {
        // address msgsender = _msgSender();
        // bytes4 selector = _checkSelector(data);

        // bytes32 operationId = hashOperation(caller, target, data);
        // if (_schedules[operationId].timepoint == 0) {
        //     revert AccessManagerNotScheduled(operationId);
        // } else if (caller != msgsender) {
        //     // calls can only be canceled by the account that scheduled them, a global admin, or by a guardian of the required role.
        //     (bool isAdmin, ) = hasRole(ADMIN_ROLE, msgsender);
        //     (bool isGuardian, ) = hasRole(getRoleGuardian(getTargetFunctionRole(target, selector)), msgsender);
        //     if (!isAdmin && !isGuardian) {
        //         revert AccessManagerUnauthorizedCancel(msgsender, caller, target, selector);
        //     }
        // }

        // delete _schedules[operationId].timepoint; // reset the timepoint, keep the nonce
        // uint32 nonce = _schedules[operationId].nonce;
        // emit OperationCanceled(operationId, nonce);

        // return nonce;
    }

    /// @inheritdoc IAccessManagerSimple
    function consumeScheduledOp(address caller, bytes calldata data) public virtual {
        // address target = _msgSender();
        // if (IAccessManaged(target).isConsumingScheduledOp() != IAccessManaged.isConsumingScheduledOp.selector) {
        //     revert AccessManagerUnauthorizedConsume(target);
        // }
        // _consumeScheduledOp(hashOperation(caller, target, data));
    }

    // /**
    //  * @dev Internal variant of {consumeScheduledOp} that operates on bytes32 operationId.
    //  *
    //  * Returns the nonce of the scheduled operation that is consumed.
    //  */
    // function _consumeScheduledOp(bytes32 operationId) internal virtual returns (uint32) {
    //     uint48 timepoint = _schedules[operationId].timepoint;
    //     uint32 nonce = _schedules[operationId].nonce;

    //     if (timepoint == 0) {
    //         revert AccessManagerNotScheduled(operationId);
    //     } else if (timepoint > Time.timestamp()) {
    //         revert AccessManagerNotReady(operationId);
    //     } else if (_isExpired(timepoint)) {
    //         revert AccessManagerExpired(operationId);
    //     }

    //     delete _schedules[operationId].timepoint; // reset the timepoint, keep the nonce
    //     emit OperationExecuted(operationId, nonce);

    //     return nonce;
    // }

    /// @inheritdoc IAccessManagerSimple
    function hashOperation(address caller, address target, bytes calldata data) public view virtual returns (bytes32) {
        return keccak256(abi.encode(caller, target, data));
    }

    // ==================================================== OTHERS ====================================================
    /// @inheritdoc IAccessManagerSimple
    function updateAuthority(address target, address newAuthority) public virtual onlyAuthorized {
        IAccessManaged(target).setAuthority(newAuthority);
    }

    // ================================================= ADMIN LOGIC ==================================================
    /**
     * @dev Check if the current call is authorized according to admin logic.
     */
    function _checkAuthorized() private {
        address caller = _msgSender();
        (bool immediate, uint32 delay) = _canCallSelf(caller, _msgData());
        if (!immediate) {
            if (delay == 0) {
                (, uint64 requiredRole, ) = _getAdminRestrictions(_msgData());
                revert AccessManagerUnauthorizedAccount(caller, requiredRole);
            }
            // else {
            //     _consumeScheduledOp(hashOperation(caller, address(this), _msgData()));
            // }
        }
    }

    /**
     * @dev Get the admin restrictions of a given function call based on the function and arguments involved.
     *
     * Returns:
     * - bool restricted: does this data match a restricted operation
     * - uint64: which role is this operation restricted to
     * - uint32: minimum delay to enforce for that operation (max between operation's delay and admin's execution delay)
     */
    function _getAdminRestrictions(
        bytes calldata data
    ) private view returns (bool restricted, uint64 roleAdminId, uint32 executionDelay) {
        if (data.length < 4) {
            return (false, 0, 0);
        }

        bytes4 selector = _checkSelector(data);

        // Restricted to ADMIN with no delay beside any execution delay the caller may have
        if (
            selector == this.labelRole.selector ||
            selector == this.setRoleAdmin.selector ||
            selector == this.setRoleGuardian.selector ||
            selector == this.setGrantDelay.selector ||
            selector == this.setTargetAdminDelay.selector
        ) {
            return (true, ADMIN_ROLE, 0);
        }

        // Restricted to ADMIN with the admin delay corresponding to the target
        if (
            selector == this.updateAuthority.selector ||
            selector == this.setTargetClosed.selector ||
            selector == this.setTargetFunctionRole.selector
        ) {
            // First argument is a target.
            address target = abi.decode(data[0x04:0x24], (address));
            uint32 delay = getTargetAdminDelay(target);
            return (true, ADMIN_ROLE, delay);
        }

        // Restricted to that role's admin with no delay beside any execution delay the caller may have.
        if (selector == this.grantRole.selector || selector == this.revokeRole.selector) {
            // First argument is a roleId.
            uint64 roleId = abi.decode(data[0x04:0x24], (uint64));
            return (true, getRoleAdmin(roleId), 0);
        }

        return (false, 0, 0);
    }

    // =================================================== HELPERS ====================================================
    /**
     * @dev An extended version of {canCall} for internal usage that checks {_canCallSelf}
     * when the target is this contract.
     *
     * Returns:
     * - bool immediate: whether the operation can be executed immediately (with no delay)
     * - uint32 delay: the execution delay
     */
    function _canCallExtended(
        address caller,
        address target,
        bytes calldata data
    ) private view returns (bool immediate, uint32 delay) {
        if (target == address(this)) {
            return _canCallSelf(caller, data);
        } else {
            return data.length < 4 ? (false, 0) : canCall(caller, target, _checkSelector(data));
        }
    }

    /**
     * @dev A version of {canCall} that checks for admin restrictions in this contract.
     */
    function _canCallSelf(address caller, bytes calldata data) private view returns (bool immediate, uint32 delay) {
        if (data.length < 4) {
            return (false, 0);
        }

        // if (caller == address(this)) {
        //     // Caller is AccessManager, this means the call was sent through {execute} and it already checked
        //     // permissions. We verify that the call "identifier", which is set during {execute}, is correct.
        //     return (_isExecuting(address(this), _checkSelector(data)), 0);
        // }

        (bool enabled, uint64 roleId, uint32 operationDelay) = _getAdminRestrictions(data);
        if (!enabled) {
            return (false, 0);
        }

        (bool inRole, uint32 executionDelay) = hasRole(roleId, caller);
        if (!inRole) {
            return (false, 0);
        }

        // downcast is safe because both options are uint32
        delay = 0; // uint32(Math.max(operationDelay, executionDelay));
        return (delay == 0, delay);
    }

    // /**
    //  * @dev Returns true if a call with `target` and `selector` is being executed via {executed}.
    //  */
    // function _isExecuting(address target, bytes4 selector) private view returns (bool) {
    //     return _executionId == _hashExecutionId(target, selector);
    // }

    // /**
    //  * @dev Returns true if a schedule timepoint is past its expiration deadline.
    //  */
    // function _isExpired(uint48 timepoint) private view returns (bool) {
    //     return timepoint + expiration() <= Time.timestamp();
    // }

    /**
     * @dev Extracts the selector from calldata. Panics if data is not at least 4 bytes
     */
    function _checkSelector(bytes calldata data) private pure returns (bytes4) {
        return bytes4(data[0:4]);
    }

    /**
     * @dev Hashing function for execute protection
     */
    // function _hashExecutionId(address target, bytes4 selector) private pure returns (bytes32) {
    //     return keccak256(abi.encode(target, selector));
    // }
}
