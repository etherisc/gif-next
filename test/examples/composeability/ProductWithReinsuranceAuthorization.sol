// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Authorization} from "../../../contracts/authorization/Authorization.sol";
import {BasicProduct} from "../../../contracts/product/BasicProduct.sol"; 
import {SimpleProduct} from "../../../contracts/examples/unpermissioned/SimpleProduct.sol";
import {PRODUCT, POOL} from "../../../contracts/type/ObjectType.sol";
import {IAccess} from "../../../contracts/authorization/IAccess.sol";
import {IInstanceLinkedComponent} from "../../../contracts/shared/IInstanceLinkedComponent.sol";
import {IProductComponent} from "../../../contracts/product/IProductComponent.sol";
import {PUBLIC_ROLE} from "../../../contracts/type/RoleId.sol";
import {RoleId} from "../../../contracts/type/RoleId.sol";


contract ProductWithReinsuranceAuthorization
     is Authorization
{

     constructor()
          Authorization("ProductWithReinsurance", PRODUCT())
     {}

     function _setupTargetAuthorizations()
          internal
          virtual override
     {
          IAccess.FunctionInfo[] storage functions;

          // authorize public role (open access to any account, only allows to lock target)
          functions = _authorizeForTarget(getMainTargetName(), PUBLIC_ROLE());
          _authorize(functions, BasicProduct.setFees.selector, "setFees");
          _authorize(functions, SimpleProduct.approveTokenHandler.selector, "approveTokenHandler");
          _authorize(functions, IInstanceLinkedComponent.withdrawFees.selector, "withdrawFees");

          // authorize pool service for callback
          functions = _authorizeForTarget(getMainTargetName(), getServiceRole(POOL()));
          _authorize(functions, IProductComponent.processFundedClaim.selector, "processFundedClaim");
     }
}

