// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {NftId} from "../../types/NftId.sol";
import {Fee} from "../../types/Fee.sol";
import {UFixed} from "../../types/UFixed.sol";
import {IProductComponent} from "../../components/IProduct.sol";
import {ITreasuryModule} from "./ITreasury.sol";

contract TreasuryModule is ITreasuryModule {

    mapping(NftId productNftId => ProductSetup setup) private _productSetup;
    mapping(NftId distributorNftId => DistributorSetup setup) private _distributorSetup;
    mapping(NftId poolNftId => PoolSetup setup) private _poolSetup;

    function registerProduct(
        NftId productNftId,
        NftId distributorNftId,
        NftId poolNftId,
        IERC20 token,
        address wallet,
        Fee memory policyFee,
        Fee memory processingFee
    )
        external
        override
        // TODO add authz (only component module)
    {
        // TODO add validation

        _productSetup[productNftId] = ProductSetup(
            productNftId,
            distributorNftId,
            poolNftId,
            token,
            wallet,
            policyFee,
            processingFee
        );

        // TODO add logging
    }

    function registerPool(
            NftId poolNftId,
            address wallet,
            Fee memory stakingFee,
            Fee memory performanceFee
    )
        external
        override
        // TODO add authz (only component module)
    {
        // TODO add validation

        _poolSetup[poolNftId] = PoolSetup(
            poolNftId,
            wallet,
            stakingFee,
            performanceFee
        );

        // TODO add logging
    }

    function getProductSetup(NftId productNftId)
        external
        view
        override
        returns(ProductSetup memory setup)
    {
        return _productSetup[productNftId];
    }

    function getPoolSetup(NftId poolNftId) 
        external
        view
        override
        returns(PoolSetup memory setup)
    {
        return _poolSetup[poolNftId];
    }

    function processPremium(NftId policyNftId)
        external
        // TODO add authz (only product service)
    {

    }
}