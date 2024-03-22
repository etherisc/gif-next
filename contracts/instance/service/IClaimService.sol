// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRisk} from "../module/IRisk.sol";
import {IService} from "../../shared/IService.sol";

import {Amount} from "../../types/Amount.sol";
import {ClaimId} from "../../types/ClaimId.sol";
import {PayoutId} from "../../types/PayoutId.sol";
import {NftId} from "../../types/NftId.sol";
import {ReferralId} from "../../types/Referral.sol";
import {RiskId} from "../../types/RiskId.sol";
import {StateId} from "../../types/StateId.sol";
import {Timestamp} from "../../types/Timestamp.sol";
import {UFixed} from "../../types/UFixed.sol";
import {Fee} from "../../types/Fee.sol";

/// @dev gif service responsible for creating claims and payouts
/// only product components may call transaction functions
interface IClaimService is
    IService
{

    event LogClaimServiceClaimCreated(NftId policyNftId, ClaimId claimId, Amount claimAmount);

    error ErrorClaimServicePolicyProductMismatch(NftId policyNftId, NftId expectedProduct, NftId actualProduct);
    error ErrorClaimServicePolicyNotOpen(NftId policyNftId);
    error ErrorClaimServiceClaimExceedsSumInsured(NftId policyNftId, Amount sumInsured, Amount payoutsIncludingClaimAmount);

    /// @dev create a new claim for the specified policy
    /// function can only be called by product, policy needs to match with calling product
    function create(
        NftId policyNftId, 
        Amount claimAmount,
        bytes memory claimData
    ) external returns (ClaimId);

    /// @dev confirms the specified claim and fixes the final claim amount
    /// function can only be called by product, policy needs to match with calling product
    function confirm(NftId policyNftId, ClaimId claimId, Amount claimAmount) external;

    /// @dev declares the claim as invalid, no payout(s) will be made
    /// function can only be called by product, policy needs to match with calling product
    function decline(NftId policyNftId, ClaimId claimId) external;

    /// @dev closes the claim
    /// a claim may only be closed once all existing payouts have been executed and the sum of the paid out amounts has reached the claim amount
    /// function can only be called by product, policy needs to match with calling product
    function close(NftId policyNftId, ClaimId claimId) external; 

    /// @dev create a new payout for the specified policy and claim
    /// function can only be called by product, policy needs to match with calling product
    function createPayout(
        NftId policyNftId, 
        ClaimId claimId,
        Amount payoutAmount,
        bytes calldata payoutData
    ) external returns (PayoutId payoutId);

    /// @dev callback function to confirm transfer of payout token to beneficiary
    /// allows claim service to update claims/payout book keeping
    /// only pool service can confirm executed payout
    function payoutExecuted(
        NftId policyNftId, 
        PayoutId payoutId
    ) external;

}
