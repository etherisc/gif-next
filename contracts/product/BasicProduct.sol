// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Fee} from "../type/Fee.sol";
import {IAuthorization} from "../authorization/IAuthorization.sol";
import {IComponents} from "../instance/module/IComponents.sol";
import {NftId} from "../type/NftId.sol";
import {Product} from "../product/Product.sol";

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
        string memory name,
        IComponents.ProductInfo memory productInfo,
        IComponents.FeeInfo memory feeInfo,
        IAuthorization authorization,
        address initialOwner
    )
        internal
        virtual
        onlyInitializing()
    {
        __Product_init(
            registry, 
            instanceNftId, 
            name, 
            productInfo,
            feeInfo,
            authorization, 
            initialOwner, 
            ""); // component data
    }
}