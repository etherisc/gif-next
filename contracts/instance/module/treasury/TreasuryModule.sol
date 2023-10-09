// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {NftId} from "../../../types/NftId.sol";
import {TREASURY} from "../../../types/ObjectType.sol";
import {Fee, FeeLib} from "../../../types/Fee.sol";
import {UFixed, UFixedMathLib} from "../../../types/UFixed.sol";
import {TokenHandler} from "./TokenHandler.sol";
import {IKeyValueStore} from "../../base/IKeyValueStore.sol";
import {ITreasuryModule} from "./ITreasury.sol";
import {ModuleBase} from "../../base/ModuleBase.sol";

abstract contract TreasuryModule is
    ModuleBase,
    ITreasuryModule
{
    // relation of distributor and pool nft map to product nft
    mapping(NftId componentNftId => NftId productNftId) internal _productNft;
    // relation of component nft to token hanlder
    mapping(NftId componentNftId => TokenHandler tokenHandler) internal _tokenHandler;
    Fee internal _zeroFee;
    

    function initializeTreasuryModule(IKeyValueStore keyValueStore) internal {
        _initialize(keyValueStore);
        _zeroFee = FeeLib.zeroFee();
    }

    function registerProductSetup(
        NftId productNftId,
        NftId compensationNftId,
        NftId poolNftId,
        IERC20Metadata token,
        Fee memory policyFee,
        Fee memory processingFee,
        Fee memory stakingFee,
        Fee memory performanceFee
    ) external override // TODO add authz (only component module)
    {
        require(address(_tokenHandler[productNftId]) == address(0), "ERROR:TRS-010:TOKEN_HANDLER_ALREADY_REGISTERED");
        require(_productNft[compensationNftId].eqz(), "ERROR:TRS-011:COMPENSATION_ALREADY_LINKED");
        require(_productNft[poolNftId].eqz(), "ERROR:TRS-012:POOL_ALREADY_LINKED");

        // deploy product specific handler contract
        TokenHandler tokenHandler = new TokenHandler(productNftId, address(token));
        _tokenHandler[productNftId] = tokenHandler;
        _productNft[compensationNftId] = productNftId;
        _productNft[poolNftId] = productNftId;

        TreasuryInfo memory info = TreasuryInfo(
            compensationNftId,
            poolNftId,
            token,
            _zeroFee,
            policyFee,
            processingFee,
            stakingFee,
            performanceFee
        );

        _create(TREASURY(), productNftId, abi.encode(info));
    }

    function setTreasuryInfo(
        NftId productNftId,
        TreasuryInfo memory info
    )
        external
        // TODO add authz (only component module)
        override
    {
        _updateData(TREASURY(), productNftId, abi.encode(info));
    }

    // function setProductFees(
    //     NftId productNftId,
    //     Fee memory policyFee,
    //     Fee memory processingFee
    // ) external override // TODO add authz (only component owner service)
    // {
    //     TreasuryInfo memory info = getTreasuryInfo(productNftId);
    //     require(address(info.token) != address(0), "ERROR:TRS-020:NOT_FOUND");

    //     info.policyFee = policyFee;
    //     info.processingFee = processingFee;

    //     _updateData(TREASURY(), productNftId, abi.encode(info));
    // }

    // function setCompensationFees(
    //     NftId compensationNftId,
    //     Fee memory distributionFee
    // ) external override // TODO add authz (only component owner service)
    // {
    //     NftId productNftId = _productNft[compensationNftId];
    //     TreasuryInfo memory info = getTreasuryInfo(productNftId);
    //     require(address(info.token) != address(0), "ERROR:TRS-030:NOT_FOUND");

    //     info.commissionFee = distributionFee;

    //     _updateData(TREASURY(), productNftId, abi.encode(info));
    // }

    // function setPoolFees(
    //     NftId poolNftId,
    //     Fee memory stakingFee,
    //     Fee memory performanceFee
    // ) external override // TODO add authz (only component owner service)
    // {
    //     NftId productNftId = _productNft[poolNftId];
    //     TreasuryInfo memory info = getTreasuryInfo(productNftId);
    //     require(address(info.token) != address(0), "ERROR:TRS-040:NOT_FOUND");

    //     info.stakingFee = stakingFee;
    //     info.performanceFee = performanceFee;

    //     _updateData(TREASURY(), productNftId, abi.encode(info));
    // }

    function getProductNftId(
        NftId componentNftId
    ) external view returns (NftId productNftId) {
        return _productNft[componentNftId];
    }

    function getTokenHandler(
        NftId componentNftId
    ) external view override returns (TokenHandler tokenHandler) {
        return _tokenHandler[componentNftId];
    }

    function getTreasuryInfo(
        NftId productNftId
    ) public view override returns (TreasuryInfo memory info) {
        return abi.decode(_getData(TREASURY(), productNftId), (TreasuryInfo));
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

    function getZeroFee() external view override returns (Fee memory fee) {
        return _zeroFee;
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
