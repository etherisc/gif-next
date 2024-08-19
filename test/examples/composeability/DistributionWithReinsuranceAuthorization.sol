// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Authorization} from "../../../contracts/authorization/Authorization.sol";
// import {Distribution} from "../../../contracts/distribution/Distribution.sol";
import {DISTRIBUTION} from "../../../contracts/type/ObjectType.sol";
import {IAccess} from "../../../contracts/authorization/IAccess.sol";
import {IInstanceLinkedComponent} from "../../../contracts/shared/IInstanceLinkedComponent.sol";
import {PUBLIC_ROLE} from "../../../contracts/type/RoleId.sol";


contract DistributionWithReinsuranceAuthorization
     is Authorization
{

     constructor()
          Authorization("DistributionWithReinsurance", DISTRIBUTION())
     {}

     // // TODO cleanup
     // function _setupTargets()
     //      internal
     //      virtual override
     // {
     //      uint64 index = 1; // 0 is default
     //      _addComponentTargetWithRole(DISTRIBUTION(), index);
     // }


     function _setupTargetAuthorizations()
          internal
          virtual override
     {
          // we don't need distribution, empty implementation is sufficient
     }
}

