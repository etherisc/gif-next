// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IModuleAuthorization} from "./IModuleAuthorization.sol";
import {IServiceAuthorization} from "./IServiceAuthorization.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType} from "../type/ObjectType.sol";
import {RoleId} from "../type/RoleId.sol";
import {VersionPart} from "../type/Version.sol";

interface IInstanceAuthorization
     is IModuleAuthorization
{

     function getInstanceNftId()
          external
          view
          returns(NftId instanceNftId);

     /// @dev Returns the linked service authorization specification.
     function getServiceAuthorization()
          external
          view
          returns(IServiceAuthorization serviceAuthz);
}

