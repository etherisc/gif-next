// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount} from "../../type/Amount.sol";
import {NftId} from "../../type/NftId.sol";
import {ClaimId} from "../../type/ClaimId.sol";
import {ReferralId} from "../../type/Referral.sol";
import {RiskId} from "../../type/RiskId.sol";
import {Seconds} from "../../type/Seconds.sol";
import {Timestamp} from "../../type/Timestamp.sol";

interface IPolicy {

    struct PremiumInfo {
        // premium splitting per target wallet
        Amount productFeeAmount;
        Amount distributionFeeAndCommissionAmount;
        Amount poolPremiumAndFeeAmount;

        // detailed positions
        // this is the net premium calculated by the product 
        Amount netPremiumAmount;
        // fullPremium = netPremium + all fixed amounts + all variable amounts (excl commission and minDistribtuionOwnerFee variable part)
        Amount fullPremiumAmount;
        // effective premium = fullPremium - discount 
        Amount premiumAmount;
        Amount productFeeFixAmount;
        Amount poolFeeFixAmount;
        Amount bundleFeeFixAmount;
        Amount distributionFeeFixAmount;
        Amount productFeeVarAmount;
        Amount poolFeeVarAmount;
        Amount bundleFeeVarAmount;
        Amount distributionFeeVarAmount;
        Amount distributionOwnerFeeFixAmount;
        // this is the remaining amount when the commission and discount are subtracted from the distribution fee variable part (must be at least the minDistributionOwnerFee)
        Amount distributionOwnerFeeVarAmount;
        // this value is based on distributor type referenced in the referral 
        Amount commissionAmount;
        // this is based on referral used
        Amount discountAmount;
    }

    /// @dev policy data for the full policy lifecycle
    struct PolicyInfo {
        // application data, no changes after applying for a policy
        NftId productNftId;
        NftId bundleNftId;
        ReferralId referralId;
        RiskId riskId;
        Amount sumInsuredAmount;
        Amount premiumAmount; // expected premium at application time
        Seconds lifetime;
        bytes applicationData;
        // policy data that may change during the lifecycle
        bytes processData;
        uint16 claimsCount;
        uint16 openClaimsCount;
        Amount claimAmount; // sum of confirmed claim amounts (max = sum insured amount)
        Amount payoutAmount; // sum of payouts (max = sum confirmed claim amountst)
        Timestamp activatedAt; // time of underwriting
        Timestamp expiredAt; // no new claims (activatedAt + lifetime)
        Timestamp closedAt; // no locked capital (or declinedAt)
    }

    // claimId neeeds to be encoded policyNftId:claimId combination
    struct ClaimInfo {
        Amount claimAmount;
        Amount paidAmount;
        uint24 payoutsCount;
        uint24 openPayoutsCount;
        bytes submissionData; // use case specific claim submission data, no changes after submitting the claim
        bytes processData; // use case specific data that may include information supporting confirm or decline
        Timestamp closedAt; // payment of confirmed claim amount (or declinedAt)
    }

    // claimId neeeds to be encoded policyNftId:claimId combination
    struct PayoutInfo {
        ClaimId claimId;
        Amount amount;
        address beneficiary; // for address(0) beneficiary is policy nft owner
        bytes data; // use case specific supporting data
        Timestamp paidAt; // timestamp for actual payout
    }
}
