// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ShortString, ShortStrings} from "@openzeppelin/contracts/utils/ShortStrings.sol";

import {RoleId, RoleIdLib } from "../types/RoleId.sol";
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
        // this service required admin rights to access manager to be able to grant/revoke roles
        _accessManager.grantRole(_accessManager.ADMIN_ROLE(), initialAdmin, 0);

        __AccessManaged_init(address(_accessManager));

        _createRole(RoleIdLib.toRoleId(_accessManager.ADMIN_ROLE()), ADMIN_ROLE_NAME, false, false);
        _createRole(RoleIdLib.toRoleId(_accessManager.PUBLIC_ROLE()), PUBLIC_ROLE_NAME, false, false);
    }

    //--- Role ------------------------------------------------------//
    function createGifRole(RoleId roleId, string memory name) external restricted() {
        _createRole(roleId, name, false, true);
    }

    function createRole(RoleId roleId, string memory name) external restricted() {
        _createRole(roleId, name, true, true);
    }

    function setRoleLocked(RoleId roleId, bool locked) external restricted() {
        if (!roleExists(roleId)) {
            revert IAccess.ErrorIAccessRoleIdInvalid(roleId);
        }

        _role[roleId].isLocked = locked;
        _role[roleId].updatedAt = TimestampLib.blockTimestamp();
    }

    function roleExists(RoleId roleId) public view returns (bool exists) {
        return _role[roleId].createdAt.gtz();
    }

    // TODO remove restricted - should be done by access manager (onlyAuthorized) - needs test to verify
    function grantRole(RoleId roleId, address member) external restricted() returns (bool granted) {
        if (!roleExists(roleId)) {
            revert IAccess.ErrorIAccessRoleIdInvalid(roleId);
        }

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

    // TODO remove restricted
    function revokeRole(RoleId roleId, address member) external restricted() returns (bool revoked) {
        if (!roleExists(roleId)) {
            revert IAccess.ErrorIAccessRevokeNonexstentRole(roleId);
        }

        if (EnumerableSet.contains(_roleMembers[roleId], member)) {
            _accessManager.revokeRole(roleId.toInt(), member);
            EnumerableSet.remove(_roleMembers[roleId], member);
            return true;
        }

        return false;
    }

    /// @dev not restricted function by intention
    /// the restriction to role members is already enforced by the call to the access manger
    function renounceRole(RoleId roleId) external returns (bool revoked) {
        address member = msg.sender;

        if (!roleExists(roleId)) {
            revert IAccess.ErrorIAccessRenounceNonexstentRole(roleId);
        }

        if (EnumerableSet.contains(_roleMembers[roleId], member)) {
            // cannot use accessManger.renounce as it directly checks against msg.sender
            _accessManager.revokeRole(roleId.toInt(), member);
            EnumerableSet.remove(_roleMembers[roleId], member);
            return true;
        }

        return false;
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

    // TODO add function `setRoleAdmin` to allow changing the admin role for a given role
    // - create new role X (id must be even)
    // - create new admin role for X (id + 1 ... avoid collision with existing roles)
    // - grant admin role for X to admin

    //--- Target ------------------------------------------------------//
    function createGifTarget(address target, string memory name) external restricted() {
        _createTarget(target, name, false, true);
    }

    function createTarget(address target, string memory name) external restricted() {
        _createTarget(target, name, true, true);
    }

    function setTargetLocked(string memory targetName, bool locked) external restricted() {
        address target = _targetForName[ShortStrings.toShortString(targetName)];
        
        if (target == address(0)) {
            revert IAccess.ErrorIAccessTargetDoesNotExist(ShortStrings.toShortString(targetName));
        }

        _target[target].isLocked = locked;
        _accessManager.setTargetClosed(target, locked);
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

    function _createTarget(address target, string memory name, bool isCustom, bool validateParameters) internal {
        if (validateParameters) {
            _validateTargetParameters(target, name, isCustom);
        }

        if (_target[target].createdAt.gtz()) {
            revert IAccess.ErrorIAccessTargetExists(target, _target[target].name);
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

    function setTargetFunctionRole(
        string memory targetName,
        bytes4[] calldata selectors,
        RoleId roleId
    ) public virtual restricted() {
        address target = _targetForName[ShortStrings.toShortString(targetName)];
        
        if (target == address(0)) {
            revert IAccess.ErrorIAccessTargetDoesNotExist(ShortStrings.toShortString(targetName));
        }
        if (! roleExists(roleId)) {
            revert IAccess.ErrorIAccessRoleIdInvalid(roleId);
        }
        uint64 roleIdInt = RoleId.unwrap(roleId);
        _accessManager.setTargetFunctionRole(target, selectors, roleIdInt);
    }

    function setTargetClosed(string memory targetName, bool closed) public restricted() {
        address target = _targetForName[ShortStrings.toShortString(targetName)];
        if (target == address(0)) {
            revert IAccess.ErrorIAccessTargetDoesNotExist(ShortStrings.toShortString(targetName));
        }
        _accessManager.setTargetClosed(target, closed);
    }

    function isTargetLocked(address target) public view returns (bool locked) {
        return _accessManager.isTargetClosed(target);
    }

    function canCall(
        address caller,
        address target,
        bytes4 selector
    ) public view virtual returns (bool immediate, uint32 delay) {
        return _accessManager.canCall(caller, target, selector);
    }
}
