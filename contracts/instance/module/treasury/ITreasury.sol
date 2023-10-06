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

    struct ProductSetup {
        NftId nftId;
        NftId distributorNftId;
        NftId poolNftId;
        IERC20Metadata token;
        address wallet;
        Fee policyFee;
        Fee processingFee;
    }

    struct DistributorSetup {
        NftId distributorNftId;
        address wallet;
        Fee commissionFee;
    }

    struct PoolSetup { 
        NftId nftId;
        NftId productNftId;// TODO notified when product is connected...
        IERC20Metadata token;
        address wallet;
        Fee stakingFee;
        Fee performanceFee;
    }
}

interface ITreasuryModule is ITreasury {

    function registerProduct(
        NftId productNftId,
        NftId distributorNftId,
        NftId poolNftId,
        IERC20Metadata token,
        address wallet,
        Fee memory policyFee,
        Fee memory processingFee
    ) external;

    function setProductFees(
        NftId productNftId,
        Fee memory policyFee,
        Fee memory processingFee
    ) external;

    function registerPool(
        NftId poolNftId,
        NftId productNftId,
        IERC20Metadata token,
        address wallet,
        Fee memory stakingFee,
        Fee memory performanceFee
    ) external;

    function setPoolFees(
        NftId poolNftId,
        Fee memory stakingFee,
        Fee memory performanceFee
    ) external;

    function getTokenHandler(
        NftId componentNftId
    ) external view returns (TokenHandler tokenHandler);

    function getProductSetup(
        NftId productNftId
    ) external view returns (ProductSetup memory setup);

    function getPoolSetup(
        NftId poolNftId
    ) external view returns (PoolSetup memory setup);

    function calculateFeeAmount(
        uint256 amount,
        Fee memory fee
    ) external pure returns (uint256 feeAmount, uint256 netAmount);

    function getFee(
        UFixed fractionalFee, 
        uint256 fixedFee
    ) external pure returns (Fee memory fee);

    function getZeroFee() external pure returns (Fee memory fee);

    function getUFixed(
        uint256 a
    ) external pure returns (UFixed);

    function getUFixed(
        uint256 a, 
        int8 exp
    ) external pure returns (UFixed);
}
