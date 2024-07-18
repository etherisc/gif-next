// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccess} from "./IAccess.sol";
import {IAuthorization} from "./IAuthorization.sol";
import {ObjectType, ObjectTypeLib} from "../type/ObjectType.sol";
import {RoleId, RoleIdLib, ADMIN_ROLE} from "../type/RoleId.sol";
import {SelectorLib} from "../type/Selector.sol";
import {Str, StrLib} from "../type/String.sol";
import {TimestampLib} from "../type/Timestamp.sol";
import {VersionPart, VersionPartLib} from "../type/Version.sol";

contract Authorization
     is IAuthorization
{
     uint256 public constant GIF_VERSION = 3;
     string public constant ROLE_NAME_SUFFIX = "Role";
     string public constant SERVICE_ROLE_NAME_SUFFIX = "ServiceRole";

     string internal _mainTargetName = "Component";
     Str[] internal _targets;

     mapping(Str target => RoleId roleid) internal _targetRole;
     mapping(Str target => bool exists) internal _targetExists;

     RoleId[] internal _roles;
     mapping(RoleId role => RoleInfo info) internal _roleInfo;

     mapping(Str target => RoleId[] authorizedRoles) internal _authorizedRoles;
     mapping(Str target => mapping(RoleId authorizedRole => IAccess.FunctionInfo[] functions)) internal _authorizedFunctions;


     constructor(string memory mainTargetName) {
          _mainTargetName = mainTargetName;

          _setupRoles();
          _setupTargets();
          _setupTargetAuthorizations();
     }

     function getRelease() public virtual pure returns(VersionPart release) {
          return VersionPartLib.toVersionPart(GIF_VERSION);
     }

     function getRoles() external view returns(RoleId[] memory roles) {
          return _roles;
     }

     function getServiceRole(ObjectType serviceDomain) public virtual pure returns (RoleId serviceRoleId) {
          return RoleIdLib.roleForTypeAndVersion(
               serviceDomain, getRelease());
     }

     function getRoleInfo(RoleId roleId) external view returns (RoleInfo memory info) {
          return _roleInfo[roleId];
     }

     function roleExists(RoleId roleId) public view returns(bool exists) {
          return _roleInfo[roleId].roleType != RoleType.Undefined;
     }

     function getTarget() public view returns(Str) {
          if (_targets.length > 0) {
               return _targets[0];
          }

          return StrLib.toStr("");
     }

     function getTargets() external view returns(Str[] memory targets) {
          return _targets;
     }

     function targetExists(Str target) external view returns(bool exists) {
          return _targetExists[target];
     }

     function getTargetRole(Str target) external view returns(RoleId roleId) {
          return _targetRole[target];
     }

     function getAuthorizedRoles(Str target) external view returns(RoleId[] memory roleIds) {
          return _authorizedRoles[target];
     }

     function getAuthorizedFunctions(Str target, RoleId roleId) external view returns(IAccess.FunctionInfo[] memory authorizatedFunctions) {
          return _authorizedFunctions[target][roleId];
     }

     function getTargetName() public virtual view returns (string memory name) {
          return _mainTargetName;
     }

     /// @dev Overwrite this function for a specific realease.
     // solhint-disable-next-line no-empty-blocks
     function _setupRoles() internal virtual {}

     /// @dev Overwrite this function for a specific realease.
     /// The first target added represents the components/module main target.
     // solhint-disable-next-line no-empty-blocks
     function _setupTargets() internal virtual { }

     /// @dev Overwrite this function for a specific realease.
     // solhint-disable-next-line no-empty-blocks
     function _setupTargetAuthorizations() internal virtual {}

     /// @dev Use this method to to add an authorized role.
     function _addRole(RoleId roleId, RoleInfo memory info) internal {
          _roles.push(roleId);
          _roleInfo[roleId] = info;
     }

     /// @dev Add a contract role for the provided role id and name.
     function _addContractRole(RoleId roleId, string memory name) internal {
          _addRole(
               roleId,
               _toRoleInfo(
                    ADMIN_ROLE(),
                    RoleType.Contract,
                    1,
                    name));
     }

     /// @dev Add the versioned service role for the specified service domain
     function _addServiceRole(ObjectType serviceDomain) internal {
          _addContractRole(
               getServiceRole(serviceDomain),
               ObjectTypeLib.toVersionedName(
                    ObjectTypeLib.toName(serviceDomain), 
                    SERVICE_ROLE_NAME_SUFFIX, 
                    getRelease().toInt()));
     }

     function _addComponentTargetWithRole(ObjectType componentType) internal {
          _addTargetWithRole(
               getTargetName(), 
               RoleIdLib.toComponentRoleId(componentType, 0),
               _toTargetRoleName(
                    getTargetName()));
     }

     /// @dev Add a contract role for the provided role id and name.
     function _addCustomRole(RoleId roleId, RoleId adminRoleId, uint32 maxMemberCount, string memory name) internal {
          _addRole(
               roleId,
               _toRoleInfo(
                    adminRoleId,
                    RoleType.Custom,
                    maxMemberCount,
                    name));
     }

     /// @dev Use this method to to add an authorized target together with its target role.
     function _addTargetWithRole(
          string memory targetName, 
          RoleId roleId, 
          string memory roleName
     )
          internal
     {
          // add target
          Str target = StrLib.toStr(targetName);
          _targets.push(target);

          _targetExists[target] = true;

          // link role to target if defined
          if (roleId != RoleIdLib.zero()) {
               // add role if new
               if (!roleExists(roleId)) {
                    _addContractRole(roleId, roleName);
               }

               // link target to role
               _targetRole[target] = roleId;
          }
     }

     /// @dev Use this method to to add an authorized target.
     function _addTarget(string memory name) internal {
          _addTargetWithRole(name, RoleIdLib.zero(), "");
     }

     /// @dev Use this method to authorize the specified role to access the target.
     function _authorizeForTarget(string memory target, RoleId authorizedRoleId)
          internal
          returns (IAccess.FunctionInfo[] storage authorizatedFunctions)
     {
          Str targetStr = StrLib.toStr(target);
          _authorizedRoles[targetStr].push(authorizedRoleId);
          return _authorizedFunctions[targetStr][authorizedRoleId];
     }

     /// @dev Use this method to authorize a specific function authorization
     function _authorize(IAccess.FunctionInfo[] storage functions, bytes4 selector, string memory name) internal {
          functions.push(
               IAccess.FunctionInfo({
                    selector: SelectorLib.toSelector(selector),
                    name: StrLib.toStr(name),
                    createdAt: TimestampLib.blockTimestamp()}));
     }

     function _toTargetRoleName(string memory targetName) internal view returns (string memory) {
          return string(
               abi.encodePacked(
                    targetName,
                    ROLE_NAME_SUFFIX));
     }

     /// @dev creates a role info object from the provided parameters
     function _toRoleInfo(RoleId adminRoleId, RoleType roleType, uint32 maxMemberCount, string memory name) internal view returns (RoleInfo memory info) {
          return RoleInfo({
               name: StrLib.toStr(name),
               adminRoleId: adminRoleId,
               roleType: roleType,
               maxMemberCount: maxMemberCount,
               createdAt: TimestampLib.blockTimestamp()});
     }
}

