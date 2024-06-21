// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Authorization} from "./Authorization.sol";
import {IAccess} from "./IAccess.sol";
import {IModuleAuthorization} from "./IModuleAuthorization.sol";
import {ObjectType, ObjectTypeLib} from "../type/ObjectType.sol";
import {RoleId, RoleIdLib, ADMIN_ROLE} from "../type/RoleId.sol";
import {SelectorLib} from "../type/Selector.sol";
import {Str, StrLib} from "../type/String.sol";
import {TimestampLib} from "../type/Timestamp.sol";
import {VersionPart} from "../type/Version.sol";

contract ModuleAuthorization is
     Authorization,
     IModuleAuthorization
{

     // TODO cleanup
     // Str[] internal _targets;
     ObjectType[] internal _serviceDomains;

     mapping(ObjectType domain => Str target) internal _serviceTarget;
     // mapping(Str target => RoleId roleid) internal _targetRole;
     // mapping(Str target => bool exists) internal _targetExists;

     // RoleId[] internal _roles;
     // mapping(RoleId role => RoleInfo info) internal _roleInfo;

     // mapping(Str target => RoleId[] authorizedRoles) internal _authorizedRoles;
     // mapping(Str target => mapping(RoleId authorizedRole => IAccess.FunctionInfo[] functions)) internal _authorizedFunctions;

     constructor(string memory moduleName)
          Authorization(moduleName)
     { }

     // function getRoles() external view returns(RoleId[] memory roles) {
     //      return _roles;
     // }

     // function getRoleInfo(RoleId roleId) external view returns (RoleInfo memory info) {
     //      return _roleInfo[roleId];
     // }

     // function roleExists(RoleId roleId) public view returns(bool exists) {
     //      return _roleInfo[roleId].roleType != RoleType.Undefined;
     // }

     // function getTargets() external view returns(Str[] memory targets) {
     //      return _targets;
     // }

     function getServiceDomains() external view returns(ObjectType[] memory serviceDomains) {
          return _serviceDomains;
     }

     function getServiceTarget(ObjectType serviceDomain) external view returns(Str serviceTarget) {
          return _serviceTarget[serviceDomain];
     }

     // function getTargetRole(Str target) external view returns(RoleId roleId) {
     //      return _targetRole[target];
     // }

     // function getAuthorizedRoles(Str target) external view returns(RoleId[] memory roleIds) {
     //      return _authorizedRoles[target];
     // }

     // function getAuthorizedFunctions(Str target, RoleId roleId) external view returns(IAccess.FunctionInfo[] memory authorizatedFunctions) {
     //      return _authorizedFunctions[target][roleId];
     // }

     // /// @dev Overwrite this function for a specific realease.
     // function _setupTargets() internal virtual {}

     // /// @dev Overwrite this function for a specific realease.
     // function _setupRoles() internal virtual {}

     // /// @dev Overwrite this function for a specific realease.
     // function _setupTargetAuthorizations() internal virtual {}

     // /// @dev Use this method to to add an authorized role.
     // function _addRole(RoleId roleId, RoleInfo memory info) internal {
     //      _roles.push(roleId);
     //      _roleInfo[roleId] = info;
     // }

     /// @dev Add a GIF role for the provided role id and name.
     function _addGifRole(RoleId roleId, string memory name) internal returns (RoleInfo memory info) {
          _addRole(
               roleId,
               _toRoleInfo(
                    ADMIN_ROLE(),
                    RoleType.Gif,
                    type(uint32).max,
                    name));
     }

     // /// @dev Add a contract role for the provided role id and name.
     // function _addContractRole(RoleId roleId, string memory name) internal {
     //      _addRole(
     //           roleId,
     //           _toRoleInfo(
     //                ADMIN_ROLE(),
     //                RoleType.Contract,
     //                1,
     //                name));
     // }

     /// @dev Add the service target role for the specified service domain
     function _addServiceTargetWithRole(ObjectType serviceDomain) internal {
          // add service domain
          _serviceDomains.push(serviceDomain);

          // get versioned target name
          string memory serviceTargetName = ObjectTypeLib.toVersionedName(
                    ObjectTypeLib.toName(serviceDomain), 
                    "Service", 
                    getRelease().toInt());

          _serviceTarget[serviceDomain] = StrLib.toStr(serviceTargetName);

          RoleId serviceRoleId = getServiceRole(serviceDomain);
          string memory serviceRoleName = ObjectTypeLib.toVersionedName(
                    ObjectTypeLib.toName(serviceDomain), 
                    "ServiceRole", 
                    getRelease().toInt());

          _addTargetWithRole(
               serviceTargetName,
               serviceRoleId,
               serviceRoleName);
     }

     // /// @dev Use this method to to add an authorized target together with its target role.
     // function _addTargetWithRole(
     //      string memory targetName, 
     //      RoleId roleId, 
     //      string memory roleName
     // )
     //      internal
     // {
     //      // add target
     //      Str target = StrLib.toStr(targetName);
     //      _targets.push(target);

     //      _targetExists[target] = true;

     //      // link role to target if defined
     //      if (roleId != RoleIdLib.zero()) {
     //           // add role if new
     //           if (!roleExists(roleId)) {
     //                _addContractRole(roleId, roleName);
     //           }

     //           // link target to role
     //           _targetRole[target] = roleId;
     //      }
     // }

     // /// @dev creates a role info object from the provided parameters
     // function _toRoleInfo(RoleId adminRoleId, RoleType roleType, uint32 maxMemberCount, string memory name) internal view returns (RoleInfo memory info) {
     //      return RoleInfo({
     //           name: StrLib.toStr(name),
     //           adminRoleId: adminRoleId,
     //           roleType: roleType,
     //           maxMemberCount: maxMemberCount,
     //           createdAt: TimestampLib.blockTimestamp()});
     // }

     // /// @dev Use this method to to add an authorized target.
     // function _addTarget(string memory name) internal {
     //      _addTargetWithRole(name, RoleIdLib.zero(), "");
     // }

     // /// @dev Use this method to authorize the specified role to access the target.
     // function _authorizeForTarget(string memory target, RoleId authorizedRoleId)
     //      internal
     //      returns (IAccess.FunctionInfo[] storage authorizatedFunctions)
     // {
     //      Str targetStr = StrLib.toStr(target);
     //      _authorizedRoles[targetStr].push(authorizedRoleId);
     //      return _authorizedFunctions[targetStr][authorizedRoleId];
     // }

     // /// @dev Use this method to authorize a specific function authorization
     // function _authorize(IAccess.FunctionInfo[] storage functions, bytes4 selector, string memory name) internal {
     //      functions.push(
     //           IAccess.FunctionInfo({
     //                selector: SelectorLib.toSelector(selector),
     //                name: StrLib.toStr(name),
     //                createdAt: TimestampLib.blockTimestamp()}));
     // }

     /// @dev role id for targets registry, staking and instance
     function _getTargetRoleId(ObjectType targetDomain) 
          internal
          returns (RoleId targetRoleId)
     {
          return RoleIdLib.roleForType(targetDomain);
     }
}

