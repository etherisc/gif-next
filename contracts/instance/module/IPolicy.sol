// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {NftId} from "../../types/NftId.sol";
import {NumberId} from "../../types/NumberId.sol";
import {ReferralId} from "../../types/Referral.sol";
import {RiskId} from "../../types/RiskId.sol";
import {Timestamp} from "../../types/Timestamp.sol";

interface IPolicy {
    struct PolicyInfo {
        NftId productNftId;
        NftId bundleNftId;
        ReferralId referralId;
        RiskId riskId;
        uint256 sumInsuredAmount;
        uint256 premiumAmount;
        uint256 premiumPaidAmount;
        uint256 lifetime;
        bytes applicationData;
        bytes policyData;
        uint16 claimsCount;
        uint16 openClaimsCount;
        uint256 payoutAmount;
        Timestamp activatedAt; // time of underwriting
        Timestamp expiredAt; // no new claims (activatedAt + lifetime)
        Timestamp closedAt; // no locked capital (or declinedAt)
    }

    // claimId neeeds to be encoded policyNftId:claimId combination
    struct ClaimInfo {
        uint256 claimAmount;
        uint256 paidAmount;
        bytes data;
        Timestamp closedAt; // payoment of confirmed claim amount (or declinedAt)
    }

    // claimId neeeds to be encoded policyNftId:claimId combination
    struct PayoutInfo {
        NumberId claimId;
        uint256 amount;
        bytes data;
        Timestamp paidAt; // payoment of confirmed claim amount (or declinedAt)
    }
}
