// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Authorization} from "../authorization/Authorization.sol";
import {BasicDistribution} from "./BasicDistribution.sol"; 
import {DISTRIBUTION} from "../type/ObjectType.sol";
import {IAccess} from "../authorization/IAccess.sol";
import {IInstanceLinkedComponent} from "../shared/IInstanceLinkedComponent.sol";
import {PUBLIC_ROLE} from "../../contracts/type/RoleId.sol";
import {RoleId} from "../type/RoleId.sol";


contract BasicDistributionAuthorization
     is Authorization
{

     constructor(string memory distributionlName)
          Authorization(distributionlName)
     {}

     function _setupTargets()
          internal
          virtual override
     {
          _addComponentTargetWithRole(DISTRIBUTION()); // basic target
     }


     function _setupTargetAuthorizations()
          internal
          virtual override
     {
          IAccess.FunctionInfo[] storage functions;

          // authorize public role (open access to any account, only allows to lock target)
          functions = _authorizeForTarget(getTargetName(), PUBLIC_ROLE());
          _authorize(functions, BasicDistribution.setFees.selector, "setFees");
          _authorize(functions, BasicDistribution.createDistributorType.selector, "createDistributorType");
          _authorize(functions, BasicDistribution.createDistributor.selector, "createDistributor");
          _authorize(functions, BasicDistribution.updateDistributorType.selector, "updateDistributorType");
          _authorize(functions, BasicDistribution.createReferral.selector, "createReferral");
          
          _authorize(functions, IInstanceLinkedComponent.withdrawFees.selector, "withdrawFees");
     }
}

