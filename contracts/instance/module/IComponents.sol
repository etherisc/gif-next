// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount} from "../../type/Amount.sol";
import {Fee} from "../../type/Fee.sol";
import {NftId} from "../../type/NftId.sol";
import {TokenHandler} from "../../shared/TokenHandler.sol";
import {UFixed} from "../../type/UFixed.sol";

interface IComponents {

    struct ComponentInfo {
        // slot 0
        string name; // component name (needs to be unique per instance)
        // slot 1
        TokenHandler tokenHandler;
        // slot 2
        bytes data; // will hold component type specific additional info (eg encoded pool info)
    }

    struct ProductInfo {
        bool isProcessingFundedClaims; // custom logic to react to pool events for funded claims
        bool isInterceptingPolicyTransfers; // custom logic for policy nft transfers
        bool hasDistribution; // flag to indicate if distribution is enabled
        uint8 expectedNumberOfOracles; // expected number of oracles
        uint8 numberOfOracles; // actual number of oracles
        NftId poolNftId; // mandatory
        NftId distributionNftId; // 0..1 (optional)
        NftId [] oracleNftId; // 0..n (optional)
    }

    struct FeeInfo {
        // slot 0
        Fee productFee; // product fee on net premium
        // slot 1
        Fee processingFee; // product fee on payout amounts        
        // slot 2
        Fee distributionFee; // distribution fee for sales that do not include commissions
        // slot 3
        Fee minDistributionOwnerFee; // min fee required by distribution owner (not including commissions for distributors)
        // slot 4
        Fee poolFee; // pool fee on net premium
        // slot 5
        Fee stakingFee; // pool fee on staked capital from investor
        // slot 6
        Fee performanceFee; // pool fee on profits from capital investors
    }

    struct PoolInfo {
        Amount maxBalanceAmount; // max balance amount allowed for pool
        bool isInterceptingBundleTransfers; // custom logic for bundle nft transfers
        bool isProcessingConfirmedClaims; // custom logic for claims confirmation
        bool isExternallyManaged; // funding bundles is restricted to book keeping, actual funds may be provided as needed to support payouts
        bool isVerifyingApplications; // underwriting requires the pool component checks/confirms the applications 
        UFixed collateralizationLevel; // factor to calculate collateral for sum insurance (default 100%)
        UFixed retentionLevel; // amount of collateral held in pool (default 100%)
    }
}
