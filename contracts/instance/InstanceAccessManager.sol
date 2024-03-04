// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ShortString, ShortStrings} from "@openzeppelin/contracts/utils/ShortStrings.sol";

import {RoleId, RoleIdLib, ADMIN_ROLE, PUBLIC_ROLE, INSTANCE_SERVICE_ROLE, INSTANCE_OWNER_ROLE} from "../types/RoleId.sol";
import {TimestampLib} from "../types/Timestamp.sol";
import {IAccess} from "./module/IAccess.sol";

contract InstanceAccessManager is
    AccessManagedUpgradeable
{
    using RoleIdLib for RoleId;

    string public constant ADMIN_ROLE_NAME = "AdminRole";
    string public constant PUBLIC_ROLE_NAME = "PublicRole";

    uint64 public constant CUSTOM_ROLE_ID_MIN = 10000;
    uint32 public constant EXECUTION_DELAY = 0;

    // role specific state
    mapping(RoleId roleId => IAccess.RoleInfo info) internal _role;
    mapping(RoleId roleId => EnumerableSet.AddressSet roleMembers) internal _roleMembers; 
    mapping(ShortString name => RoleId roleId) internal _roleForName;
    RoleId [] internal _roles;

    // target specific state
    mapping(address target => IAccess.TargetInfo info) internal _target;
    mapping(ShortString name => address target) internal _targetForName;
    address [] internal _targets;

    AccessManager internal _accessManager;

    function initialize(address initialAdmin) external initializer 
    {
        // if size of the contract gets too large, this can be externalized which will reduce the contract size considerably
        _accessManager = new AccessManager(address(this));

        __AccessManaged_init(address(_accessManager));

        _createRole(ADMIN_ROLE(), ADMIN_ROLE_NAME, false, false);
        _createRole(PUBLIC_ROLE(), PUBLIC_ROLE_NAME, false, false);

        // assume initialAdmin is instance service which requires admin rights to access manager during instance cloning
        EnumerableSet.add(_roleMembers[ADMIN_ROLE()], initialAdmin);
        _accessManager.grantRole(ADMIN_ROLE().toInt(), initialAdmin, 0);
    }

    //--- Role ------------------------------------------------------//
    // INSTANCE_SERVICE_ROLE
    function createGifRole(RoleId roleId, string memory name) external restricted() {
        _createRole(roleId, name, false, true);
    }

    // INSTANCE_OWNER_ROLE
    function createRole(RoleId roleId, string memory name) external restricted() {
        _createRole(roleId, name, true, true);
    }

    // INSTANCE_OWNER_ROLE
    function setRoleLocked(RoleId roleId, bool locked) external restricted() {
        if (!roleExists(roleId)) {
            revert IAccess.ErrorIAccessSetLockedForNonexistentRole(roleId);
        }

        if(!_role[roleId].isCustom) {
            revert IAccess.ErrorIAccessSetLockedForNoncustomRole(roleId);
        }

        _role[roleId].isLocked = locked;
        _role[roleId].updatedAt = TimestampLib.blockTimestamp();
    }

    // TODO Oz's grantRole() have different modifier and works with all role admins -> while this function works only with one role...
    // INSTANCE_OWNER_ROLE
    function grantRole(RoleId roleId, address member) external restricted() returns (bool granted) {
        if(!_role[roleId].isCustom) {
            revert IAccess.ErrorIAccessGrantNoncustomRole(roleId);
        }

        return _grantRole(roleId, member);
    }
    // INSTANCE_SERVICE_ROLE
    function grantGifRole(RoleId roleId, address member) external restricted() returns (bool granted) {
        if(_role[roleId].isCustom) {
            revert IAccess.ErrorIAccessGrantCustomRole(roleId);
        }

        return _grantRole(roleId, member);
    }

    // TODO oz's revokeRole() have different modifier and works with all roles admins while this function works only with one role...
    // INSTANCE_OWNER_ROLE
    function revokeRole(RoleId roleId, address member) external restricted() returns (bool revoked) {
        if (!roleExists(roleId)) {
            revert IAccess.ErrorIAccessRevokeNonexistentRole(roleId);
        }

        if(!_role[roleId].isCustom) {
            revert IAccess.ErrorIAccessRevokeNoncustomRole(roleId);
        }

        if (EnumerableSet.contains(_roleMembers[roleId], member)) {
            _accessManager.revokeRole(roleId.toInt(), member);
            EnumerableSet.remove(_roleMembers[roleId], member);
            return true;
        }

        return false;
    }

    /// @dev not restricted function by intention
    /// the restriction to role members is already enforced by the call to the access manager
    function renounceRole(RoleId roleId) external returns (bool revoked) {
        address member = msg.sender;

        if (!roleExists(roleId)) {
            revert IAccess.ErrorIAccessRenounceNonexistentRole(roleId);
        }

        // TODO prohibit renouncing GIF roles???
        /*if(!_role[roleId].isCustom) {
            revert IAccess.ErrorIAccessRenounceNoncustomRole(roleId);
        }*/

        if (EnumerableSet.contains(_roleMembers[roleId], member)) {
            // cannot use accessManger.renounce as it directly checks against msg.sender
            _accessManager.revokeRole(roleId.toInt(), member);
            EnumerableSet.remove(_roleMembers[roleId], member);
            return true;
        }

        return false;
    }

    function roleExists(RoleId roleId) public view returns (bool exists) {
        return _role[roleId].createdAt.gtz();
    }

    function roles() external view returns (uint256 numberOfRoles) {
        return _roles.length;
    }

    function getRoleId(uint256 idx) external view returns (RoleId roleId) {
        return _roles[idx];
    }

    function getRoleIdForName(string memory name) external view returns (RoleId roleId) {
        return _roleForName[ShortStrings.toShortString(name)];
    }

    function getRole(RoleId roleId) external view returns (IAccess.RoleInfo memory role) {
        return _role[roleId];
    }

    function hasRole(RoleId roleId, address account) external view returns (bool accountHasRole) {
        (accountHasRole, ) = _accessManager.hasRole(roleId.toInt(), account);
    }

    function roleMembers(RoleId roleId) external view returns (uint256 numberOfMembers) {
        return EnumerableSet.length(_roleMembers[roleId]);
    }

    function getRoleMember(RoleId roleId, uint256 idx) external view returns (address roleMember) {
        return EnumerableSet.at(_roleMembers[roleId], idx);
    }

    //--- Target ------------------------------------------------------//
    // INSTANCE_SERVICE_ROLE
    function createGifTarget(address target, string memory name) external restricted() {
        _createTarget(target, name, false, true);
    }
    // ADMIN_ROLE, func is not used
    function createTarget(address target, string memory name) external restricted() {
        _createTarget(target, name, true, true);
    }
    // INSTANCE_SERVICE_ROLE
    function setTargetLocked(string memory targetName, bool locked) external restricted() {
        address target = _targetForName[ShortStrings.toShortString(targetName)];
        
        if (target == address(0)) {
            revert IAccess.ErrorIAccessSetLockedForNonexistentTarget(target);
        }

        if(!_target[target].isCustom) {
            revert IAccess.ErrorIAccessSetLockedForNoncustomTarget(target);
        }

        _target[target].isLocked = locked;
        _accessManager.setTargetClosed(target, locked);
    }
    // INSTANCE_SERVICE_ROLE
    function setTargetFunctionRole(
        string memory targetName,
        bytes4[] calldata selectors,
        RoleId roleId
    ) public virtual restricted() {
        address target = _targetForName[ShortStrings.toShortString(targetName)];

        if (target == address(0)) {
            revert IAccess.ErrorIAccessSetForNonexistentTarget(target);
        }

        if (!roleExists(roleId)) {
            revert IAccess.ErrorIAccessSetNonexistentRole(roleId);
        }

        uint64 roleIdInt = RoleId.unwrap(roleId);
        _accessManager.setTargetFunctionRole(target, selectors, roleIdInt);
    }

    function isTargetLocked(address target) public view returns (bool locked) {
        return _accessManager.isTargetClosed(target);
    }

    function targetExists(address target) public view returns (bool exists) {
        return _target[target].createdAt.gtz();
    }

    //--- internal view/pure functions --------------------------------------//

    function _createRole(RoleId roleId, string memory name, bool isCustom, bool validateParameters) internal {
        if (validateParameters) {
            _validateRoleParameters(roleId, name, isCustom);
        }

        IAccess.RoleInfo memory role = IAccess.RoleInfo(
            ShortStrings.toShortString(name), 
            isCustom,
            false, // role un-locked,
            TimestampLib.blockTimestamp(),
            TimestampLib.blockTimestamp());

        _role[roleId] = role;
        _roleForName[role.name] = roleId;
        _roles.push(roleId);
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
        // check role id
        uint64 roleIdInt = RoleId.unwrap(roleId);
        if(roleIdInt == _accessManager.ADMIN_ROLE() || roleIdInt == _accessManager.PUBLIC_ROLE()) {
            revert IAccess.ErrorIAccessRoleIdInvalid(roleId); 
        }

        // prevent changing isCustom for existing roles
        existingRole = _role[roleId];

        if (existingRole.createdAt.gtz() && isCustom != existingRole.isCustom) {
            revert IAccess.ErrorIAccessRoleIsCustomIsImmutable(roleId, isCustom, existingRole.isCustom); 
        }

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

        if (_roleForName[nameShort] != RoleIdLib.zero() && _roleForName[nameShort] != roleId) {
            revert IAccess.ErrorIAccessRoleNameNotUnique(_roleForName[nameShort], nameShort);
        }
    }

    function _grantRole(RoleId roleId, address member) internal returns (bool granted) {
        if (!roleExists(roleId)) {
            revert IAccess.ErrorIAccessGrantNonexistentRole(roleId);
        }

        // GIF roles are never locked
        if (_role[roleId].isLocked) {
            revert IAccess.ErrorIAccessRoleIdNotActive(roleId);
        }

        if (!EnumerableSet.contains(_roleMembers[roleId], member)) {
            _accessManager.grantRole(roleId.toInt(), member, EXECUTION_DELAY);
            EnumerableSet.add(_roleMembers[roleId], member);
            return true;
        }

        return false;        
    }

    function _createTarget(address target, string memory name, bool isCustom, bool validateParameters) internal {
        if (validateParameters) {
            _validateTargetParameters(target, name, isCustom);
        }

        if (_target[target].createdAt.gtz()) {
            revert IAccess.ErrorIAccessTargetAlreadyExists(target, _target[target].name);
        }
        if (_targetForName[ShortStrings.toShortString(name)] != address(0)) {
            revert IAccess.ErrorIAccessTargetNameExists(target, _targetForName[ShortStrings.toShortString(name)], ShortStrings.toShortString(name));
        }

        IAccess.TargetInfo memory info = IAccess.TargetInfo(
            ShortStrings.toShortString(name), 
            isCustom,
            _accessManager.isTargetClosed(target), // sync with state in access manager
            TimestampLib.blockTimestamp(),
            TimestampLib.blockTimestamp());

        _target[target] = info;
        _targetForName[info.name] = target;
        _targets.push(target);
    }

    function _validateTargetParameters(address target, string memory name, bool isCustom) internal view {
        // TODO: implement
    }

    function canCall(
        address caller,
        address target,
        bytes4 selector
    ) public view virtual returns (bool immediate, uint32 delay) {
        return _accessManager.canCall(caller, target, selector);
    }
}
