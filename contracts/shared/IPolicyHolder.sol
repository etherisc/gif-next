// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {Amount} from "../type/Amount.sol";
import {ClaimId} from "../type/ClaimId.sol";
import {IRegistryLinked} from "../shared/IRegistryLinked.sol";
import {NftId} from "../type/NftId.sol";
import {PayoutId} from "../type/PayoutId.sol";

/// @dev generic interface for contracts that need to hold policies and receive payouts
/// GIF will notify policy holder contracts for policy creation and payout execution
interface IPolicyHolder is
    IERC165,
    IERC721Receiver,
    IRegistryLinked
{

    /// @dev callback function that will be called after successful policy activation
    /// active policies may open claims under the activated policy
    function policyActivated(NftId policyNftId) external;

    /// @dev callback function to indicate the specified policy has expired
    /// expired policies may no longer open claims
    /// it is optional for products to notifiy policy holder of expired claims
    function policyExpired(NftId policyNftId) external;

    /// @dev callback function to notify the confirmation of the specified claim
    /// active policies may open claims under the activated policy
    function claimConfirmed(NftId policyNftId, ClaimId claimId, Amount amount) external;

    /// @dev callback function that will be called after a successful payout
    function payoutExecuted(NftId policyNftId, PayoutId payoutId, address beneficiary, Amount amount) external;

    /// @dev determines policy and claim specific beneficiary address
    /// returned address will override GIF default where the policy nft holder is treated as beneficiary
    function getBeneficiary(NftId policyNftId, ClaimId claimId) external view returns (address beneficiary);
}