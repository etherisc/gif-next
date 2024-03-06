// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ShortString, ShortStrings} from "@openzeppelin/contracts/utils/ShortStrings.sol";

import {RoleId, RoleIdLib, ADMIN_ROLE, PUBLIC_ROLE, INSTANCE_SERVICE_ROLE, INSTANCE_OWNER_ROLE} from "../types/RoleId.sol";
import {TimestampLib} from "../types/Timestamp.sol";
import {IAccess} from "./module/IAccess.sol";

import {IRegistry} from "../registry/IRegistry.sol";

contract InstanceAccessManager is
    AccessManagedUpgradeable
{
    using RoleIdLib for RoleId;

    string public constant ADMIN_ROLE_NAME = "AdminRole";
    string public constant PUBLIC_ROLE_NAME = "PublicRole";

    uint64 public constant CUSTOM_ROLE_ID_MIN = 10000;
    uint32 public constant EXECUTION_DELAY = 0;

    // role specific state
    mapping(RoleId roleId => IAccess.RoleInfo info) internal _roleInfo;
    mapping(RoleId roleId => EnumerableSet.AddressSet roleMembers) internal _roleMembers; 
    mapping(ShortString name => RoleId roleId) internal _roleIdForName;
    RoleId [] internal _roleIds;
    uint64 _idNext;

    // target specific state
    mapping(address target => IAccess.TargetInfo info) internal _targetInfo;
    mapping(ShortString name => address target) internal _targetAddressForName;
    address [] internal _targets;

    AccessManager internal _accessManager;
    IRegistry internal _registry;

    modifier restrictedToRoleAdmin(RoleId roleId) {
        RoleId admin = getRoleAdmin(roleId);
        (bool inRole, uint32 executionDelay) = _accessManager.hasRole(admin.toInt(), _msgSender());
        assert(executionDelay == 0); // to be sure no delayed execution functionality is used
        if (!inRole) {
            revert IAccess.ErrorIAccessCallerIsNotRoleAdmin(_msgSender(), roleId);
        }
        _;
    }

    function initialize(address initialAdmin, address registry) external initializer 
    {
        // if size of the contract gets too large, this can be externalized which will reduce the contract size considerably
        _accessManager = new AccessManager(address(this));

        __AccessManaged_init(address(_accessManager));

        _registry = IRegistry(_registry);
        _idNext = CUSTOM_ROLE_ID_MIN;

        _createRole(ADMIN_ROLE(), ADMIN_ROLE_NAME, false);
        _createRole(PUBLIC_ROLE(), PUBLIC_ROLE_NAME, false);

        // assume initialAdmin is instance service which requires admin rights to access manager during instance cloning
        _accessManager.grantRole(ADMIN_ROLE().toInt(), initialAdmin, 0);

        EnumerableSet.add(_roleMembers[ADMIN_ROLE()], address(this));
        EnumerableSet.add(_roleMembers[ADMIN_ROLE()], initialAdmin);
    }

    //--- Role ------------------------------------------------------//
    // INSTANCE_SERVICE_ROLE 
    // creates core or gif roles
    // assume core roles are never revoked or renounced -> core roles admin is never active after intialization
    // assume gif roles can be revoked or renounced
    function createRole(RoleId roleId, string memory name, RoleId admin) 
        external
        restricted()
    {
        bool isCustom = false;
        _validateRoleParameters(roleId, name, isCustom);
        _createRole(roleId, name, isCustom);
        setRoleAdmin(roleId, admin);
    }

    // INSTANCE_OWNER_ROLE
    // creates custom roles only
    // TODO INSTANCE_OWNER_ROLE as default admin
    function createCustomRole(string memory name, RoleId admin) 
        external
        restricted()
        returns(RoleId roleId)
    {
        bool isCustom = true;
        RoleId roleId = _getNextCustomRoleId();
        _validateRoleParameters(roleId, name, isCustom);
        _createRole(roleId, name, isCustom);
        setRoleAdmin(roleId, admin);
    }

    // TODO MUST always be restricted to ADMIN_ROLE? -> use onlyAdminRole or use similar _getAdminRestrictions()
    function setRoleAdmin(RoleId roleId, RoleId admin) 
        public 
        restricted()
    {
        if (!roleExists(roleId)) {
            revert IAccess.ErrorIAccessSetAdminForNonexistentRole(roleId);
        }

        _roleInfo[roleId].admin = admin;      
    }

    // TODO notify member?
    // TODO granting/revoking can be `attached` to nft transfer?
    function grantRole(RoleId roleId, address member) 
        external 
        restrictedToRoleAdmin(roleId) 
        returns (bool granted) 
    {
        if (!roleExists(roleId)) {
            revert IAccess.ErrorIAccessGrantNonexistentRole(roleId);
        }

        granted = !EnumerableSet.contains(_roleMembers[roleId], member);
        if(granted) {
            _accessManager.grantRole(roleId.toInt(), member, EXECUTION_DELAY);
            EnumerableSet.add(_roleMembers[roleId], member);
        }    
    }

    function revokeRole(RoleId roleId, address member)
        external 
        restrictedToRoleAdmin(roleId) 
        returns (bool revoked) 
    {
        if (!roleExists(roleId)) {
            revert IAccess.ErrorIAccessRevokeNonexistentRole(roleId);
        }

        revoked = EnumerableSet.contains(_roleMembers[roleId], member);
        if(revoked) {
            _accessManager.revokeRole(roleId.toInt(), member);
            EnumerableSet.remove(_roleMembers[roleId], member);
        }
    }

    /// @dev not restricted function by intention
    /// the restriction to role members is already enforced by the call to the access manager
    function renounceRole(RoleId roleId) 
        external 
        returns (bool revoked) 
    {
        address member = msg.sender;

        if (!roleExists(roleId)) {
            revert IAccess.ErrorIAccessRenounceNonexistentRole(roleId);
        }

        revoked = EnumerableSet.contains(_roleMembers[roleId], member);
        if(revoked) {
            // cannot use accessManger.renounce as it directly checks against msg.sender
            _accessManager.revokeRole(roleId.toInt(), member);
            EnumerableSet.remove(_roleMembers[roleId], member);
        }
    }

    function roleExists(RoleId roleId) public view returns (bool exists) {
        return _roleInfo[roleId].createdAt.gtz();
    }

    function getRoleAdmin(RoleId roleId) public view returns(RoleId admin) {
        return _roleInfo[roleId].admin;
    }

    function getRoleInfo(RoleId roleId) external view returns (IAccess.RoleInfo memory role) {
        return _roleInfo[roleId];
    }

    function roleMembers(RoleId roleId) external view returns (uint256 numberOfMembers) {
        return EnumerableSet.length(_roleMembers[roleId]);
    }

    function getRoleId(uint256 idx) external view returns (RoleId roleId) {
        return _roleIds[idx];
    }

    function getRoleIdForName(string memory name) external view returns (RoleId roleId) {
        return _roleIdForName[ShortStrings.toShortString(name)];
    }

    function roleMember(RoleId roleId, uint256 idx) external view returns (address roleMember) {
        return EnumerableSet.at(_roleMembers[roleId], idx);
    }

    function hasRole(RoleId roleId, address account) external view returns (bool accountHasRole) {
        (accountHasRole, ) = _accessManager.hasRole(roleId.toInt(), account);
    }

    function roles() external view returns (uint256 numberOfRoles) {
        return _roleIds.length;
    }

    //--- Target ------------------------------------------------------//
    // INSTANCE_SERVICE_ROLE
    function createTarget(address target, string memory name) external restricted() {
        bool isCustom = false;
        _createTarget(target, name, isCustom);
    }
    // INSTANCE_OWNER_ROLE
    function createCustomTarget(address target, string memory name) 
        external 
        restricted() 
    {
        // TODO custom targets can not be registered before this function, but possibly can after...
        if(_registry.isRegistered(target)) {
            revert IAccess.ErrorIAccessCreateCustomTargetTargetIsRegistered(target);
        }

        bool isCustom = true;
        _createTarget(target, name, isCustom);
    }
    // INSTANCE_SERVICE_ROLE
    // TODO if target name and role id are isomoprhic?
    function setTargetLocked(string memory targetName, bool locked) 
        external 
        restricted() 
    {
        address target = _targetAddressForName[ShortStrings.toShortString(targetName)];
        
        if (target == address(0)) {
            revert IAccess.ErrorIAccessSetLockedForNonexistentTarget(target);
        }

        // TODO setLocked() for gif and custom targets but NEVER for core targets
        /*if(!_targetInfo[target].isCustom) {
            revert IAccess.ErrorIAccessSetLockedForNoncustomTarget(target);
        }*/
        // TODO isLocked is redundant but makes getTargetInfo() faster
        _targetInfo[target].isLocked = locked;
        _accessManager.setTargetClosed(target, locked);
    }

    // allowed combinations of roles and targets:
    //1) set core role for core target 
    //2) set gif role for gif target  
    //3) set custom role for gif target
    //4) set custom role for custom target

    // ADMIN_ROLE if used only during initialization, works with:
    //      any roles for any targets
    // INSTANCE_SERVICE_ROLE if used not only initilization, works with:
    //      core roles for core targets
    //      gif roles for gif targets
    function setTargetFunctionRole(
        string memory targetName,
        bytes4[] calldata selectors,
        RoleId roleId
    ) 
        public 
        virtual 
        restricted() // restrictedToRoleAdmin? -> instance service is admin of component roles?
    { 
        address target = _targetAddressForName[ShortStrings.toShortString(targetName)];

        if (target == address(0)) {
            revert IAccess.ErrorIAccessSetForNonexistentTarget(target);
        }

        if (!roleExists(roleId)) {
            revert IAccess.ErrorIAccessSetNonexistentRole(roleId);
        }

        uint64 roleIdInt = RoleId.unwrap(roleId);
        _accessManager.setTargetFunctionRole(target, selectors, roleIdInt);
    }
    // INSTANCE_OWNER_ROLE
    // custom role for gif target -> instance owner can mess with gif target (component) -> e.g. set customer role for function intendent to work with gif role
    // custom role for custom target
    function setTargetFunctionCustomRole(
        string memory targetName,
        bytes4[] calldata selectors,
        RoleId roleId
    ) public virtual restricted() {
        address target = _targetAddressForName[ShortStrings.toShortString(targetName)];
        if (target == address(0)) {
            revert IAccess.ErrorIAccessSetForNonexistentTarget(target);
        }

        // TODO set for gif and custom targets
        /*if(!_targetInfo[target].isCustom) {
            revert IAccess.ErrorIAccessSetForNoncustomTarget(target);
        }*/

        if (!roleExists(roleId)) {
            revert IAccess.ErrorIAccessSetNonexistentRole(roleId);
        }

        // TODO set for gif and custom roles
        /*if(!_roleInfo[roleId].isCustom) {
            revert IAccess.ErrorIAccessSetNoncustomRole(roleId);
        }*/

        uint64 roleIdInt = RoleId.unwrap(roleId);
        _accessManager.setTargetFunctionRole(target, selectors, roleIdInt);
    }

    function isTargetLocked(address target) public view returns (bool locked) {
        return _accessManager.isTargetClosed(target);
    }

    function targetExists(address target) public view returns (bool exists) {
        return _targetInfo[target].createdAt.gtz();
    }

    function getTargetInfo(address target) public view returns (IAccess.TargetInfo memory) {
        return _targetInfo[target];
    }

    //--- internal view/pure functions --------------------------------------//

    function _createRole(RoleId roleId, string memory name, bool isCustom) 
        internal
    {
        IAccess.RoleInfo memory role = IAccess.RoleInfo(
            ShortStrings.toShortString(name), 
            isCustom,
            ADMIN_ROLE(),
            TimestampLib.blockTimestamp(),
            TimestampLib.blockTimestamp());

        _roleInfo[roleId] = role;
        _roleIdForName[role.name] = roleId;
        _roleIds.push(roleId);
    }

    function _validateRoleParameters(
        RoleId roleId, 
        string memory name, 
        bool isCustom
    )
        internal
        view 
        returns (IAccess.RoleInfo memory existingRole)
    {
        if(roleExists(roleId)) {
            revert IAccess.ErrorIAccessRoleIdAlreadyExists(roleId);
        }

        uint roleIdInt = roleId.toInt();
        if (isCustom && roleIdInt < CUSTOM_ROLE_ID_MIN) {
            revert IAccess.ErrorIAccessRoleIdTooSmall(roleId); 
        } else if (!isCustom && roleIdInt >= CUSTOM_ROLE_ID_MIN) {
            revert IAccess.ErrorIAccessRoleIdTooBig(roleId); 
        }

        // role name checks
        ShortString nameShort = ShortStrings.toShortString(name);
        if (ShortStrings.byteLength(nameShort) == 0) {
            revert IAccess.ErrorIAccessRoleNameEmpty(roleId);
        }

        if (_roleIdForName[nameShort].gtz()) {
            revert IAccess.ErrorIAccessRoleNameNotUnique(_roleIdForName[nameShort], nameShort);
        }
    }

    function _getNextCustomRoleId() internal returns(RoleId) {
        return RoleIdLib.toRoleId(_idNext++);
    }

    function _createTarget(address target, string memory name, bool isCustom) internal {
        _validateTargetParameters(target, name, isCustom);

        IAccess.TargetInfo memory info = IAccess.TargetInfo(
            ShortStrings.toShortString(name), 
            isCustom,
            _accessManager.isTargetClosed(target), // sync with state in access manager
            TimestampLib.blockTimestamp(),
            TimestampLib.blockTimestamp());

        _targetInfo[target] = info;
        _targetAddressForName[info.name] = target;
        _targets.push(target);
    }

    function _validateTargetParameters(address target, string memory name, bool isCustom) internal view {
        if (_targetInfo[target].createdAt.gtz()) {
            revert IAccess.ErrorIAccessTargetAlreadyExists(target, _targetInfo[target].name);
        }

        ShortString nameShort = ShortStrings.toShortString(name);
        if (ShortStrings.byteLength(nameShort) == 0) {
            revert IAccess.ErrorIAccessTargetNameEmpty(target);
        }

        if (_targetAddressForName[nameShort] != address(0)) {
            revert IAccess.ErrorIAccessTargetNameExists(
                target, 
                _targetAddressForName[nameShort], 
                nameShort);
        }
    }

    function canCall(
        address caller,
        address target,
        bytes4 selector
    ) public view virtual returns (bool immediate, uint32 delay) {
        return _accessManager.canCall(caller, target, selector);
    }
}
