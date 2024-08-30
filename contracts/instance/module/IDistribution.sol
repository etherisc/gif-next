// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {DistributorType} from "../../type/DistributorType.sol";
import {NftId} from "../../type/NftId.sol";
import {Seconds} from "../../type/Seconds.sol";
import {Timestamp} from "../../type/Timestamp.sol";
import {UFixed} from "../../type/UFixed.sol";

interface IDistribution {

    struct DistributorTypeInfo {
        UFixed minDiscountPercentage;
        UFixed maxDiscountPercentage;
        uint32 maxReferralCount;
        Seconds maxReferralLifetime;
        bool allowSelfReferrals;
        bool allowRenewals;
        UFixed commissionPercentage;
        NftId distributionNftId;
        string name;                
        bytes data;
    }

    struct DistributorInfo {
        DistributorType distributorType;
        bool active;
        uint32 numPoliciesSold;
        bytes data;
    }

    struct ReferralInfo {
        NftId distributionNftId;
        NftId distributorNftId;
        string referralCode;
        UFixed discountPercentage;
        uint32 maxReferrals;
        uint32 usedReferrals;
        Timestamp expiryAt;
        bytes data;
    }

}
