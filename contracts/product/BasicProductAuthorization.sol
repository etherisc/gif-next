// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccess} from "../authorization/IAccess.sol";
import {IInstanceLinkedComponent} from "../shared/IInstanceLinkedComponent.sol";

import {Authorization} from "../authorization/Authorization.sol";
import {BasicProduct} from "./BasicProduct.sol"; 
import {COMPONENT, PRODUCT, POLICY} from "../type/ObjectType.sol";
import {RoleId, PUBLIC_ROLE} from "../type/RoleId.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";


contract BasicProductAuthorization
     is Authorization
{

     constructor(string memory componentName)
          Authorization(componentName, PRODUCT())
     {}

     function _setupServiceTargets()
          internal
          virtual override
     {
          _addServiceTargetWithRole(COMPONENT());
          _addServiceTargetWithRole(POLICY());
     }

     function _setupTokenHandlerAuthorizations() internal virtual override {
          // authorize token handler functions for component service role
          IAccess.FunctionInfo[] storage functions;
          functions = _authorizeForTarget(getTokenHandlerName(), getServiceRole(COMPONENT()));
          _authorize(functions, TokenHandler.approve.selector, "approve");
          _authorize(functions, TokenHandler.setWallet.selector, "setWallet");
          _authorize(functions, TokenHandler.pushFeeToken.selector, "pushFeeToken");

          // authorize token handler functions for pool service role
          functions = _authorizeForTarget(getTokenHandlerName(), getServiceRole(POLICY()));
          _authorize(functions, TokenHandler.pullToken.selector, "pullToken");
          _authorize(functions, TokenHandler.pushToken.selector, "pushToken");
     }

     function _setupTargetAuthorizations()
          internal
          virtual override
     {
          IAccess.FunctionInfo[] storage functions;

          // authorize public role (open access to any account, only allows to lock target)
          functions = _authorizeForTarget(getMainTargetName(), PUBLIC_ROLE());
          _authorize(functions, BasicProduct.setFees.selector, "setFees");
          _authorize(functions, IInstanceLinkedComponent.withdrawFees.selector, "withdrawFees");
     }
}

