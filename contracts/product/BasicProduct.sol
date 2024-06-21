// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Amount, AmountLib} from "../type/Amount.sol";
import {ClaimId} from "../type/ClaimId.sol";
import {InstanceLinkedComponent} from "../shared/InstanceLinkedComponent.sol";
import {Fee, FeeLib} from "../type/Fee.sol";
import {IRisk} from "../instance/module/IRisk.sol";
import {IApplicationService} from "./IApplicationService.sol";
import {IAuthorization} from "../authorization/IAuthorization.sol";
import {IComponentService} from "../shared/IComponentService.sol";
import {IPolicyService} from "./IPolicyService.sol";
import {IProductService} from "./IProductService.sol";
import {IClaimService} from "./IClaimService.sol";
import {IPricingService} from "./IPricingService.sol";
import {IProductComponent} from "./IProductComponent.sol";
import {NftId, NftIdLib} from "../type/NftId.sol";
import {Product} from "../product/Product.sol";
import {PayoutId} from "../type/PayoutId.sol";
import {COMPONENT, PRODUCT, APPLICATION, POLICY, CLAIM, PRICE } from "../type/ObjectType.sol";
import {ReferralId} from "../type/Referral.sol";
import {RiskId, RiskIdLib} from "../type/RiskId.sol";
import {Seconds} from "../type/Seconds.sol";
import {StateId} from "../type/StateId.sol";
import {Timestamp} from "../type/Timestamp.sol";

import {TokenHandler} from "../shared/TokenHandler.sol";

import {InstanceReader} from "../instance/InstanceReader.sol";
import {IPolicy} from "../instance/module/IPolicy.sol";
import {IComponents} from "../instance/module/IComponents.sol";
import {Pool} from "../pool/Pool.sol";
import {Distribution} from "../distribution/Distribution.sol";

abstract contract BasicProduct is
    Product
{
 
    function setFees(
        Fee memory productFee,
        Fee memory processingFee
    )
        external
        virtual
        onlyOwner()
        restricted()
    {
        _setFees(productFee, processingFee);
    }


    function _initializeBasicProduct(
        address registry,
        NftId instanceNftId,
        IAuthorization authorization,
        address initialOwner,
        string memory name,
        address token,
        bool isInterceptor,
        address pool,
        address distribution
    )
        internal
        virtual
        onlyInitializing()
    {
        _initializeProduct(
            registry, 
            instanceNftId, 
            authorization, 
            initialOwner, 
            name, 
            token, 
            isInterceptor, 
            pool,
            distribution,
            "", //registryData, 
            ""); // componentData
    }
}