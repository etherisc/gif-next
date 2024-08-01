// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccess} from "./IAccess.sol";
import {IAuthorization} from "./IAuthorization.sol";
import {ObjectType} from "../type/ObjectType.sol";
import {RoleId} from "../type/RoleId.sol";
import {Str} from "../type/String.sol";

// TODO why module is have get service functions
interface IModuleAuthorization is 
     IAccess,
     IAuthorization 
{

     /// @dev Returns the list of service domains used by module.
     function getServiceDomains() external view returns(ObjectType[] memory serviceDomains);

     /// @dev Returns the service name for the specified domain.
     function getServiceName(ObjectType serviceDomain) external view returns(Str serviceName);
}

