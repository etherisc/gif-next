// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccess} from "../../../contracts/authorization/IAccess.sol";
import {IInstanceLinkedComponent} from "../../../contracts/shared/IInstanceLinkedComponent.sol";
import {IProductComponent} from "../../../contracts/product/IProductComponent.sol";

import {Authorization} from "../../../contracts/authorization/Authorization.sol";
import {BasicProduct} from "../../../contracts/product/BasicProduct.sol"; 
import {BasicProductAuthorization} from "../../../contracts/product/BasicProductAuthorization.sol"; 
import {SimpleProduct} from "../../../contracts/examples/unpermissioned/SimpleProduct.sol";
import {PRODUCT, POOL} from "../../../contracts/type/ObjectType.sol";
import {PUBLIC_ROLE} from "../../../contracts/type/RoleId.sol";
import {RoleId} from "../../../contracts/type/RoleId.sol";


contract ProductWithReinsuranceAuthorization
     is BasicProductAuthorization
{

     constructor()
          BasicProductAuthorization("ProductWithReinsurance")
     {}

     function _setupTargetAuthorizations()
          internal
          virtual override
     {
          super._setupTargetAuthorizations();

          // authorize pool service for callback
          IAccess.FunctionInfo[] storage functions;
          functions = _authorizeForTarget(getMainTargetName(), getServiceRole(POOL()));
          _authorize(functions, IProductComponent.processFundedClaim.selector, "processFundedClaim");
     }
}

