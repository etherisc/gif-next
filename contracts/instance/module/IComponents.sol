// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Fee} from "../../types/Fee.sol";
import {NftId} from "../../types/NftId.sol";
import {RoleId} from "../../types/RoleId.sol";
import {TokenHandler} from "../../shared/TokenHandler.sol";
import {UFixed} from "../../types/UFixed.sol";

interface IComponents {

    struct ComponentInfo {
        string name; // component name (needs to be unique per instance)
        IERC20Metadata token;
        TokenHandler tokenHandler;
        address wallet;
        bytes data; // will hold component type specific additional info (eg encoded pool info)
    }

    struct PoolInfo {
        NftId productNftId; // the nft of the product this pool is linked to
        RoleId bundleOwnerRole; // the required role for bundle owners
        uint256 maxCapitalAmount; // max capital amount allowed for pool
        bool isInterceptingBundleTransfers; // intercepts nft transfers for bundles
        bool isExternallyManaged; // funding bundles is restricted to book keeping, actual funds may be provided as needed to support payouts
        bool isVerifyingApplications; // underwriting requires the pool component checks/confirms the applications 
        UFixed collateralizationLevel; // factor to calculate collateral for sum insurance (default 100%)
        UFixed retentionLevel; // amount of collateral held in pool (default 100%)
        Fee poolFee; // pool fee on net premium
        Fee stakingFee; // pool fee on staked capital from investor
        Fee performanceFee; // pool fee on profits from capital investors
    }
}
