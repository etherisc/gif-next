// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {NftId} from "../../../types/NftId.sol";
import {Fee, FeeLib} from "../../../types/Fee.sol";
import {UFixed, UFixedMathLib} from "../../../types/UFixed.sol";
import {TokenHandler} from "./TokenHandler.sol";
import {ITreasuryModule} from "./ITreasury.sol";

abstract contract TreasuryModule is ITreasuryModule {
    mapping(NftId productNftId => ProductSetup setup) private _productSetup;
    mapping(NftId distributorNftId => DistributorSetup setup)
        private _distributorSetup;
    mapping(NftId poolNftId => PoolSetup setup) private _poolSetup;
    mapping(NftId componentNftId => TokenHandler tokenHanlder) _tokenHandler;

    function registerProduct(ProductSetup memory setup)
        external override // TODO add authz (only component module)
    {
        NftId productNftId = setup.nftId;
        NftId poolNftId = setup.poolNftId;
        NftId distributorNftId = setup.poolNftId;

        require(address(_tokenHandler[productNftId]) == address(0), "ERROR:TRS-010:TOKEN_HANDLER_ALREADY_REGISTERED");
        require(address(_tokenHandler[poolNftId]) == address(0), "ERROR:TRS-011:TOKEN_HANDLER_ALREADY_REGISTERED");
        require(address(_tokenHandler[distributorNftId]) == address(0), "ERROR:TRS-012:TOKEN_HANDLER_ALREADY_REGISTERED");
        // TODO add additional validations

        // deploy product specific handler contract
        TokenHandler tokenHandler = new TokenHandler(productNftId, address(setup.token));
        _tokenHandler[productNftId] = tokenHandler;
        _tokenHandler[poolNftId] = tokenHandler;
        _tokenHandler[distributorNftId] = tokenHandler;

        // create product setup
        _productSetup[productNftId] = setup;

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

    function registerPool(PoolSetup memory setup) external override // TODO add authz (only component module)
    {
        require(
            _poolSetup[setup.nftId].nftId.eqz(), //TODO use .objectType as existance check against rewrite? -> delete nftId from setup? -> save space
            "ERROR:PL-010:ALREADY_CREATED");

        _poolSetup[setup.nftId] = setup;

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
        NftId componentNftId
    ) external view override returns (TokenHandler tokenHandler) {
        return _tokenHandler[componentNftId];
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
        return FeeLib.calculateFee(amount, fee);
    }

    function getFee(
        UFixed fractionalFee, 
        uint256 fixedFee
    ) external pure override returns (Fee memory fee) {
        return FeeLib.toFee(fractionalFee, fixedFee);
    }

    function getZeroFee() external pure override returns (Fee memory fee) {
        return FeeLib.zeroFee();
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
