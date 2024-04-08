// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IInstance} from "../IInstance.sol";
import {InstanceReader} from "../InstanceReader.sol";
import {IService} from "../../shared/IService.sol";

import {Amount} from "../../types/Amount.sol";
import {ClaimId} from "../../types/ClaimId.sol";
import {PayoutId} from "../../types/PayoutId.sol";
import {NftId} from "../../types/NftId.sol";
import {StateId} from "../../types/StateId.sol";
import {Timestamp} from "../../types/Timestamp.sol";
import {UFixed} from "../../types/UFixed.sol";
import {Fee} from "../../types/Fee.sol";

/// @dev gif service responsible for creating claims and payouts
/// only product components may call transaction functions
interface IClaimService is
    IService
{

    event LogClaimServiceClaimSubmitted(NftId policyNftId, ClaimId claimId, Amount claimAmount);
    event LogClaimServiceClaimConfirmed(NftId policyNftId, ClaimId claimId, Amount confirmedAmount);
    event LogClaimServiceClaimDeclined(NftId policyNftId, ClaimId claimId);
    event LogClaimServiceClaimClosed(NftId policyNftId, ClaimId claimId);

    event LogClaimServicePayoutCreated(NftId policyNftId, PayoutId payoutId, Amount amount);
    event LogClaimServicePayoutProcessed(NftId policyNftId, PayoutId payoutId, Amount amount);

    error ErrorClaimServicePolicyProductMismatch(NftId policyNftId, NftId expectedProduct, NftId actualProduct);
    error ErrorClaimServicePolicyNotOpen(NftId policyNftId);
    error ErrorClaimServiceClaimExceedsSumInsured(NftId policyNftId, Amount sumInsured, Amount payoutsIncludingClaimAmount);

    error ErrorClaimServiceClaimWithOpenPayouts(NftId policyNftId, ClaimId claimId, uint8 openPayouts);
    error ErrorClaimServiceClaimWithMissingPayouts(NftId policyNftId, ClaimId claimId, Amount claimAmount, Amount paidAmount);
    error ErrorClaimServiceClaimNotInExpectedState(NftId policyNftId, ClaimId claimId, StateId expectedState, StateId actualState);

    /// @dev create a new claim for the specified policy
    /// returns the id of the newly created claim
    /// function can only be called by product, policy needs to match with calling product
    function submit(
        NftId policyNftId, 
        Amount claimAmount,
        bytes memory claimData
    ) external returns (ClaimId claimId);

    /// @dev declines the specified claim
    /// function can only be called by product, policy needs to match with calling product
    function decline(
        NftId policyNftId, 
        ClaimId claimId) external;

    /// @dev confirms the specified claim and specifies the payout amount
    /// function can only be called by product, policy needs to match with calling product
    function confirm(
        NftId policyNftId, 
        ClaimId claimId,
        Amount confirmedAmount
    ) external;

    /// @dev closes the specified claim
    /// function can only be called by product, policy needs to match with calling product
    function close(
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
}
