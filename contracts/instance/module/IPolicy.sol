// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {NftId} from "../../types/NftId.sol";
import {ClaimId} from "../../types/ClaimId.sol";
import {ReferralId} from "../../types/Referral.sol";
import {RiskId} from "../../types/RiskId.sol";
import {Timestamp} from "../../types/Timestamp.sol";

interface IPolicy {

    struct Premium {
        uint256 netPremiumAmount;
        // fullPremium = netPremium + productFee + poolFee + bundleFee + distributionOwnerFee + comission
        uint256 fullPremiumAmount;
        // premium = fullPremium - discount
        uint256 premiumAmount;
        uint256 productFeeAmount;
        uint256 poolFeeAmount;
        uint256 bundleFeeAmount;
        uint256 distributionOwnerFeeAmount;
        uint256 commissionAmount;
        uint256 discountAmount;
    }

    /// @dev policy data for the full policy lifecycle
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
        ClaimId claimId;
        uint256 amount;
        bytes data;
        Timestamp paidAt; // payoment of confirmed claim amount (or declinedAt)
    }
}
