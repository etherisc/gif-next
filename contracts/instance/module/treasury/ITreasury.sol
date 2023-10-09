// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {NftId} from "../../../types/NftId.sol";
import {UFixed} from "../../../types/UFixed.sol";
import {Fee} from "../../../types/Fee.sol";

import {TokenHandler} from "./TokenHandler.sol";

interface ITreasury {
    // TODO add events
    // TODO add errors

    // treasury info is linked to product nft id
    struct TreasuryInfo {
        NftId compensationNftId;
        NftId poolNftId;
        IERC20Metadata token;
        Fee commissionFee;
        Fee policyFee;
        Fee processingFee;
        Fee stakingFee;
        Fee performanceFee;
    }
}

interface ITreasuryModule is ITreasury {

    function registerProductSetup(
        NftId productNftId,
        NftId distributorNftId,
        NftId poolNftId,
        IERC20Metadata token,
        Fee memory policyFee,
        Fee memory processingFee,
        Fee memory stakingFee,
        Fee memory performanceFee
    ) external;

    function setTreasuryInfo(
        NftId productNftId,
        TreasuryInfo memory info
    ) external;

    function getTreasuryInfo(
        NftId productNftId
    ) external view returns (TreasuryInfo memory info);

    // function setProductFees(
    //     NftId productNftId,
    //     Fee memory policyFee,
    //     Fee memory processingFee
    // ) external;

    // function setCompensationFees(
    //     NftId poolNftId,
    //     Fee memory distributionFee
    // ) external;

    // function setPoolFees(
    //     NftId poolNftId,
    //     Fee memory stakingFee,
    //     Fee memory performanceFee
    // ) external;

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
}
