// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccess} from "../authorization/IAccess.sol";
import {IInstanceLinkedComponent} from "../shared/IInstanceLinkedComponent.sol";

import {Authorization} from "../authorization/Authorization.sol";
import {BasicDistribution} from "./BasicDistribution.sol"; 
import {Distribution} from "./Distribution.sol";
import {COMPONENT, DISTRIBUTION} from "../type/ObjectType.sol";
import {RoleId, PUBLIC_ROLE} from "../type/RoleId.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";


contract BasicDistributionAuthorization
     is Authorization
{

     constructor(string memory distributionlName)
          Authorization(distributionlName, DISTRIBUTION(), true, true)
     {}

     function _setupServiceTargets()
          internal
          virtual override
     {
          _addServiceTargetWithRole(COMPONENT());
     }

     function _setupTokenHandlerAuthorizations() internal virtual override {
          IAccess.FunctionInfo[] storage functions;
          functions = _authorizeForTarget(getTokenHandlerName(), getServiceRole(COMPONENT()));
          _authorize(functions, TokenHandler.approve.selector, "approve");
          _authorize(functions, TokenHandler.setWallet.selector, "setWallet");
          _authorize(functions, TokenHandler.pushFeeToken.selector, "pushFeeToken");

          // authorize token handler functions for pool service role
          functions = _authorizeForTarget(getTokenHandlerName(), getServiceRole(DISTRIBUTION()));
          _authorize(functions, TokenHandler.pushToken.selector, "pushToken");
     }

     function _setupTargetAuthorizations()
          internal
          virtual override
     {
          IAccess.FunctionInfo[] storage functions;

          // authorize public role (open access to any account, only allows to lock target)
          functions = _authorizeForTarget(getMainTargetName(), PUBLIC_ROLE());
          _authorize(functions, BasicDistribution.setFees.selector, "setFees");
          _authorize(functions, BasicDistribution.createDistributorType.selector, "createDistributorType");
          _authorize(functions, BasicDistribution.createDistributor.selector, "createDistributor");
          _authorize(functions, BasicDistribution.changeDistributorType.selector, "changeDistributorType");
          _authorize(functions, BasicDistribution.createReferral.selector, "createReferral");
          
          _authorize(functions, IInstanceLinkedComponent.withdrawFees.selector, "withdrawFees");
          _authorize(functions, Distribution.withdrawCommission.selector, "withdrawCommission");
     }
}

