// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRisk} from "../module/IRisk.sol";
import {IService} from "../../shared/IService.sol";

import {NftId} from "../../types/NftId.sol";
import {ReferralId} from "../../types/Referral.sol";
import {RiskId} from "../../types/RiskId.sol";
import {StateId} from "../../types/StateId.sol";
import {Timestamp} from "../../types/Timestamp.sol";
import {UFixed} from "../../types/UFixed.sol";
import {Fee} from "../../types/Fee.sol";

/// @dev gif service responsible for creating applications
/// only product components may call transaction functions
interface IApplicationService is IService {
    
    error IApplicationServicePolicyNotApplied(NftId applicationNftId);

    /// @dev creates a new application based on the specified attributes
    /// may only be called by a product component
    function create(
        address applicationOwner,
        RiskId riskId,
        NftId bundleNftId,
        ReferralId referralId,
        uint256 sumInsuredAmount,
        uint256 lifetime,
        bytes memory applicationData
    ) external returns (NftId applicationNftId);

    /// @dev updates application attributes
    /// may only be called while the application is in applied state
    /// may only be called by the referenced product related to applicationNftId
    function ajust(
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
        RiskId riskId,
        uint256 sumInsuredAmount,
        uint256 lifetime,
        bytes memory applicationData,
        NftId bundleNftId,
        ReferralId referralId
    )
        external
        view
        returns (
            uint256 premiumAmount,
            uint256 distributionFeeAmount,
            uint256 productFeeAmount,
            uint256 poolFeeAmount,
            uint256 bundleFeeAmount
        );
}
