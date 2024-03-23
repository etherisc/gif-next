// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount} from "../../types/Amount.sol";
import {NftId} from "../../types/NftId.sol";
import {ClaimId} from "../../types/ClaimId.sol";
import {ReferralId} from "../../types/Referral.sol";
import {RiskId} from "../../types/RiskId.sol";
import {Seconds} from "../../types/Seconds.sol";
import {Timestamp} from "../../types/Timestamp.sol";

interface IPolicy {

    struct Premium {
        // this is the net premium calculated by the product 
        uint256 netPremiumAmount;
        // fullPremium = netPremium + all fixed amounts + all variable amounts (excl commission and minDistribtuionOwnerFee variable part)
        uint256 fullPremiumAmount;
        // premium = fullPremium - discount
        uint256 premiumAmount;
        uint256 productFeeFixAmount;
        uint256 poolFeeFixAmount;
        uint256 bundleFeeFixAmount;
        uint256 distributionFeeFixAmount;
        uint256 productFeeVarAmount;
        uint256 poolFeeVarAmount;
        uint256 bundleFeeVarAmount;
        uint256 distributionFeeVarAmount;
        uint256 distributionOwnerFeeFixAmount;
        // this is the remaining amount when the commission and discount are subtracted from the distribution fee variable part (must be at least the minDistributionOwnerFee)
        uint256 distributionOwnerFeeVarAmount;
        // this value is based on distributor type referenced in the referral 
        uint256 commissionAmount;
        // this is based on referral used
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
        Seconds lifetime;
        bytes applicationData;
        bytes policyData;
        uint16 claimsCount;
        uint16 openClaimsCount;
        Amount payoutAmount;
        Timestamp activatedAt; // time of underwriting
        Timestamp expiredAt; // no new claims (activatedAt + lifetime)
        Timestamp closedAt; // no locked capital (or declinedAt)
    }

    // claimId neeeds to be encoded policyNftId:claimId combination
    struct ClaimInfo {
        Amount claimAmount;
        Amount paidAmount;
        uint8 payoutsCount;
        uint8 openPayoutsCount;
        bytes data;
        // TODO decide if to add processData that may include information supporting confirm or decline
        Timestamp closedAt; // payment of confirmed claim amount (or declinedAt)
    }

    // claimId neeeds to be encoded policyNftId:claimId combination
    struct PayoutInfo {
        ClaimId claimId;
        Amount amount;
        bytes data;
        Timestamp paidAt; // payoment of confirmed claim amount (or declinedAt)
    }
}
