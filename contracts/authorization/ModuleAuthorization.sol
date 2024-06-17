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
     RoleId[] internal _roles;
     mapping(RoleId role => Str name) internal _roleName;

     mapping(Str target => RoleId[] authorizedRoles) internal _authorizedRoles;
     mapping(Str target => mapping(RoleId authorizedRole => IAccess.FunctionInfo[] functions)) internal _authorizedFunctions;

     constructor() {
          _setupTargets();
          _setupRoles();
          _setupTargetAuthorizations();
     }

     function getRelease() public virtual view returns(VersionPart release) { }

     function getTargets() external view returns(Str[] memory targets) {
          return _targets;
     }

     function getRoles() external view returns(RoleId[] memory roles) {
          return _roles;
     }

     function getRoleName(RoleId roleId) external view returns (Str name) {
          return _roleName[roleId];
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

     /// @dev Use this method to to add an authorized target.
     function _addTarget(string memory name) internal {
          _targets.push(StrLib.toStr(name));
     }

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

