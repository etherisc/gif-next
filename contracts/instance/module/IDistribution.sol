// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount} from "../../type/Amount.sol";
import {DistributorType} from "../../type/DistributorType.sol";
import {NftId} from "../../type/NftId.sol";
import {Timestamp} from "../../type/Timestamp.sol";
import {UFixed} from "../../type/UFixed.sol";

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
        uint32 numPoliciesSold;
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
