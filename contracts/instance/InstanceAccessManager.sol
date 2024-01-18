// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ShortString, ShortStrings} from "@openzeppelin/contracts/utils/ShortStrings.sol";

import {AccessManagedSimple} from "./AccessManagedSimple.sol";
import {AccessManagerSimple} from "./AccessManagerSimple.sol";
import {IBundle} from "./module/IBundle.sol";
import {IPolicy} from "./module/IPolicy.sol";
import {IRisk} from "./module/IRisk.sol";
import {ISetup} from "./module/ISetup.sol";
import {Key32, KeyId, Key32Lib} from "../types/Key32.sol";
import {KeyValueStore} from "./base/KeyValueStore.sol";
import {NftId} from "../types/NftId.sol";
import {NumberId} from "../types/NumberId.sol";
import {ObjectType, BUNDLE, DISTRIBUTION, POLICY, POOL, ROLE, PRODUCT, TARGET} from "../types/ObjectType.sol";
import {RiskId, RiskIdLib} from "../types/RiskId.sol";
import {RoleId, RoleIdLib} from "../types/RoleId.sol";
import {StateId, ACTIVE} from "../types/StateId.sol";
import {Timestamp, TimestampLib} from "../types/Timestamp.sol";

contract InstanceAccessManager is
    AccessManagedSimple
{
    string public constant ADMIN_ROLE_NAME = "AdminRole";
    string public constant PUBLIC_ROLE_NAME = "PublicRole";

    uint64 public constant CUSTOM_ROLE_ID_MIN = 10000;
    uint32 public constant EXECUTION_DELAY = 0;

    struct RoleInfo {
        ShortString name;
        bool isCustom;
        bool isLocked;
        Timestamp createdAt;
        Timestamp updatedAt;
    }

    struct TargetInfo {
        ShortString name;
        bool isCustom;
        bool isLocked;
        Timestamp createdAt;
        Timestamp updatedAt;
    }

    error ErrorRoleIdInvalid(RoleId roleId);
    error ErrorRoleIdTooBig(RoleId roleId);
    error ErrorRoleIdTooSmall(RoleId roleId);
    error ErrorRoleIdAlreadyExists(RoleId roleId, ShortString name);
    error ErrorRoleIdNotActive(RoleId roleId);
    error ErrorRoleNameEmpty(RoleId roleId);
    error ErrorRoleNameNotUnique(RoleId roleId, ShortString name);
    error ErrorRoleInvalidUpdate(RoleId roleId, bool isCustom);
    error ErrorRoleIsCustomIsImmutable(RoleId roleId, bool isCustom, bool isCustomExisting);
    error ErrorSetLockedForNonexstentRole(RoleId roleId);
    error ErrorGrantNonexstentRole(RoleId roleId);
    error ErrorRevokeNonexstentRole(RoleId roleId);
    error ErrorRenounceNonexstentRole(RoleId roleId);

    error ErrorTargetAddressZero();
    error ErrorTargetAlreadyExists(address target, ShortString name);
    error ErrorTargetNameEmpty(address target);
    error ErrorTargetNameExists(address target, address existingTarget, ShortString name);
    error ErrorSetLockedForNonexstentTarget(address target);

    // role specific state
    mapping(RoleId roleId => RoleInfo info) internal _role;
    mapping(RoleId roleId => EnumerableSet.AddressSet roleMembers) internal _roleMembers; 
    mapping(ShortString name => RoleId roleId) internal _roleForName;
    RoleId [] internal _roles;

    // target specific state
    mapping(address target => TargetInfo info) internal _target;
    mapping(ShortString name => address target) internal _targetForName;
    address [] internal _targets;

    AccessManagerSimple internal _accessManager;

    constructor(address accessManager)
    {
        _accessManager = AccessManagerSimple(accessManager);
        initializeAccessManagedSimple(accessManager);

        _createRole(RoleIdLib.toRoleId(_accessManager.ADMIN_ROLE()), ADMIN_ROLE_NAME, false, false);
        _createRole(RoleIdLib.toRoleId(_accessManager.PUBLIC_ROLE()), PUBLIC_ROLE_NAME, false, false);
    }

    //--- Role ------------------------------------------------------//

    function createDefaultRole(RoleId roleId, string memory name) external restricted() {
        _createRole(roleId, name, false, true);
    }

    function createRole(RoleId roleId, string memory name) external restricted() {
        _createRole(roleId, name, true, true);
    }

    function setRoleLocked(RoleId roleId, bool locked) external restricted() {
        if (!roleExists(roleId)) {
            revert ErrorSetLockedForNonexstentRole(roleId);
        }

        _role[roleId].isLocked = locked;
        _role[roleId].updatedAt = TimestampLib.blockTimestamp();
    }

    function roleExists(RoleId roleId) public view returns (bool exists) {
        return _role[roleId].createdAt.gtz();
    }

    function grantRole(RoleId roleId, address member) external restricted() returns (bool granted) {
        if (!roleExists(roleId)) {
            revert ErrorGrantNonexstentRole(roleId);
        }

        if (_role[roleId].isLocked) {
            revert ErrorRoleIdNotActive(roleId);
        }

        if (!EnumerableSet.contains(_roleMembers[roleId], member)) {
            _accessManager.grantRole(roleId.toInt(), member, EXECUTION_DELAY);
            EnumerableSet.add(_roleMembers[roleId], member);
            return true;
        }

        return false;
    }

    function revokeRole(RoleId roleId, address member) external restricted() returns (bool revoked) {
        if (!roleExists(roleId)) {
            revert ErrorRevokeNonexstentRole(roleId);
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
            revert ErrorRenounceNonexstentRole(roleId);
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

    function getRole(RoleId roleId) external view returns (RoleInfo memory role) {
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
    function createTarget(address target, string memory name) external restricted() {
        _createTarget(target, name, true, true);
    }

    function setTargetLocked(address target, bool locked) external restricted() {
        if (!targetExists(target)) {
            revert ErrorSetLockedForNonexstentTarget(target);
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

        RoleInfo memory role = RoleInfo(
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
        returns (RoleInfo memory existingRole)
    {
        // check role id
        uint64 roleIdInt = RoleId.unwrap(roleId);
        if(roleIdInt == _accessManager.ADMIN_ROLE() || roleIdInt == _accessManager.PUBLIC_ROLE()) {
            revert ErrorRoleIdInvalid(roleId); 
        }

        // prevent changing isCustom for existing roles
        existingRole = _role[roleId];

        if (existingRole.createdAt.gtz() && isCustom != existingRole.isCustom) {
            revert ErrorRoleIsCustomIsImmutable(roleId, isCustom, existingRole.isCustom); 
        }

        if (isCustom && roleIdInt < CUSTOM_ROLE_ID_MIN) {
            revert ErrorRoleIdTooSmall(roleId); 
        } else if (!isCustom && roleIdInt >= CUSTOM_ROLE_ID_MIN) {
            revert ErrorRoleIdTooBig(roleId); 
        }

        // role name checks
        ShortString nameShort = ShortStrings.toShortString(name);
        if (ShortStrings.byteLength(nameShort) == 0) {
            revert ErrorRoleNameEmpty(roleId);
        }

        if (_roleForName[nameShort] != RoleIdLib.zero() && _roleForName[nameShort] != roleId) {
            revert ErrorRoleNameNotUnique(_roleForName[nameShort], nameShort);
        }
    }

    function _createTarget(address target, string memory name, bool isCustom, bool validateParameters) internal {
        if (validateParameters) {
            _validateTargetParameters(target, name, isCustom);
        }

        TargetInfo memory info = TargetInfo(
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

    }
}
