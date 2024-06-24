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

     ObjectType[] internal _serviceDomains;
     mapping(ObjectType domain => Str target) internal _serviceTarget;

     constructor(string memory moduleName)
          Authorization(moduleName)
     { }

     function getServiceDomains() external view returns(ObjectType[] memory serviceDomains) {
          return _serviceDomains;
     }

     function getServiceTarget(ObjectType serviceDomain) external view returns(Str serviceTarget) {
          return _serviceTarget[serviceDomain];
     }

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

     /// @dev role id for targets registry, staking and instance
     function _getTargetRoleId(ObjectType targetDomain) 
          internal
          returns (RoleId targetRoleId)
     {
          return RoleIdLib.roleForType(targetDomain);
     }
}

