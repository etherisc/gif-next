// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {Amount} from "../type/Amount.sol";
import {ClaimId} from "../type/ClaimId.sol";
import {IRegistryLinked} from "../shared/IRegistryLinked.sol";
import {NftId} from "../type/NftId.sol";
import {PayoutId} from "../type/PayoutId.sol";
import {Timestamp} from "../type/Timestamp.sol";

/// @dev Generic interface for contracts that need to hold policies and receive payouts.
/// The framework notifies policy holder contracts for policy creation/expiry, claim confirmation and payout execution
interface IPolicyHolder is
    IERC165,
    IERC721Receiver,
    IRegistryLinked
{

    /// @dev Callback function that will be called after successful policy activation.
    /// Active policies may open claims under the activated policy.
    function policyActivated(NftId policyNftId, Timestamp activatedAt) external;

    /// @dev Callback function to indicate the specified policy has expired.
    /// expired policies no longer accept new claims.
    function policyExpired(NftId policyNftId, Timestamp expiredAt) external;

    /// @dev Callback function to notify the confirmation of the specified claim.
    function claimConfirmed(NftId policyNftId, ClaimId claimId, Amount amount) external;

    /// @dev Callback function to notify the successful payout.
    function payoutExecuted(NftId policyNftId, PayoutId payoutId, address beneficiary, Amount amount) external;
}