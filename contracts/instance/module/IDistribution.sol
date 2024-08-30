// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {DistributorType} from "../../type/DistributorType.sol";
import {NftId} from "../../type/NftId.sol";
import {Seconds} from "../../type/Seconds.sol";
import {Timestamp} from "../../type/Timestamp.sol";
import {UFixed} from "../../type/UFixed.sol";

interface IDistribution {

    struct DistributorTypeInfo {
        // slot 0
        UFixed minDiscountPercentage;
        NftId distributionNftId;
        // slot 1
        UFixed maxDiscountPercentage;
        uint32 maxReferralCount;
        Seconds maxReferralLifetime;
        bool allowSelfReferrals;
        bool allowRenewals;
        // slot 2
        UFixed commissionPercentage;
        // slot 3
        string name;                
        // slot 4
        bytes data;
    }

    struct DistributorInfo {
        // slot 0
        DistributorType distributorType;
        bool active;
        uint32 numPoliciesSold;
        // slot 1
        bytes data;
    }

    struct ReferralInfo {
        // slot 0
        NftId distributionNftId;
        NftId distributorNftId;
        uint32 maxReferrals;
        uint32 usedReferrals;
        // slot 1
        UFixed discountPercentage;
        Timestamp expiryAt;
        // slot 2
        string referralCode;
        // slot 3
        bytes data;
    }

}
