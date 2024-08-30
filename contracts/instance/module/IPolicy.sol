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
        // slot 0
        // premium splitting per target wallet
        Amount productFeeAmount;
        Amount distributionFeeAndCommissionAmount;
        // slot 1
        Amount poolPremiumAndFeeAmount;

        // detailed positions
        // this is the net premium calculated by the product 
        Amount netPremiumAmount;
        // slot 2
        // fullPremium = netPremium + all fixed amounts + all variable amounts (excl commission and minDistribtuionOwnerFee variable part)
        Amount fullPremiumAmount;
        // effective premium = fullPremium - discount 
        Amount premiumAmount;
        // slot 3
        Amount productFeeFixAmount;
        Amount poolFeeFixAmount;
        // slot 4
        Amount bundleFeeFixAmount;
        Amount distributionFeeFixAmount;
        // slot 5
        Amount productFeeVarAmount;
        Amount poolFeeVarAmount;
        // slot 6
        Amount bundleFeeVarAmount;
        Amount distributionFeeVarAmount;
        // slot 7
        Amount distributionOwnerFeeFixAmount;
        // this is the remaining amount when the commission and discount are subtracted from the distribution fee variable part (must be at least the minDistributionOwnerFee)
        Amount distributionOwnerFeeVarAmount;
        // slot 8
        // this value is based on distributor type referenced in the referral 
        Amount commissionAmount;
        // this is based on referral used
        Amount discountAmount;
    }

    /// @dev policy data for the full policy lifecycle
    struct PolicyInfo {
        // slot 0
        NftId productNftId;
        NftId bundleNftId;
        RiskId riskId;
        // slot 1
        Amount sumInsuredAmount;
        Amount premiumAmount; // expected premium at application time
        ReferralId referralId;
        // slot 2
        uint16 claimsCount;
        uint16 openClaimsCount;
        Amount claimAmount; // sum of confirmed claim amounts (max = sum insured amount)
        Amount payoutAmount; // sum of payouts (max = sum confirmed claim amountst)
        // slot 3
        Timestamp activatedAt; // time of underwriting
        Seconds lifetime;
        Timestamp expiredAt; // no new claims (activatedAt + lifetime)
        Timestamp closedAt; // no locked capital (or declinedAt)
        // slot 4
        bytes applicationData;
        // slot 5
        bytes processData;
    }

    // claimId neeeds to be encoded policyNftId:claimId combination
    struct ClaimInfo {
        // slot 0
        Amount claimAmount;
        Amount paidAmount;
        Timestamp closedAt; // payment of confirmed claim amount (or declinedAt)
        uint24 payoutsCount;
        // slot 1
        uint24 openPayoutsCount;
        // slot 2
        bytes submissionData; // use case specific claim submission data, no changes after submitting the claim
        // slot 3
        bytes processData; // use case specific data that may include information supporting confirm or decline
    }

    // claimId neeeds to be encoded policyNftId:claimId combination
    struct PayoutInfo {
        // slot 0
        ClaimId claimId;
        Amount amount;
        Timestamp paidAt; // timestamp for actual payout
        // slot 1
        address beneficiary; // for address(0) beneficiary is policy nft owner
        // slot 2
        bytes data; // use case specific supporting data
    }
}
