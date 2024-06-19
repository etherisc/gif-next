// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccess} from "../authorization/IAccess.sol";
import {IModuleAuthorization} from "./IModuleAuthorization.sol";
import {ObjectType, ObjectTypeLib} from "../type/ObjectType.sol";
import {RoleId, RoleIdLib} from "../type/RoleId.sol";
import {SelectorLib} from "../type/Selector.sol";
import {Str, StrLib} from "../type/String.sol";
import {TimestampLib} from "../type/Timestamp.sol";
import {VersionPart} from "../type/Version.sol";

contract ModuleAuthorization
     is IModuleAuthorization
{

     Str[] internal _targets;
     ObjectType[] internal _serviceDomains;

     mapping(ObjectType domain => Str target) internal _serviceTarget;
     mapping(Str target => RoleId roleid) internal _targetRole;
     mapping(Str target => bool exists) internal _targetExists;

     RoleId[] internal _roles;
     mapping(RoleId role => Str name) internal _roleName;

     mapping(Str target => RoleId[] authorizedRoles) internal _authorizedRoles;
     mapping(Str target => mapping(RoleId authorizedRole => IAccess.FunctionInfo[] functions)) internal _authorizedFunctions;

     constructor() {
          _setupRoles();
          _setupTargets();
          _setupTargetAuthorizations();
     }

     function getRelease() public virtual view returns(VersionPart release) { }

     function getRoles() external view returns(RoleId[] memory roles) {
          return _roles;
     }

     function getRoleName(RoleId roleId) external view returns (Str name) {
          return _roleName[roleId];
     }

     function roleExists(RoleId roleId) public view returns(bool exists) {
          return _roleName[roleId].length() > 0;
     }

     function getTargets() external view returns(Str[] memory targets) {
          return _targets;
     }

     function getServiceDomains() external view returns(ObjectType[] memory serviceDomains) {
          return _serviceDomains;
     }

     function getServiceTarget(ObjectType serviceDomain) external view returns(Str serviceTarget) {
          return _serviceTarget[serviceDomain];
     }

     function getTargetRole(Str target) external view returns(RoleId roleId) {
          return _targetRole[target];
     }

     function targetExists(Str target) external view returns(bool exists) {
          return _targetExists[target];
     }

     function getAuthorizedRoles(Str target) external view returns(RoleId[] memory roleIds) {
          return _authorizedRoles[target];
     }

     function getAuthorizedFunctions(Str target, RoleId roleId) external view returns(IAccess.FunctionInfo[] memory authorizatedFunctions) {
          return _authorizedFunctions[target][roleId];
     }

     /// @dev Overwrite this function for a specific realease.
     function _setupTargets() internal virtual {}

     /// @dev Overwrite this function for a specific realease.
     function _setupRoles() internal virtual {}

     /// @dev Overwrite this function for a specific realease.
     function _setupTargetAuthorizations() internal virtual {}

     /// @dev Add the versioned service role for the specified service domain
     function _addServiceRole(ObjectType serviceDomain) internal {
          _addRole(
               _getServiceRoleId(serviceDomain),
               ObjectTypeLib.toVersionedName(
                    ObjectTypeLib.toName(serviceDomain), 
                    "ServiceRole", 
                    getRelease().toInt()));
     }

     /// @dev Use this method to to add an authorized role.
     function _addRole(RoleId roleId, string memory name) internal {
          _roles.push(roleId);
          _roleName[roleId] = StrLib.toStr(name);
     }

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

          RoleId serviceRoleId = _getServiceRoleId(serviceDomain);
          string memory serviceRoleName = ObjectTypeLib.toVersionedName(
                    ObjectTypeLib.toName(serviceDomain), 
                    "ServiceRole", 
                    getRelease().toInt());

          _addTargetWithRole(
               serviceTargetName,
               serviceRoleId,
               serviceRoleName);
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
                    _addRole(roleId, roleName);
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

     /// @dev role id for targets registry, staking and instance
     function _getTargetRoleId(ObjectType targetDomain) 
          internal
          returns (RoleId targetRoleId)
     {
          return RoleIdLib.roleForType(targetDomain);
     }

     function _getServiceRoleId(ObjectType serviceDomain) 
          internal
          returns (RoleId serviceRoleId)
     {
          return RoleIdLib.roleForTypeAndVersion(
               serviceDomain, getRelease());
     }
}

