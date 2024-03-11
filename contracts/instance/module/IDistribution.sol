// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {DistributorType} from "../../types/DistributorType.sol";
import {NftId} from "../../types/NftId.sol";
import {Timestamp} from "../../types/Timestamp.sol";
import {UFixed} from "../../types/UFixed.sol";

interface IDistribution {

    struct DistributorTypeInfo {
        string name;
        UFixed minDiscountPercentage;
        UFixed maxDiscountPercentage;
        UFixed commissionPercentage;
        uint32 maxReferralCount;
        uint32 maxReferralLifetime;
        bool allowSelfReferrals;
        bool allowRenewals;
        bytes data;
    }

    struct DistributorInfo {
        DistributorType distributorType;
        bool active;
        bytes data;
        // TODO: track commission, number of sold policies, etc.
    }

    struct ReferralInfo {   
        NftId distributorNftId;
        string referralCode;
        UFixed discountPercentage;
        uint32 maxReferrals;
        uint32 usedReferrals;
        Timestamp expiryAt;
        bytes data;
    }

}
