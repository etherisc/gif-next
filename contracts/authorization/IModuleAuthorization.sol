// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccess} from "./IAccess.sol";
import {IAuthorization} from "./IAuthorization.sol";
import {ObjectType} from "../type/ObjectType.sol";
import {RoleId} from "../type/RoleId.sol";
import {Str} from "../type/String.sol";

interface IModuleAuthorization is 
     IAccess,
     IAuthorization 
{

     /// @dev Returns the list of service targets.
     function getServiceDomains() external view returns(ObjectType[] memory serviceDomains);

     /// @dev Returns the service target for the specified domain.
     function getServiceTarget(ObjectType serviceDomain) external view returns(Str serviceTarget);
}

