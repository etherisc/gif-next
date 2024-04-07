// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRisk} from "../module/IRisk.sol";
import {IService} from "../../shared/IService.sol";

import {Amount} from "../../types/Amount.sol";
import {ClaimId} from "../../types/ClaimId.sol";
import {Amount} from "../../types/Amount.sol";
import {ClaimId} from "../../types/ClaimId.sol";
import {NftId} from "../../types/NftId.sol";
import {PayoutId} from "../../types/PayoutId.sol";
import {PayoutId} from "../../types/PayoutId.sol";
import {ReferralId} from "../../types/Referral.sol";
import {RiskId} from "../../types/RiskId.sol";
import {Seconds} from "../../types/Seconds.sol";
import {StateId} from "../../types/StateId.sol";
import {Timestamp} from "../../types/Timestamp.sol";
import {UFixed} from "../../types/UFixed.sol";
import {Fee} from "../../types/Fee.sol";

interface IPolicyService is IService {

    event LogPolicyServiceClaimSubmitted(NftId policyNftId, ClaimId claimId, Amount claimAmount);
    event LogPolicyServiceClaimConfirmed(NftId policyNftId, ClaimId claimId, Amount confirmedAmount);
    event LogPolicyServiceClaimDeclined(NftId policyNftId, ClaimId claimId);
    event LogPolicyServiceClaimClosed(NftId policyNftId, ClaimId claimId);

    event LogPolicyServicePayoutCreated(NftId policyNftId, PayoutId payoutId, Amount amount);
    event LogPolicyServicePayoutProcessed(NftId policyNftId, PayoutId payoutId, Amount amount);

    error ErrorPolicyServicePolicyProductMismatch(NftId policyNftId, NftId expectedProduct, NftId actualProduct);
    error ErrorPolicyServicePolicyNotOpen(NftId policyNftId);
    error ErrorPolicyServiceClaimExceedsSumInsured(NftId policyNftId, Amount sumInsured, Amount payoutsIncludingClaimAmount);
    error ErrorPolicyServicePolicyStateNotApplied(NftId applicationNftId);

    error ErrorIPolicyServiceInsufficientAllowance(address customer, address tokenHandlerAddress, uint256 amount);
    error ErrorIPolicyServicePremiumAlreadyPaid(NftId policyNftId, uint256 premiumPaidAmount);
    error ErrorIPolicyServicePolicyNotActivated(NftId policyNftId);
    error ErrorIPolicyServicePolicyAlreadyClosed(NftId policyNftId);
    error ErrorIPolicyServicePolicyNotActive(NftId policyNftId, StateId state);
    error ErrorIPolicyServicePremiumNotFullyPaid(NftId policyNftId, uint256 premiumAmount, uint256 premiumPaidAmount);
    error ErrorIPolicyServiceOpenClaims(NftId policyNftId, uint16 openClaimsCount);
    error ErrorIPolicyServicePolicyHasNotExpired(NftId policyNftId, Timestamp expiredAt);

    error ErrorIPolicyServicePremiumMismatch(NftId policyNftId, uint256 expectedPremiumAmount, uint256 recalculatedPremiumAmount);
    error ErrorPolicyServiceTransferredPremiumMismatch(NftId policyNftId, uint256 expectedPremiumAmount, uint256 transferredPremiumAmount);

    /// @dev declines an application represented by {policyNftId}
    /// an application can only be declined in applied state
    /// only the related product may decline an application
    function decline(NftId policyNftId) external;

    /// @dev collateralizes the policy represented by {policyNftId}
    /// sets the policy state to underwritten
    /// may set the policy state to activated and set the activation date
    /// optionally collects premiums and activates the policy.
    /// - premium payment is only attempted if requirePremiumPayment is set to true
    /// - activation is only done if activateAt is a non-zero timestamp
    /// an application can only be underwritten in applied state
    /// only the related product may collateralize an application
    function collateralize(
        NftId policyNftId,
        bool requirePremiumPayment,
        Timestamp activateAt
    ) external;

    /// @dev collects the premium token for the specified policy
    function collectPremium(NftId policyNftId, Timestamp activateAt) external;

    /// @dev activates the specified policy and sets the activation date in the policy metadata
    /// to activate a policy it needs to be in underwritten state
    function activate(NftId policyNftId, Timestamp activateAt) external;

    /// @dev expires the specified policy and sets the expiry date in the policy metadata
    /// to expire a policy it must be in active state, policies may be expired even when the predefined expiry date is still in the future
    /// a policy can only be closed when it has been expired. in addition, it must not have any open claims
    /// this function can only be called by a product. the policy needs to match with the calling product
    function expire(NftId policyNftId) external;

    /// @dev closes the specified policy and sets the closed data in the policy metadata
    /// a policy can only be closed when it has been expired. in addition, it must not have any open claims
    /// this function can only be called by a product. the policy needs to match with the calling product
    function close(NftId policyNftId) external;

    /// @dev create a new claim for the specified policy
    /// returns the id of the newly created claim
    /// function can only be called by product, policy needs to match with calling product
    function submitClaim(
        NftId policyNftId, 
        Amount claimAmount,
        bytes memory claimData
    ) external returns (ClaimId claimId);

    /// @dev declines the specified claim
    /// function can only be called by product, policy needs to match with calling product
    function declineClaim(
        NftId policyNftId, 
        ClaimId claimId) external;

    /// @dev confirms the specified claim and specifies the payout amount
    /// function can only be called by product, policy needs to match with calling product
    function confirmClaim(
        NftId policyNftId, 
        ClaimId claimId,
        Amount confirmedAmount
    ) external;

    /// @dev closes the specified claim
    /// function can only be called by product, policy needs to match with calling product
    function closeClaim(
        NftId policyNftId, 
        ClaimId claimId
    ) external;

    /// @dev creates a new payout for the specified claim
    /// returns the id of the newly created payout, this id is unique for the specified policy
    /// function can only be called by product, policy needs to match with calling product
    function createPayout(
        NftId policyNftId, 
        ClaimId claimId,
        Amount amount,
        bytes memory data
    )
        external
        returns (PayoutId payoutId);

    /// @dev processes the specified payout
    /// this includes moving the payout token to the beneficiary (default: policy holder)
    /// function can only be called by product, policy needs to match with calling product
    function processPayout(
        NftId policyNftId, 
        PayoutId payoutId
    ) external;

    // TODO move function to pool service
    function calculateRequiredCollateral(
        UFixed collateralizationLevel, 
        uint256 sumInsuredAmount
    ) external pure returns(uint256 collateralAmount);

}
