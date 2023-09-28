// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {NftId} from "../../../types/NftId.sol";
import {Fee, feeIsZero, toFee, zeroFee} from "../../../types/Fee.sol";
import {UFixed, UFixedMathLib} from "../../../types/UFixed.sol";
import {TokenHandler} from "./TokenHandler.sol";
import {ITreasuryModule} from "./ITreasury.sol";

abstract contract TreasuryModule is ITreasuryModule {
    mapping(NftId productNftId => ProductSetup setup) private _productSetup;
    mapping(NftId distributorNftId => DistributorSetup setup)
        private _distributorSetup;
    mapping(NftId poolNftId => PoolSetup setup) private _poolSetup;

    function registerProduct(
        NftId productNftId,
        NftId distributorNftId,
        NftId poolNftId,
        IERC20Metadata token,
        address wallet,
        Fee memory policyFee,
        Fee memory processingFee
    ) external override // TODO add authz (only component module)
    {
        // TODO add validation

        // deploy product specific handler contract
        TokenHandler tokenHandler = new TokenHandler(productNftId, address(token));

        _productSetup[productNftId] = ProductSetup(
            productNftId,
            distributorNftId,
            poolNftId,
            token,
            tokenHandler,
            wallet,
            policyFee,
            processingFee
        );

        // TODO add logging
    }

    function setProductFees(
        NftId productNftId,
        Fee memory policyFee,
        Fee memory processingFee
    ) external override // TODO add authz (only component owner service)
    {
        // TODO add validation

        ProductSetup storage setup = _productSetup[productNftId];
        setup.policyFee = policyFee;
        setup.processingFee = processingFee;

        // TODO add logging
    }

    function registerPool(
        NftId poolNftId,
        address wallet,
        Fee memory stakingFee,
        Fee memory performanceFee
    ) external override // TODO add authz (only component module)
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

    function setPoolFees(
        NftId poolNftId,
        Fee memory stakingFee,
        Fee memory performanceFee
    ) external override // TODO add authz (only component owner service)
    {
        // TODO add validation

        PoolSetup storage setup = _poolSetup[poolNftId];
        setup.stakingFee = stakingFee;
        setup.performanceFee = performanceFee;

        // TODO add logging
    }

    function getTokenHandler(
        NftId productNftId
    ) external view override returns (TokenHandler tokenHandler) {
        return _productSetup[productNftId].tokenHandler;
    }

    function getProductSetup(
        NftId productNftId
    ) external view override returns (ProductSetup memory setup) {
        return _productSetup[productNftId];
    }

    function getPoolSetup(
        NftId poolNftId
    ) external view override returns (PoolSetup memory setup) {
        return _poolSetup[poolNftId];
    }

    function calculateFeeAmount(
        uint256 amount,
        Fee memory fee
    ) public pure override returns (uint256 feeAmount, uint256 netAmount) {
        UFixed fractionalAmount = UFixedMathLib.toUFixed(amount) *
            fee.fractionalFee;
        feeAmount = fractionalAmount.toInt() + fee.fixedFee;
        netAmount = amount - feeAmount;
    }

    function getFee(
        UFixed fractionalFee, 
        uint256 fixedFee
    ) external pure override returns (Fee memory fee) {
        return toFee(fractionalFee, fixedFee);
    }

    function getZeroFee() external pure override returns (Fee memory fee) {
        return zeroFee();
    }

    function getUFixed(
        uint256 a
    ) external pure override returns (UFixed) {
        return UFixedMathLib.toUFixed(a);
    }

    function getUFixed(
        uint256 a, 
        int8 exp
    ) external pure returns (UFixed)
    {
        return UFixedMathLib.toUFixed(a, exp);
    }
}
