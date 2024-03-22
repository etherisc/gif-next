// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRisk} from "../module/IRisk.sol";
import {IService} from "../../shared/IService.sol";

import {Amount} from "../../types/Amount.sol";
import {ClaimId} from "../../types/ClaimId.sol";
import {NftId} from "../../types/NftId.sol";
import {ReferralId} from "../../types/Referral.sol";
import {RiskId} from "../../types/RiskId.sol";
import {Seconds} from "../../types/Seconds.sol";
import {StateId} from "../../types/StateId.sol";
import {Timestamp} from "../../types/Timestamp.sol";
import {UFixed} from "../../types/UFixed.sol";
import {Fee} from "../../types/Fee.sol";

interface IPolicyService is IService {

    event LogPolicyServiceClaimCreated(NftId policyNftId, ClaimId claimId, Amount claimAmount);

    error ErrorPolicyServicePolicyProductMismatch(NftId policyNftId, NftId expectedProduct, NftId actualProduct);
    error ErrorPolicyServicePolicyNotOpen(NftId policyNftId);
    error ErrorPolicyServiceClaimExceedsSumInsured(NftId policyNftId, Amount sumInsured, Amount payoutsIncludingClaimAmount);

    error ErrorIPolicyServiceInsufficientAllowance(address customer, address tokenHandlerAddress, uint256 amount);
    error ErrorIPolicyServicePremiumAlreadyPaid(NftId policyNftId, uint256 premiumPaidAmount);
    error ErrorIPolicyServicePolicyNotActivated(NftId policyNftId);
    error ErrorIPolicyServicePolicyAlreadyClosed(NftId policyNftId);
    error ErrorIPolicyServicePolicyNotActive(NftId policyNftId, StateId state);
    error ErrorIPolicyServicePremiumNotFullyPaid(NftId policyNftId, uint256 premiumAmount, uint256 premiumPaidAmount);
    error ErrorIPolicyServiceOpenClaims(NftId policyNftId, uint16 openClaimsCount);
    error ErrorIPolicyServicePolicyHasNotExpired(NftId policyNftId, Timestamp expiredAt);

    error ErrorIPolicyServicePremiumMismatch(NftId policyNftId, uint256 premiumAmount, uint256 recalculatedPremiumAmount);

    /// @dev declines an application represented by {policyNftId}
    /// an application can only be declined in applied state
    /// only the related product may decline an application
    function decline(NftId policyNftId) external;

    /// @dev underwrites the policy represented by {policyNftId}
    /// sets the policy state to underwritten
    /// may set the policy state to activated and set the activation date
    /// optionally collects premiums and activates the policy.
    /// - premium payment is only attempted if requirePremiumPayment is set to true
    /// - activation is only done if activateAt is a non-zero timestamp
    /// an application can only be underwritten in applied state
    /// only the related product may underwrite an application
    function underwrite(
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
    /// function can only be called by product, policy needs to match with calling product
    function createClaim(
        NftId policyNftId, 
        Amount claimAmount,
        bytes memory claimData
    ) external returns (ClaimId);

    // TODO move function to pool service
    function calculateRequiredCollateral(
        UFixed collateralizationLevel, 
        uint256 sumInsuredAmount
    ) external pure returns(uint256 collateralAmount);

}
