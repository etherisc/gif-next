// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {AccessManagerCloneable} from "./AccessManagerCloneable.sol";
import {ContractLib} from "../shared/ContractLib.sol";
import {IAccessAdmin} from "./IAccessAdmin.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {RoleId, RoleIdLib, ADMIN_ROLE, PUBLIC_ROLE} from "../type/RoleId.sol";
import {Selector, SelectorLib, SelectorSetLib} from "../type/Selector.sol";
import {Str, StrLib} from "../type/String.sol";
import {TimestampLib} from "../type/Timestamp.sol";
import {VersionPart} from "../type/Version.sol";

interface IAccessManagedChecker {
    function authority() external view returns (address);
}

/**
 * @dev A generic access amin contract that implements role based access control based on OpenZeppelin's AccessManager contract.
 * The contract provides read functions to query all available roles, targets and access rights.
 * This contract works for both a constructor based deployment or a deployment based on cloning and initialization.
 */ 
contract AccessAdmin is
    AccessManagedUpgradeable,
    ReentrancyGuardUpgradeable,
    IAccessAdmin
{
    using EnumerableSet for EnumerableSet.AddressSet;

    string public constant ADMIN_ROLE_NAME = "AdminRole";
    string public constant PUBLIC_ROLE_NAME = "PublicRole";

    /// @dev the OpenZeppelin access manager driving the access admin contract
    AccessManagerCloneable internal _authority;

    /// @dev stores the deployer address and allows to create initializers
    /// that are restricted to the deployer address.
    address internal _deployer;

    /// @dev store role info per role id
    mapping(RoleId roleId => RoleInfo info) internal _roleInfo;

    /// @dev store role name info per role name
    mapping(Str roleName => RoleNameInfo nameInfo) internal _roleForName;

    /// @dev store array with all created roles
    RoleId [] internal _roleIds;

    /// @dev store set of current role members for given role
    mapping(RoleId roleId => EnumerableSet.AddressSet roleMembers) internal _roleMembers;

    /// @dev store target info per target address
    mapping(address target => TargetInfo info) internal _targetInfo;

    /// @dev store role name info per role name
    mapping(Str targetName => address target) internal _targetForName;

    /// @dev store array with all created targets
    address [] internal _targets;

    /// @dev store all managed functions per target
    mapping(address target => SelectorSetLib.Set selectors) internal _targetFunctions;

    /// @dev function infos array
    mapping(address target => mapping(Selector selector => FunctionInfo)) internal _functionInfo;

    /// @dev temporary dynamic functions array
    bytes4[] private _functions;

    modifier onlyDeployer() {
        // special case for cloned AccessAdmin contracts
        // IMPORTANT cloning and initialize authority needs to be done in a single transaction
        if (_deployer == address(0)) {
            _deployer = msg.sender;
        }

        if (msg.sender != _deployer) {
            revert ErrorNotDeployer();
        }
        _;
    }

    modifier onlyRoleAdmin(RoleId roleId) {
        _checkRoleExists(roleId, false);

        if (!hasAdminRole(msg.sender, roleId)) {
            revert ErrorNotAdminOfRole(_roleInfo[roleId].adminRoleId);
        }
        _;
    }

    modifier onlyRoleMember(RoleId roleId) {
        if (!hasRole(msg.sender, roleId)) {
            revert ErrorNotRoleOwner(roleId);
        }
        _;
    }

    modifier onlyExistingRole(
        RoleId roleId, 
        bool onlyActiveRole,
        bool allowLockedRoles
    )
    {
        if (!allowLockedRoles) {
            _checkRoleExists(roleId, onlyActiveRole);
        }
        _;
    }

    modifier onlyExistingTarget(address target) {
        _checkTarget(target);
        _;
    }

    //-------------- initialization functions ------------------------------//

    // event LogAccessAdminDebug(string message);

    /// @dev Initializes this admin with the provided accessManager (and authorization specification).
    /// Internally initializes access manager with this admin and creates basic role setup.
    function initialize(
        AccessManagerCloneable authority 
    )
        public
        initializer()
    {
        __AccessAdmin_init(authority);
    }


    function __AccessAdmin_init(
        AccessManagerCloneable authority 
    )
        internal
        onlyInitializing()
        onlyDeployer() // initializes deployer if not initialized yet
    {
        authority.initialize(address(this));

        // set and initialize this access manager contract as
        // the admin (ADMIN_ROLE) of the provided authority
        __AccessManaged_init(address(authority));
        _authority = authority;

        // create admin and public roles
        _initializeAdminAndPublicRoles();

        // additional use case specific initialization
        _initializeCustom();
    }


    function getRegistry() public view returns (IRegistry registry) {
        return _authority.getRegistry();
    }


    function getRelease() public view returns (VersionPart release) {
        return _authority.getRelease();
    }


    function _initializeAdminAndPublicRoles()
        internal
        virtual
        onlyInitializing()
    {
        RoleId adminRoleId = RoleIdLib.toRoleId(_authority.ADMIN_ROLE());

        // setup admin role
        _createRoleUnchecked(
            ADMIN_ROLE(),
            toRole({
                adminRoleId: ADMIN_ROLE(),
                roleType: RoleType.Contract,
                maxMemberCount: 1,
                name: ADMIN_ROLE_NAME}));

        // add this contract as admin role member
        _roleMembers[adminRoleId].add(address(this));

        // setup public role
        _createRoleUnchecked(
            PUBLIC_ROLE(),
            toRole({
                adminRoleId: ADMIN_ROLE(),
                roleType: RoleType.Gif,
                maxMemberCount: type(uint32).max,
                name: PUBLIC_ROLE_NAME}));
    }


    function _initializeCustom()
        internal
        virtual
        onlyInitializing()
    { }

    //--- view functions for roles ------------------------------------------//

    function roles() external view returns (uint256 numberOfRoles) {
        return _roleIds.length;
    }

    function getRoleId(uint256 idx) external view returns (RoleId roleId) {
        return _roleIds[idx];
    }

    function getAdminRole() public view returns (RoleId roleId) {
        return RoleId.wrap(_authority.ADMIN_ROLE());
    }

    function getPublicRole() public view returns (RoleId roleId) {
        return RoleId.wrap(_authority.PUBLIC_ROLE());
    }

    function roleExists(RoleId roleId) public view returns (bool exists) {
        return _roleInfo[roleId].createdAt.gtz();
    }

    function getRoleInfo(RoleId roleId) external view returns (RoleInfo memory) {
        return _roleInfo[roleId];
    }

    function getRoleForName(Str name) external view returns (RoleNameInfo memory) {
        return _roleForName[name];
    }

    function roleMembers(RoleId roleId) external view returns (uint256 numberOfMembers) {
        return _roleMembers[roleId].length();
    }

    function getRoleMember(RoleId roleId, uint256 idx) external view returns (address account) {
        return _roleMembers[roleId].at(idx);
    }

    // TODO false because not role member or because role not exists?
    function hasRole(address account, RoleId roleId) public view returns (bool) {
        (bool isMember, ) = _authority.hasRole(
            RoleId.unwrap(roleId), 
            account);
        return isMember;
    }

    function hasAdminRole(address account, RoleId roleId)
        public 
        virtual
        view 
        returns (bool)
    {
        return hasRole(account, _roleInfo[roleId].adminRoleId);
    }

    //--- view functions for targets ----------------------------------------//

    function targetExists(address target) public view returns (bool exists) {
        return _targetInfo[target].createdAt.gtz();
    }

    function targets() external view returns (uint256 numberOfTargets) {
        return _targets.length;
    }

    function getTargetAddress(uint256 idx) external view returns (address target) {
        return _targets[idx];
    }

    function getTargetInfo(address target) external view returns (TargetInfo memory targetInfo) {
        return _targetInfo[target];
    }

    function getTargetForName(Str name) public view returns (address target) {
        return _targetForName[name];
    }

    function isTargetLocked(address target) public view returns (bool locked) {
        return _authority.isTargetClosed(target);
    }

    function authorizedFunctions(address target) external view returns (uint256 numberOfFunctions) {
        return SelectorSetLib.size(_targetFunctions[target]);
    }

    function getAuthorizedFunction(
        address target, 
        uint256 idx
    )
        external 
        view 
        returns (
            FunctionInfo memory func, 
            RoleId roleId
        )
    {
        Selector selector = SelectorSetLib.at(_targetFunctions[target], idx);
        func = _functionInfo[target][selector];
        roleId = RoleIdLib.toRoleId(
            _authority.getTargetFunctionRole(
                target, 
                selector.toBytes4()));
    }

    function canCall(address caller, address target, Selector selector) external virtual view returns (bool can) {
        (can, ) = _authority.canCall(caller, target, selector.toBytes4());
    }

    function toRole(RoleId adminRoleId, RoleType roleType, uint32 maxMemberCount, string memory name) public view returns (RoleInfo memory) {
        return RoleInfo({
            name: StrLib.toStr(name),
            adminRoleId: adminRoleId,
            roleType: roleType,
            maxMemberCount: maxMemberCount,
            createdAt: TimestampLib.blockTimestamp(),
            pausedAt: TimestampLib.max()
        });
    }

    function toFunction(bytes4 selector, string memory name) public view returns (FunctionInfo memory) {
        return FunctionInfo({
            name: StrLib.toStr(name),
            selector: SelectorLib.toSelector(selector),
            createdAt: TimestampLib.blockTimestamp()});
    }

    function deployer() public view returns (address) {
        return _deployer;
    }

    //--- internal/private functions -------------------------------------------------//

    function _authorizeTargetFunctions(
        address target, 
        RoleId roleId, 
        FunctionInfo[] memory functions
    )
        internal
    {
        if (roleId == getAdminRole()) {
            revert ErrorAuthorizeForAdminRoleInvalid(target);
        }

        (
            bytes4[] memory functionSelectors,
            string[] memory functionNames
        ) = _processFunctionSelectors(target, functions, true);

        // apply authz via access manager
        _grantRoleAccessToFunctions(
            target, 
            roleId, 
            functionSelectors,
            functionNames, 
            false); // allow locked roles
    }

    function _unauthorizeTargetFunctions(
        address target, 
        FunctionInfo[] memory functions
    )
        internal
    {
        (
            bytes4[] memory functionSelectors,
            string[] memory functionNames
        ) = _processFunctionSelectors(target, functions, false);

        _grantRoleAccessToFunctions(
            target, 
            getAdminRole(), 
            functionSelectors, 
            functionNames, 
            true);  // allowLockedRoles
    }

    function _processFunctionSelectors(
        address target,
        FunctionInfo[] memory functions,
        bool addFunctions
    )
        internal
        onlyExistingTarget(target)
        returns (
            bytes4[] memory functionSelectors,
            string[] memory functionNames
        )
    {
        uint256 n = functions.length;
        functionSelectors = new bytes4[](n);
        functionNames = new string[](n);
        FunctionInfo memory func;
        Selector selector;

        for (uint256 i = 0; i < n; i++) {
            func = functions[i];
            selector = func.selector;

            // add function selector to target selector set if not in set
            if (addFunctions) { SelectorSetLib.add(_targetFunctions[target], selector); } 
            else { SelectorSetLib.remove(_targetFunctions[target], selector); }

            // set function name
            _functionInfo[target][selector] = func;

            // add bytes4 selector to function selector array
            functionSelectors[i] = selector.toBytes4();
            functionNames[i] = func.name.toString();
        }
    }

    /// @dev grant the specified role access to all functions in the provided selector list
    function _grantRoleAccessToFunctions(
        address target,
        RoleId roleId, 
        bytes4[] memory functionSelectors,
        string[] memory functionNames,
        bool allowLockedRoles // admin and public roles are locked
    )
        internal
        onlyExistingTarget(target)
        onlyExistingRole(roleId, true, allowLockedRoles)
    {

        _authority.setTargetFunctionRole(
            target,
            functionSelectors,
            RoleId.unwrap(roleId));

        for (uint256 i = 0; i < functionSelectors.length; i++) {
            emit LogAccessAdminFunctionGranted(
                target, 
                // _getAccountName(target), 
                // string(abi.encodePacked("", functionSelectors[i])), 
                functionNames[i], 
                _getRoleName(roleId));
        }
    }


    /// @dev grant the specified role to the provided account
    function _grantRoleToAccount(RoleId roleId, address account)
        internal
        onlyExistingRole(roleId, true, false)
    {
        // check max role members will not be exceeded
        if (_roleMembers[roleId].length() >= _roleInfo[roleId].maxMemberCount) {
            revert ErrorRoleMembersLimitReached(roleId, _roleInfo[roleId].maxMemberCount);
        }

        // check account is contract for contract role
        if (
            _roleInfo[roleId].roleType == RoleType.Contract &&
            !ContractLib.isContract(account) // will fail in account's constructor
        ) {
            revert ErrorRoleMemberNotContract(roleId, account);
        }

        // TODO check account already have roleId
        _roleMembers[roleId].add(account);
        _authority.grantRole(
            RoleId.unwrap(roleId), 
            account, 
            0);
        
        emit LogAccessAdminRoleGranted(account, _getRoleName(roleId));
    }

    /// @dev revoke the specified role from the provided account
    function _revokeRoleFromAccount(RoleId roleId, address account)
        internal
        onlyExistingRole(roleId, false, false)
    {

        // check role removal is permitted
        if (_roleInfo[roleId].roleType == RoleType.Contract) {
            revert ErrorRoleMemberRemovalDisabled(roleId, account);
        }

        // TODO check account have roleId?
        _roleMembers[roleId].remove(account);
        _authority.revokeRole(
            RoleId.unwrap(roleId), 
            account);

        emit LogAccessAdminRoleRevoked(account, _roleInfo[roleId].name.toString());
    }


    /// @dev Creates a role based on the provided parameters.
    /// Checks that the provided role and role id and role name not already used.
    function _createRole(
        RoleId roleId, 
        RoleInfo memory info
    )
        internal
    {
        // check role does not yet exist
        if(roleExists(roleId)) {
            revert ErrorRoleAlreadyCreated(
                roleId, 
                _roleInfo[roleId].name.toString());
        }

        // check admin role exists
        if(!roleExists(info.adminRoleId)) {
            revert ErrorRoleAdminNotExisting(info.adminRoleId);
        }

        // check role name is not empty
        if(info.name.length() == 0) {
            revert ErrorRoleNameEmpty(roleId);
        }

        // check role name is not used for another role
        if(_roleForName[info.name].exists) {
            revert ErrorRoleNameAlreadyExists(
                roleId, 
                info.name.toString(),
                _roleForName[info.name].roleId);
        }

        _createRoleUnchecked(roleId, info);
    }


    function _createRoleUnchecked(
        RoleId roleId, 
        RoleInfo memory info
    )
        private
    {
        // create role info
        info.createdAt = TimestampLib.blockTimestamp();
        _roleInfo[roleId] = info;

        // create role name info
        _roleForName[info.name] = RoleNameInfo({
            roleId: roleId,
            exists: true});

        // add role to list of roles
        _roleIds.push(roleId);

        emit LogAccessAdminRoleCreated(roleId, info.roleType, info.adminRoleId, info.name.toString());
    }


    function _createTarget(
        address target, 
        string memory targetName, 
        bool checkAuthority,
        bool custom
    )
        internal
    {
        // check target does not yet exist
        if(targetExists(target)) {
            revert ErrorTargetAlreadyCreated(
                target, 
                _targetInfo[target].name.toString());
        }

        // check target name is not empty
        Str name = StrLib.toStr(targetName);
        if(name.length() == 0) {
            revert ErrorTargetNameEmpty(target);
        }

        // check target name is not used for another target
        if( _targetForName[name] != address(0)) {
            revert ErrorTargetNameAlreadyExists(
                target, 
                targetName,
                _targetForName[name]);
        }

        // check target is an access managed contract
        if (!_isAccessManaged(target)) {
            revert ErrorTargetNotAccessManaged(target);
        }

        // check target shares authority with this contract
        if (checkAuthority) {
            address targetAuthority = AccessManagedUpgradeable(target).authority();
            if (targetAuthority != authority()) {
                revert ErrorTargetAuthorityMismatch(authority(), targetAuthority);
            }
        }

        // create target info
        _targetInfo[target] = TargetInfo({
            name: name,
            isCustom: custom,
            createdAt: TimestampLib.blockTimestamp()
        });

        // create name to target mapping
        _targetForName[name] = target;

        // add role to list of roles
        _targets.push(target);

        emit LogAccessAdminTargetCreated(target, targetName);
    }


    function _isAccessManaged(address target)
        internal
        view
        returns (bool)
    {
        if (!ContractLib.isContract(target)) {
            return false;
        }

        (bool success, ) = target.staticcall(
            abi.encodeWithSelector(
                IAccessManagedChecker.authority.selector));

        return success;
    }


    function _setTargetClosed(address target, bool locked)
        internal
    {
        _checkTarget(target);

        // target locked/unlocked already
        if(_authority.isTargetClosed(target) == locked) {
            revert ErrorTargetAlreadyLocked(target, locked);
        }

        _authority.setTargetClosed(target, locked);
    }

    function _getAccountName(address account) internal view returns (string memory) {
        if (targetExists(account)) {
            return _targetInfo[account].name.toString();
        }
        return "<unknown-account>";
    }


    function _getRoleName(RoleId roleId) internal view returns (string memory) {
        if (roleExists(roleId)) {
            return _roleInfo[roleId].name.toString();
        }
        return "<unknown-role>";
    }


    function _checkRoleExists(
        RoleId roleId, 
        bool onlyActiveRole
    )
        internal
        view
    {
        if (!roleExists(roleId)) {
            revert ErrorRoleUnknown(roleId);
        }

        uint64 roleIdInt = RoleId.unwrap(roleId);
        if (roleIdInt == _authority.ADMIN_ROLE()) {
            revert ErrorRoleIsLocked(roleId);
        }

        // check if role is disabled
        if (onlyActiveRole && _roleInfo[roleId].pausedAt <= TimestampLib.blockTimestamp()) {
            revert ErrorRoleIsPaused(roleId);
        }
    }


    /// @dev check if target exists and reverts if it doesn't
    function _checkTarget(address target)
        internal
        view
    {
        if (!targetExists(target)) {
            revert ErrorTargetUnknown(target);
        }
    }
}