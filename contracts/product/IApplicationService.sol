// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IPolicy} from "../instance/module/IPolicy.sol";
import {IService} from "../shared/IService.sol";

import {Amount} from "../type/Amount.sol";
import {NftId} from "../type/NftId.sol";
import {ReferralId} from "../type/Referral.sol";
import {RiskId} from "../type/RiskId.sol";
import {Seconds} from "../type/Seconds.sol";

/// @dev gif service responsible for creating applications
/// only product components may call transaction functions
interface IApplicationService is IService {
    
    event LogApplicationServiceApplicationCreated(
        NftId applicationNftId,
        NftId productNftId,
        NftId bundleNftId, 
        RiskId riskId,
        ReferralId referralId,
        address applicationOwner,
        Amount sumInsuredAmount,
        Amount premiumAmount,
        Seconds lifetime);
    event LogApplicationServiceApplicationRenewed(NftId policyNftId, NftId bundleNftId);
    event LogApplicationServiceApplicationAdjusted(
        NftId applicationNftId, 
        NftId bundleNftId, 
        RiskId riskId, 
        ReferralId referralId, 
        Amount sumInsuredAmount, 
        Seconds lifetime);
    event LogApplicationServiceApplicationRevoked(NftId applicationNftId);

    // _checkLinkedApplicationParameters
    error ErrorApplicationServiceRiskProductMismatch(RiskId riskId, NftId riskProductNftId, NftId productNftId);
    error ErrorApplicationServiceRiskUnknown(RiskId riskId, NftId productNftId);
    error ErrorApplicationServiceRiskPaused(RiskId riskId, NftId productNftId);
    error ErrorApplicationServiceBundleUnknown(NftId bundleNftId, NftId poolNftId);
    error ErrorApplicationServiceBundleLocked(NftId bundleNftId, NftId poolNftId);
    error ErrorApplicationServiceReferralInvalid(NftId productNftId, NftId distributionNftId, ReferralId referralId);
    

    /// @dev creates a new application based on the specified attributes
    /// may only be called by a product component
    function create(
        address applicationOwner,
        RiskId riskId,
        Amount sumInsuredAmount,
        Amount premiumAmount,
        Seconds lifetime,
        NftId bundleNftId,
        ReferralId referralId,
        bytes memory applicationData
    ) external returns (NftId applicationNftId);

    /// @dev updates application attributes
    /// may only be called while the application is in applied state
    /// may only be called by the referenced product related to applicationNftId
    function adjust(
        NftId applicationNftId,
        RiskId riskId,
        NftId bundleNftId,
        ReferralId referralId,
        Amount sumInsuredAmount,
        Seconds lifetime,
        bytes memory applicationData
    ) external;

    /// @dev creates a new application that extends the provided policy
    /// lifetime will seamlessly extend referenced policy, for closed policies
    /// lifetime will start at underwriting time
    /// product will need to limit the time window for renewal as underwriting
    /// will lock the collateral at underwriting time which might be earlier than activation time
    /// policyNftId needs to refer to an underwritten (or active or closed) policy
    /// may only be called by the referenced product related to policyNftId
    function renew(
        NftId policyNftId, // policy to be renewd (renewal inherits policy attributes)
        NftId bundleNftId // will likely need a newer bundle for underwriting
    ) external returns (NftId applicationNftId);

    /// @dev revokes the application represented by {policyNftId}
    /// an application can only be revoked in applied state
    /// only the application holder may revoke an application
    function revoke(NftId policyNftId) external;
}