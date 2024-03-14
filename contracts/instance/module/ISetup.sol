// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Fee} from "../../types/Fee.sol";
import {NftId} from "../../types/NftId.sol";
import {UFixed} from "../../types/UFixed.sol";
import {TokenHandler} from "../../shared/TokenHandler.sol";

interface ISetup {
    struct ProductSetupInfo {
        IERC20Metadata token;
        TokenHandler tokenHandler;
        NftId distributionNftId;
        NftId poolNftId;
        Fee distributionFee; // default distribution fee (no referral id)
        Fee productFee; // product fee on net premium
        Fee processingFee; // product fee on payout amounts
        Fee poolFee; // pool fee on net premium
        Fee stakingFee; // pool fee on staked capital from investor
        Fee performanceFee; // pool fee on profits from capital investors
        bool isIntercepting; // intercepts nft transfers (for products)
        address wallet;
    }

    struct DistributionSetupInfo {
        NftId productNftId;
        TokenHandler tokenHandler;
        Fee distributionFee; // default distribution fee (no referral id)
        address wallet;
        uint256 sumDistributionFees;
    }

    struct PoolSetupInfo {
        NftId productNftId;
        TokenHandler tokenHandler;
        bool isInterceptingBundleTransfers; // intercepts nft transfers for bundles
        bool isExternallyManaged; // funding bundles is restricted to book keeping, actual funds may be provided as needed to support payouts
        bool isVerifyingApplications; // underwriting requires the pool component checks/confirms the applications 
        UFixed collateralizationLevel; // factor to calculate collateral for sum insurance (default 100%)
        UFixed retentionLevel; // amount of collateral held in pool (default 100%)
        Fee poolFee; // pool fee on net premium
        Fee stakingFee; // pool fee on staked capital from investor
        Fee performanceFee; // pool fee on profits from capital investors
        address wallet;
    }
}
