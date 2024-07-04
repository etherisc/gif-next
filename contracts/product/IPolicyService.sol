// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IRisk} from "../instance/module/IRisk.sol";
import {IService} from "../shared/IService.sol";

import {Amount} from "../type/Amount.sol";
import {ClaimId} from "../type/ClaimId.sol";
import {NftId} from "../type/NftId.sol";
import {PayoutId} from "../type/PayoutId.sol";
import {ReferralId} from "../type/Referral.sol";
import {RiskId} from "../type/RiskId.sol";
import {Seconds} from "../type/Seconds.sol";
import {StateId} from "../type/StateId.sol";
import {Timestamp} from "../type/Timestamp.sol";
import {UFixed} from "../type/UFixed.sol";
import {Fee} from "../type/Fee.sol";

interface IPolicyService is IService {

    error ErrorPolicyServicePolicyProductMismatch(NftId applicationNftId, NftId expectedProductNftId, NftId actualProductNftId);
    error ErrorPolicyServicePolicyStateNotApplied(NftId applicationNftId);
    error ErrorPolicyServicePolicyStateNotCollateralizedOrApplied(NftId applicationNftId);

    error ErrorPolicyServicePremiumHigherThanExpected(Amount premiumExpectedAmount, Amount premiumToBePaidAmount);
    error ErrorPolicyServiceBalanceInsufficient(address policyOwner, uint256 premiumAmount, uint256 balance);
    error ErrorPolicyServiceAllowanceInsufficient(address policyOwner, address tokenHandler, uint256 premiumAmount, uint256 allowance);

    error ErrorIPolicyServiceInsufficientAllowance(address customer, address tokenHandlerAddress, uint256 amount);
    error ErrorPolicyServicePremiumAlreadyPaid(NftId policyNftId, Amount premiumPaidAmount);
    error ErrorIPolicyServicePolicyNotActivated(NftId policyNftId);
    error ErrorIPolicyServicePolicyAlreadyClosed(NftId policyNftId);
    error ErrorIPolicyServicePolicyNotActive(NftId policyNftId, StateId state);
    error ErrorPolicyServicePremiumNotFullyPaid(NftId policyNftId, Amount premiumAmount, Amount premiumPaidAmount);
    error ErrorIPolicyServiceOpenClaims(NftId policyNftId, uint16 openClaimsCount);
    error ErrorIPolicyServicePolicyHasNotExpired(NftId policyNftId, Timestamp expiredAt);

    error ErrorPolicyServicePremiumMismatch(NftId policyNftId, Amount expectedPremiumAmount, Amount recalculatedPremiumAmount);
    error ErrorPolicyServiceTransferredPremiumMismatch(NftId policyNftId, Amount expectedPremiumAmount, Amount transferredPremiumAmount);

    event LogPolicyServicePolicyDeclined(NftId policyNftId);

    /// @dev collateralizes the policy represented by {policyNftId}
    /// sets the policy state to collateralized
    /// may set the policy state to activated and set the activation date
    /// optionally collects premiums and activates the policy.
    /// - premium payment is only attempted if requirePremiumPayment is set to true
    /// - activation is only done if activateAt is a non-zero timestamp
    /// an application can only be collateralized in applied state
    /// only the related product may collateralize an application
    function collateralize(
        NftId policyNftId,
        bool requirePremiumPayment,
        Timestamp activateAt
    ) external;

    /// @dev declines an application represented by {policyNftId}
    /// an application can only be declined in applied state
    /// only the related product may decline an application
    function decline(NftId policyNftId) external;

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

}
