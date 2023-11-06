// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin5/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IDistributionComponent} from "../../../components/IDistributionComponent.sol";
import {IPoolComponent} from "../../../components/IPoolComponent.sol";
import {IProductComponent} from "../../../components/IProductComponent.sol";
import {IRegistryService} from "../../../../contracts/registry/IRegistryService.sol";

import {NftId} from "../../../types/NftId.sol";
import {UFixed} from "../../../types/UFixed.sol";
import {Fee} from "../../../types/Fee.sol";

import {TokenHandler} from "./TokenHandler.sol";

interface ITreasury {
    // TODO add events
    // TODO add errors

    // treasury info is linked to product nft id
    struct TreasuryInfo {
        NftId poolNftId;
        NftId distributionNftId;
        IERC20Metadata token;
        Fee productFee; // product fee on net premium
        Fee processingFee; // product fee on payout amounts
        Fee poolFee; // pool fee on net premium
        Fee stakingFee; // pool fee on staked capital from investor
        Fee performanceFee; // pool fee on profits from capital investors
        Fee distributionFee; // default distribution fee (no referral id)
    }
}

interface ITreasuryModule is ITreasury {

    function registerProductSetup(
        NftId productNftId,
        TreasuryInfo memory info
    ) external;

    function setTreasuryInfo(
        NftId productNftId,
        TreasuryInfo memory info
    ) external;

    function hasTreasuryInfo(
        NftId productNftId
    ) external view returns (bool hasInfo);

    function getTreasuryInfo(
        NftId productNftId
    ) external view returns (TreasuryInfo memory info);

    function getProductNftId(
        NftId componentNftId
    ) external view returns (NftId productNftId);

    function getTokenHandler(
        NftId componentNftId
    ) external view returns (TokenHandler tokenHandler);

    function calculateFeeAmount(
        uint256 amount,
        Fee memory fee
    ) external pure returns (uint256 feeAmount, uint256 netAmount);

    function getFee(
        UFixed fractionalFee, 
        uint256 fixedFee
    ) external pure returns (Fee memory fee);

    function getZeroFee() external view returns (Fee memory fee);

    function getUFixed(
        uint256 a
    ) external pure returns (UFixed);

    function getUFixed(
        uint256 a, 
        int8 exp
    ) external pure returns (UFixed);

    function getRegistryService() external view returns(IRegistryService);
}
