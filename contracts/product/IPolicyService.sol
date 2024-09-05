// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IService} from "../shared/IService.sol";

import {Amount} from "../type/Amount.sol";
import {IInstance} from "../instance/IInstance.sol";
import {NftId} from "../type/NftId.sol";
import {StateId} from "../type/StateId.sol";
import {Timestamp} from "../type/Timestamp.sol";

interface IPolicyService is IService {

    event LogPolicyServicePolicyCreated(NftId policyNftId, Amount premiumAmount, Timestamp activatedAt);
    event LogPolicyServicePolicyDeclined(NftId policyNftId);
    event LogPolicyServicePolicyPremiumCollected(NftId policyNftId, Amount premiumAmount);
    event LogPolicyServicePolicyActivated(NftId policyNftId, Timestamp activatedAt);
    event LogPolicyServicePolicyActivatedUpdated(NftId policyNftId, Timestamp activatedAt);
    event LogPolicyServicePolicyExpirationUpdated(NftId policyNftId, Timestamp expiredAt);
    event LogPolicyServicePolicyClosed(NftId policyNftId);

    error LogPolicyServiceMaxPremiumAmountExceeded(NftId policyNftId, Amount maxPremiumAmount, Amount premiumAmount);
    error ErrorPolicyServicePolicyProductMismatch(NftId applicationNftId, NftId expectedProductNftId, NftId actualProductNftId);
    error ErrorPolicyServicePolicyStateNotApplied(NftId applicationNftId);
    error ErrorPolicyServicePolicyStateNotCollateralized(NftId applicationNftId);
    error ErrorPolicyServicePolicyAlreadyActivated(NftId policyNftId);

    error ErrorPolicyServicePolicyNotActivated(NftId policyNftId);
    error ErrorPolicyServicePolicyActivationTooEarly(NftId policyNftId, Timestamp lowerLimit, Timestamp activatedAt);
    error ErrorPolicyServicePolicyActivationTooLate(NftId policyNftId, Timestamp upperLimit, Timestamp activatedAt);
    
    error ErrorPolicyServiceInsufficientAllowance(address customer, address tokenHandlerAddress, uint256 amount);
    error ErrorPolicyServicePremiumAlreadyPaid(NftId policyNftId);

    error ErrorPolicyServicePolicyNotCloseable(NftId policyNftId);

    error ErrorPolicyServicePolicyNotActive(NftId policyNftId, StateId state);
    error ErrorPolicyServicePremiumNotPaid(NftId policyNftId, Amount premiumAmount);
    error ErrorPolicyServiceOpenClaims(NftId policyNftId, uint16 openClaimsCount);
    error ErrorPolicyServicePolicyHasNotExpired(NftId policyNftId, Timestamp expiredAt);
    error ErrorPolicyServicePolicyExpirationTooLate(NftId policyNftId, Timestamp upperLimit, Timestamp expiredAt);
    error ErrorPolicyServicePolicyExpirationTooEarly(NftId policyNftId, Timestamp lowerLimit, Timestamp expiredAt);

    error ErrorPolicyServicePremiumMismatch(NftId policyNftId, Amount expectedPremiumAmount, Amount recalculatedPremiumAmount);
    error ErrorPolicyServiceTransferredPremiumMismatch(NftId policyNftId, Amount expectedPremiumAmount, Amount transferredPremiumAmount);

    /// @dev creates the policy from {applicationNftId}. 
    /// @param applicationNftId the application NftId
    /// @param activateAt the timestamp when the policy should be activated
    /// @param maxPremiumAmount the maximum premium amount that the policy holder is willing to pay
    /// During policy creation, the effective premium amount is calculated based on the provided parameters. If this
    /// amount is higher than the maxPremiumAmount, the function will revert.
    /// After successful completion of the function the policy can be referenced using the application NftId.
    /// Locks the sum insured amount in the pool, but does not transfer tokens. Call collectPremium to transfer tokens. 
    /// Sets the policy state to collateralized.
    /// Optionally activates the policy if activateAt is a non-zero timestamp.
    /// only the related product may create a policy from an application
    /// @return premiumAmount the effective premium amount
    function createPolicy(
        NftId applicationNftId,
        Timestamp activateAt,
        Amount maxPremiumAmount
    )
        external
        returns (Amount premiumAmount);

    /// @dev declines an application represented by {policyNftId}
    /// an application can only be declined in applied state
    /// only the related product may decline an application
    function decline(NftId policyNftId) external;

    /// @dev collects the premium token for the specified policy (must be in COLLATERALIZED state)
    function collectPremium(NftId policyNftId, Timestamp activateAt) external;

    /// @dev activates the specified policy and sets the activation date in the policy metadata
    /// to activate a policy it needs to be in underwritten state
    function activate(NftId policyNftId, Timestamp activateAt) external;

    /// @dev adjusts the activation date of the specified policy and sets the new activation date in the policy metadata
    /// to adjust the activation date of a policy it needs to have an activation date set. 
    /// the new activation date must not be before the current block timestamp or after the expiry date
    function adjustActivation(NftId policyNftId, Timestamp newActivateAt) external;

    /// @dev Expires the specified policy and sets the expiry date in the policy metadata. 
    /// Function consumers are products.
    /// If expiry date is set to 0, then the earliest possible expiry date (current blocktime) is set
    /// to expire a policy it must be in active state, policies may be expired even when the predefined expiry date is still in the future
    /// a policy can only be closed when it has been expired. in addition, it must not have any open claims
    /// this function can only be called by a product. the policy needs to match with the calling product
    /// @return expiredAt the effective expiry date
    function expire(NftId policyNftId, Timestamp expireAt) external returns (Timestamp expiredAt);

    /// @dev Closes the specified policy and sets the closed data in the policy metadata
    /// a policy can only be closed when it has been expired. in addition, it must not have any open claims
    /// this function can only be called by a product. the policy needs to match with the calling product
    function close(NftId policyNftId) external;

    /// @dev Expires the specified policy and sets the expiry date in the policy metadata. 
    /// Function consumers is claim service.
    function expirePolicy(IInstance instance, NftId policyNftId, Timestamp expireAt) external returns (Timestamp expiredAt);

}
