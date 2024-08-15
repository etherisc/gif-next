// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Authorization} from "../authorization/Authorization.sol";
import {BasicProduct} from "./BasicProduct.sol"; 
import {PRODUCT} from "../type/ObjectType.sol";
import {IAccess} from "../authorization/IAccess.sol";
import {IInstanceLinkedComponent} from "../shared/IInstanceLinkedComponent.sol";
import {RoleId, PUBLIC_ROLE} from "../type/RoleId.sol";


contract BasicProductAuthorization
     is Authorization
{

     constructor(string memory componentName)
          Authorization(componentName)
     {}

     function _setupTargets()
          internal
          virtual override
     {
          // basic component target
          _addComponentTargetWithRole(PRODUCT()); 
     }


     function _setupTargetAuthorizations()
          internal
          virtual override
     {
          IAccess.FunctionInfo[] storage functions;

          // authorize public role (open access to any account, only allows to lock target)
          functions = _authorizeForTarget(getTargetName(), PUBLIC_ROLE());
          _authorize(functions, BasicProduct.setFees.selector, "setFees");
          _authorize(functions, IInstanceLinkedComponent.withdrawFees.selector, "withdrawFees");
     }
}

