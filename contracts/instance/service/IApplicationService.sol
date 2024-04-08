// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IPolicy} from "../module/IPolicy.sol";
import {IService} from "../../shared/IService.sol";

import {NftId} from "../../types/NftId.sol";
import {ObjectType} from "../../types/ObjectType.sol";
import {ReferralId} from "../../types/Referral.sol";
import {RiskId} from "../../types/RiskId.sol";
import {Seconds} from "../../types/Seconds.sol";

/// @dev gif service responsible for creating applications
/// only product components may call transaction functions
interface IApplicationService is IService {
    
    error ErrorApplicationServiceNotProduct(NftId callerNftId, ObjectType callerType);
    error ErrorApplicationServiceBundlePoolMismatch(NftId bundleNftId, NftId bundlePoolNftId, NftId poolNftId);

    /// @dev creates a new application based on the specified attributes
    /// may only be called by a product component
    function create(
        address applicationOwner,
        RiskId riskId,
        uint256 sumInsuredAmount,
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
        uint256 sumInsuredAmount,
        uint256 lifetime,
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

    /// @dev calculates the premium amount for the specified attributes
    /// also returns the various fee components involved with creating a policy
    function calculatePremium(
        NftId productNftId,
        RiskId riskId,
        uint256 sumInsuredAmount,
        Seconds lifetime,
        bytes memory applicationData,
        NftId bundleNftId,
        ReferralId referralId
    )
        external
        view
        returns (
            IPolicy.Premium memory premium
        );
}
