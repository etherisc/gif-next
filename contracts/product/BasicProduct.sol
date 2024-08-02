// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Fee} from "../type/Fee.sol";
import {IAuthorization} from "../authorization/IAuthorization.sol";
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
        IAuthorization authorization,
        address initialOwner,
        string memory name,
        address token,
        bool isInterceptor,
        bool hasDistribution,
        uint8 numberOfOracles
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
            false, // is processing funded claims
            hasDistribution,
            numberOfOracles,
            ""); // component data
    }
}