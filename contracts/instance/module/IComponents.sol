// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Amount} from "../../type/Amount.sol";
import {Fee} from "../../type/Fee.sol";
import {NftId} from "../../type/NftId.sol";
import {RoleId} from "../../type/RoleId.sol";
import {TokenHandler} from "../../shared/TokenHandler.sol";
import {UFixed} from "../../type/UFixed.sol";

interface IComponents {

    struct ComponentInfo {
        string name; // component name (needs to be unique per instance)
        IERC20Metadata token;
        TokenHandler tokenHandler;
        address wallet;
        bytes data; // will hold component type specific additional info (eg encoded pool info)
    }

    struct ProductInfo {
        bool isProcessingFundedClaims; // custom logic to react to pool events for funded claims
        bool hasDistribution; // flag to indicate if distribution is enabled
        uint8 expectedNumberOfOracles; // expected number of oracles
        uint8 numberOfOracles; // actual number of oracles
        NftId poolNftId; // mandatory
        NftId distributionNftId; // 0..1 (optional)
        NftId [] oracleNftId; // 0..n (optional)
        Fee productFee; // product fee on net premium
        Fee processingFee; // product fee on payout amounts        
        Fee distributionFee; // distribution fee for sales that do not include commissions
        Fee minDistributionOwnerFee; // min fee required by distribution owner (not including commissions for distributors)
        Fee poolFee; // pool fee on net premium
        Fee stakingFee; // pool fee on staked capital from investor
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
