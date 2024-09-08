// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {IAccess} from "./IAccess.sol";
import {IAccessAdmin} from "./IAccessAdmin.sol";
import {IAuthorization} from "./IAuthorization.sol";
import {IRegistry} from "../registry/IRegistry.sol";

import {ADMIN_ROLE_NAME, PUBLIC_ROLE_NAME} from "./AccessAdmin.sol";
import {AccessAdminLib} from "./AccessAdminLib.sol";
import {AccessManagerCloneable} from "./AccessManagerCloneable.sol";
import {ContractLib} from "../shared/ContractLib.sol";
import {NftId, NftIdLib} from "../type/NftId.sol";
import {ObjectType} from "../type/ObjectType.sol";
import {RoleId, RoleIdLib, ADMIN_ROLE, PUBLIC_ROLE} from "../type/RoleId.sol";
import {Selector, SelectorSetLib} from "../type/Selector.sol";
import {Str, StrLib} from "../type/String.sol";
import {TimestampLib} from "../type/Timestamp.sol";
import {VersionPart} from "../type/Version.sol";

function ADMIN_ROLE_NAME() pure returns (string memory) { return "AdminRole"; }
function PUBLIC_ROLE_NAME() pure returns (string memory) { return "PublicRole"; }


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

    /// @dev admin name used for logging only
    string internal _adminName;

    /// @dev the access manager driving the access admin contract
    /// hold link to registry and release version
    AccessManagerCloneable internal _authority;

    /// @dev the authorization contract used for initial access control
    IAuthorization internal _authorization;

    /// @dev stores the deployer address and allows to create initializers
    /// that are restricted to the deployer address.
    address internal _deployer;

    /// @dev the linked NFT ID
    NftId internal _linkedNftId;

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

    // @dev target type specific role id counters
    mapping(TargetType => uint64) internal _nextRoleId;

    modifier onlyDeployer() {
        // special case for cloned AccessAdmin contracts
        // IMPORTANT cloning and initialize authority needs to be done in a single transaction
        if (_deployer == address(0)) {
            _deployer = msg.sender;
        }

        if (msg.sender != _deployer) {
            revert ErrorAccessAdminNotDeployer();
        }
        _;
    }


    //-------------- initialization functions ------------------------------//

    /// @dev Initializes this admin with the provided accessManager (and authorization specification).
    /// Internally initializes access manager with this admin and creates basic role setup.
    function initialize(
        address authority,
        string memory adminName 
    )
        public
        initializer()
    {
        __AccessAdmin_init(authority, adminName);
    }


    function __AccessAdmin_init(
        address authority, 
        string memory adminName 
    )
        internal
        onlyInitializing()
        onlyDeployer()
    {
        // checks
        // only contract check (authority might not yet be initialized at this time)
        if (!ContractLib.isContract(authority)) {
            revert ErrorAccessAdminAuthorityNotContract(authority);
        }

        // check name not empty
        if (bytes(adminName).length == 0) {
            revert ErrorAccessAdminAccessManagerEmptyName();
        }

        _authority = AccessManagerCloneable(authority);
        _authority.initialize(address(this));

        // delayed additional check for authority after its initialization
        if (!ContractLib.isAuthority(authority)) {
            revert ErrorAccessAdminAccessManagerNotAccessManager(authority);
        }

        // effects
        // set and initialize this access manager contract as
        // the admin (ADMIN_ROLE) of the provided authority
        __AccessManaged_init(authority);

        // set name for logging
        _adminName = adminName;

        // set initial linked NFT ID to zero
        _linkedNftId = NftIdLib.zero();

        // create admin and public roles
        _initializeAdminAndPublicRoles();
    }

    //--- view functions for access amdin ---------------------------------------//

    function getRelease() public view virtual returns (VersionPart release) {
        return _authority.getRelease();
    }


    function getRegistry() public view returns (IRegistry registry) {
        return _authority.getRegistry();
    }


    function getLinkedNftId() external view returns (NftId linkedNftId) {
        return _linkedNftId;
    }


    function getLinkedOwner() external view returns (address linkedOwner) {
        return getRegistry().ownerOf(_linkedNftId);
    }


    function getAuthorization() public view returns (IAuthorization authorization) {
        return _authorization;
    }


    function isLocked() public view returns (bool locked) {
        return _authority.isLocked();
    }

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

    function roleExists(string memory name) public view returns (bool exists) {
        // special case for admin and public roles
        if (StrLib.eq(name, ADMIN_ROLE_NAME()) || StrLib.eq(name, PUBLIC_ROLE_NAME())) {
            return true;
        }

        return _roleForName[StrLib.toStr(name)].roleId.gtz();
    }

    function roleExists(RoleId roleId) public view returns (bool exists) {
        return _roleInfo[roleId].createdAt.gtz();
    }

    function getRoleForName(string memory name) public view returns (RoleId roleId) {
        return _roleForName[StrLib.toStr(name)].roleId;
    }

    function getRoleInfo(RoleId roleId) public view returns (RoleInfo memory) {
        return _roleInfo[roleId];
    }

    function isRoleActive(RoleId roleId) external view returns (bool isActive) {
        return _roleInfo[roleId].pausedAt > TimestampLib.current();
    }

    function isRoleCustom(RoleId roleId) external view returns (bool isActive) {
        return _roleInfo[roleId].roleType == RoleType.Custom;
    }

    function roleMembers(RoleId roleId) external view returns (uint256 numberOfMembers) {
        return _roleMembers[roleId].length();
    }

    function getRoleMember(RoleId roleId, uint256 idx) external view returns (address account) {
        return _roleMembers[roleId].at(idx);
    }

    function isRoleMember(RoleId roleId, address account) public view returns (bool) {
        (bool isMember, ) = _authority.hasRole(
            RoleId.unwrap(roleId), 
            account);
        return isMember;
    }

    function isRoleAdmin(RoleId roleId, address account) public virtual view returns (bool) {
        return isRoleMember(_roleInfo[roleId].adminRoleId, account);
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

    function getTargetInfo(address target) public view returns (TargetInfo memory targetInfo) {
        return _targetInfo[target];
    }

    function getTargetForName(Str name) public view returns (address target) {
        return _targetForName[name];
    }

    function isTargetLocked(address target) public view returns (bool locked) {
        return _authority.isLocked() || _authority.isTargetClosed(target);
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

    function deployer() public view returns (address) {
        return _deployer;
    }

    //--- internal/private functions -------------------------------------------------//

    function _linkToNftOwnable(address registerable) internal {
        if (!getRegistry().isRegistered(registerable)) {
            revert ErrorAccessAdminNotRegistered(registerable);
        }

        _linkedNftId = getRegistry().getNftIdForAddress(registerable);
    }


    function _initializeAdminAndPublicRoles()
        internal
        virtual
        onlyInitializing()
    {
        // setup admin role
        _createRoleUnchecked(
            ADMIN_ROLE(),
            AccessAdminLib.toRole({
                adminRoleId: ADMIN_ROLE(),
                roleType: RoleType.Contract,
                maxMemberCount: 1,
                name: ADMIN_ROLE_NAME()}));

        // add this contract as admin role member, as contract roles cannot be revoked
        // and max member count is 1 for admin role this access admin contract will
        // always be the only admin of the access manager.
        _roleMembers[
            RoleIdLib.toRoleId(_authority.ADMIN_ROLE())].add(address(this));

        // setup public role
        _createRoleUnchecked(
            PUBLIC_ROLE(),
            AccessAdminLib.toRole({
                adminRoleId: ADMIN_ROLE(),
                roleType: RoleType.Core,
                maxMemberCount: type(uint32).max,
                name: PUBLIC_ROLE_NAME()}));
    }


    /// @dev Authorize the functions of the target for the specified role.
    function _authorizeFunctions(IAuthorization authorization, Str target, RoleId roleId)
        internal
    {
        _authorizeTargetFunctions(
            getTargetForName(target),
            _toAuthorizedRoleId(authorization, roleId),
            authorization.getAuthorizedFunctions(
                target, 
                roleId),
            true);
    }


    function _toAuthorizedRoleId(IAuthorization authorization, RoleId roleId)
        internal
        returns (RoleId authorizedRoleId)
    {
        // special case for service roles (service roles have predefined role ids)
        if (roleId.isServiceRole()) {

            // create service role if missing
            if (!roleExists(roleId)) {
                _createRole(
                    roleId, 
                    AccessAdminLib.toRole(
                        ADMIN_ROLE(), 
                        RoleType.Contract, 
                        1, 
                        authorization.getRoleName(roleId)));
            }

            return roleId;
        }

        string memory roleName = authorization.getRoleInfo(roleId).name.toString();
        return authorizedRoleId = getRoleForName(roleName);
    }


    function _authorizeTargetFunctions(
        address target, 
        RoleId roleId, 
        FunctionInfo[] memory functions,
        bool addFunctions
    )
        internal
    {
        if (addFunctions && roleId == getAdminRole()) {
            revert ErrorAccessAdminAuthorizeForAdminRoleInvalid(target);
        }

        // apply authz via access manager
        _grantRoleAccessToFunctions(
            target, 
            roleId, 
            functions,
            addFunctions); // add functions
    }


    /// @dev grant the specified role access to all functions in the provided selector list
    function _grantRoleAccessToFunctions(
        address target,
        RoleId roleId, 
        FunctionInfo[] memory functions,
        bool addFunctions
    )
        internal
    {
        _checkTargetExists(target);
        _checkRoleExists(roleId, true, true);

        _authority.setTargetFunctionRole(
            target,
            AccessAdminLib.getSelectors(functions),
            RoleId.unwrap(roleId));

        // update function set and log function grantings
        for (uint256 i = 0; i < functions.length; i++) {
            _updateFunctionAccess(
                target, 
                roleId,
                functions[i], 
                addFunctions);
        }
    }


    function _updateFunctionAccess(
        address target, 
        RoleId roleId,
        FunctionInfo memory func, 
        bool addFunction
    )
        internal
    {
        // update functions info
        Selector selector = func.selector;
        _functionInfo[target][selector] = func;

        // update function sets
        if (addFunction) { SelectorSetLib.add(_targetFunctions[target], selector); } 
        else { SelectorSetLib.remove(_targetFunctions[target], selector); }

        // logging
        emit LogAccessAdminFunctionGranted(
            _adminName, 
            target, 
            string(abi.encodePacked(
                func.name.toString(), 
                "(): ",
                _getRoleName(roleId))));
    }


    /// @dev grant the specified role to the provided account
    function _grantRoleToAccount(RoleId roleId, address account)
        internal
    {
        _checkRoleExists(roleId, true, false);

        // check max role members will not be exceeded
        if (_roleMembers[roleId].length() >= _roleInfo[roleId].maxMemberCount) {
            revert ErrorAccessAdminRoleMembersLimitReached(roleId, _roleInfo[roleId].maxMemberCount);
        }

        // check account is contract for contract role
        if (
            _roleInfo[roleId].roleType == RoleType.Contract &&
            !ContractLib.isContract(account) // will fail in account's constructor
        ) {
            revert ErrorAccessAdminRoleMemberNotContract(roleId, account);
        }

        // effects
        _roleMembers[roleId].add(account);
        _authority.grantRole(
            RoleId.unwrap(roleId), 
            account, 
            0);
        
        emit LogAccessAdminRoleGranted(_adminName, account, _getRoleName(roleId));
    }


    /// @dev revoke the specified role from the provided account
    function _revokeRoleFromAccount(RoleId roleId, address account)
        internal
    {
        _checkRoleExists(roleId, false, false);

        // check for attempt to revoke contract role
        if (_roleInfo[roleId].roleType == RoleType.Contract) {
            revert ErrorAccessAdminRoleMemberRemovalDisabled(roleId, account);
        }

        // effects
        _roleMembers[roleId].remove(account);
        _authority.revokeRole(
            RoleId.unwrap(roleId), 
            account);

        emit LogAccessAdminRoleRevoked(_adminName, account, _roleInfo[roleId].name.toString());
    }


    /// @dev Creates a role based on the provided parameters.
    /// Checks that the provided role and role id and role name not already used.
    function _createRole(
        RoleId roleId, 
        RoleInfo memory info
    )
        internal
    {
        // skip admin and public roles (they are created during initialization)
        if (roleId == ADMIN_ROLE() || roleId == PUBLIC_ROLE()) {
            return;
        }
        
        AccessAdminLib.checkRoleCreation(this, roleId, info);
        _createRoleUnchecked(roleId, info);
    }


    /// @dev Activates or deactivates role.
    /// The role activ property is indirectly controlled over the pausedAt timestamp.
    function _setRoleActive(RoleId roleId, bool active)
        internal
    {
        if (active) {
            _roleInfo[roleId].pausedAt = TimestampLib.max();
        } else {
            _roleInfo[roleId].pausedAt = TimestampLib.current();
        }
    }


    function _createManagedTarget(
        address target, 
        string memory targetName, 
        TargetType targetType
    )
        internal
        returns (RoleId contractRoleId)
    {
        return _createTarget(target, targetName, targetType, true);
    }


    function _createUncheckedTarget(
        address target, 
        string memory targetName, 
        TargetType targetType
    )
        internal
    {
        _createTarget(target, targetName, targetType, false);
    }


    function _createTarget(
        address target, 
        string memory targetName, 
        TargetType targetType,
        bool checkAuthority
    )
        private
        returns (RoleId contractRoleId)
    {
        // checks
        AccessAdminLib.checkTargetCreation(this, target, targetName, checkAuthority);

        // effects
        contractRoleId = _createTargetUnchecked(
            target, 
            targetName, 
            targetType,
            checkAuthority);

        // deal with token handler, if applicable
        (
            address tokenHandler,
            string memory tokenHandlerName
        ) = AccessAdminLib.getTokenHandler(target, targetName, targetType);

        if (tokenHandler != address(0)) {
            _createTargetUnchecked(
                tokenHandler, 
                tokenHandlerName, 
                targetType,
                checkAuthority);
        }
    }


    function _createRoleUnchecked(
        RoleId roleId, 
        RoleInfo memory info
    )
        private
    {
        // create role info
        info.createdAt = TimestampLib.current();
        info.pausedAt = TimestampLib.max();
        _roleInfo[roleId] = info;

        // create role name info
        _roleForName[info.name] = RoleNameInfo({
            roleId: roleId,
            exists: true});

        // add role to list of roles
        _roleIds.push(roleId);

        emit LogAccessAdminRoleCreated(_adminName, roleId, info.roleType, info.adminRoleId, info.name.toString());
    }


    /// @dev Creates a new target and a corresponding contract role.
    /// The function assigns the role to the target and logs the creation.
    function _createTargetUnchecked(
        address target, 
        string memory targetName, 
        TargetType targetType,
        bool managed
    )
        internal
        returns (RoleId targetRoleId)
    {
        // create target role (if not existing)
        string memory roleName;
        (targetRoleId, roleName) = _getOrCreateTargetRoleIdAndName(target, targetName, targetType);

        if (!roleExists(targetRoleId)) {
            _createRole(
                targetRoleId, 
                AccessAdminLib.toRole(ADMIN_ROLE(), IAccess.RoleType.Contract, 1, roleName));
        }

        // create target info
        Str name = StrLib.toStr(targetName);
        _targetInfo[target] = TargetInfo({
            name: name,
            targetType: targetType,
            roleId: targetRoleId,
            createdAt: TimestampLib.current()
        });

        // create name to target mapping
        _targetForName[name] = target;

        // add target to list of targets
        _targets.push(target);

        // grant contract role to target
        _grantRoleToAccount(targetRoleId, target);

        emit LogAccessAdminTargetCreated(_adminName, targetName, managed, target, targetRoleId);
    }


    function _getOrCreateTargetRoleIdAndName(
        address target,
        string memory targetName,
        TargetType targetType
    )
        internal
        returns (
            RoleId roleId,
            string memory roleName
        )
    {
        // get roleId
        if (targetType == TargetType.Service || targetType == TargetType.GenericService) {
            roleId = AccessAdminLib.getServiceRoleId(target, targetType); 
        } else {
            roleId = AccessAdminLib.getTargetRoleId(target, targetType, _nextRoleId[targetType]);

            // increment target type specific role id counter
            _nextRoleId[targetType]++;
        }

        // create role name
        roleName = AccessAdminLib.toRoleName(targetName);
    }


    function _setTargetLocked(address target, bool locked)
        internal
    {
        _checkTargetExists(target);
        _authority.setTargetClosed(target, locked);
    }


    function _getRoleName(RoleId roleId) internal view returns (string memory) {
        if (roleExists(roleId)) {
            return _roleInfo[roleId].name.toString();
        }
        return "<unknown-role>";
    }


    function _checkAuthorization( 
        address authorization,
        ObjectType expectedDomain, 
        VersionPart expectedRelease,
        bool expectServiceAuthorization,
        bool checkAlreadyInitialized
    )
        internal
        view
    {
        AccessAdminLib.checkAuthorization(
            address(_authorization), 
            authorization, 
            expectedDomain, 
            expectedRelease, 
            expectServiceAuthorization,
            checkAlreadyInitialized);
    }


    function _checkRoleExists( 
        RoleId roleId, 
        bool onlyActiveRole,
        bool allowAdminAndPublicRoles
    )
        internal
        view
    {
        if (!roleExists(roleId)) {
            revert ErrorAccessAdminRoleUnknown(roleId);
        }

        if (!allowAdminAndPublicRoles) {
            if (roleId == ADMIN_ROLE()) {
                revert ErrorAccessAdminInvalidUserOfAdminRole();
            }

            // check role is not public role
            if (roleId == PUBLIC_ROLE()) {
                revert ErrorAccessAdminInvalidUserOfPublicRole();
            }
        }

        // check if role is disabled
        if (onlyActiveRole && _roleInfo[roleId].pausedAt <= TimestampLib.current()) {
            revert ErrorAccessAdminRoleIsPaused(roleId);
        }
    }


    /// @dev check if target exists and reverts if it doesn't
    function _checkTargetExists(
        address target
    )
        internal
        view
    {
        // check not yet created
        if (!targetExists(target)) {
            revert ErrorAccessAdminTargetNotCreated(target);
        }
    }
}