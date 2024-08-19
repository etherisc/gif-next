// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IInstance} from "../instance/IInstance.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";
import {IService} from "../shared/IService.sol";

import {Amount} from "../type/Amount.sol";
import {ClaimId} from "../type/ClaimId.sol";
import {PayoutId} from "../type/PayoutId.sol";
import {NftId} from "../type/NftId.sol";
import {StateId} from "../type/StateId.sol";
import {Timestamp} from "../type/Timestamp.sol";
import {UFixed} from "../type/UFixed.sol";
import {Fee} from "../type/Fee.sol";

/// @dev gif service responsible for creating claims and payouts
/// only product components may call transaction functions
interface IClaimService is
    IService
{

    event LogClaimServiceClaimSubmitted(NftId policyNftId, ClaimId claimId, Amount claimAmount);
    event LogClaimServiceClaimConfirmed(NftId policyNftId, ClaimId claimId, Amount confirmedAmount);
    event LogClaimServiceClaimDeclined(NftId policyNftId, ClaimId claimId);
    event LogClaimServiceClaimRevoked(NftId policyNftId, ClaimId claimId);
    event LogClaimServiceClaimClosed(NftId policyNftId, ClaimId claimId);

    event LogClaimServicePayoutCreated(NftId policyNftId, PayoutId payoutId, Amount amount, address beneficiary);
    event LogClaimServicePayoutProcessed(NftId policyNftId, PayoutId payoutId, Amount amount, address beneficiary, Amount netAmount, Amount processingFeeAmount);
    event LogClaimServicePayoutCancelled(NftId policyNftId, PayoutId payoutId);

    error ErrorClaimServiceBeneficiarySet(NftId policyNftId, PayoutId payoutId, address beneficiary);

    error ErrorClaimServicePolicyNotOpen(NftId policyNftId);
    error ErrorClaimServiceClaimAmountIsZero(NftId policyNftId);
    error ErrorClaimServiceClaimExceedsSumInsured(NftId policyNftId, Amount sumInsured, Amount payoutsIncludingClaimAmount);
    error ErrorClaimServiceBeneficiaryIsZero(NftId policyNftId, ClaimId claimId);
    error ErrorClaimsServicePayoutAmountIsZero(NftId policyNftId, PayoutId payoutId);

    error ErrorClaimServiceClaimWithOpenPayouts(NftId policyNftId, ClaimId claimId, uint24 openPayouts);
    error ErrorClaimServiceClaimWithMissingPayouts(NftId policyNftId, ClaimId claimId, Amount claimAmount, Amount paidAmount);
    error ErrorClaimServiceClaimNotInExpectedState(NftId policyNftId, ClaimId claimId, StateId expectedState, StateId actualState);

    error ErrorClaimServiceClaimNotConfirmed(NftId policyNftId, ClaimId claimId, StateId actualState);
    error ErrorClaimServicePayoutExceedsClaimAmount(NftId policyNftId, ClaimId claimId, Amount claimAmount, Amount totalPayoutAmount);
    error ErrorClaimServicePayoutNotExpected(NftId policyNftId, PayoutId payoutId, StateId actualState);

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
        ClaimId claimId,
        bytes memory data // claim processing data
    ) external;


    /// @dev revokes the specified claim
    /// function can only be called by product, policy needs to match with calling product
    function revoke(
        NftId policyNftId, 
        ClaimId claimId
    ) external;


    /// @dev confirms the specified claim and specifies the payout amount
    /// function can only be called by product, policy needs to match with calling product
    function confirm(
        NftId policyNftId, 
        ClaimId claimId,
        Amount confirmedAmount,
        bytes memory data // claim processing data
    ) external;


    /// @dev closes the specified claim
    /// function can only be called by product, policy needs to match with calling product
    function close(
        NftId policyNftId, 
        ClaimId claimId
    ) external;


    /// @dev Creates a new payout for the specified claim.
    /// The beneficiary is the holder of the policy NFT
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


    /// @dev Creates a new payout for the specified claim and beneficiary.
    /// returns the id of the newly created payout, this id is unique for the specified policy
    /// function can only be called by product, policy needs to match with calling product
    function createPayoutForBeneficiary(
        NftId policyNftId, 
        ClaimId claimId,
        Amount amount,
        address beneficiary,
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

    /// @dev cancels the specified payout. no tokens are moved, payout is set to cancelled. 
    function cancelPayout(
        NftId policyNftId, 
        PayoutId payoutId
    ) external;
}
