// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {IRegistry} from "../registry/IRegistry.sol";
import {NftId} from "../types/NftId.sol";
import {NumberId} from "../types/NumberId.sol";

/// @dev generic interface for contracts that need to hold policies and receive payouts
/// GIF will notify policy holder contracts for policy creation and payout execution
/// 

interface IPolicyHolder is IERC165, IERC721Receiver {

    /// @dev callback function that will be called after successful policy creation
    function policyCreated(NftId policyNftId) external;

    /// @dev callback function that will be called after a successful payout
    function payoutProcessed(NftId policyNftId, NumberId payoutId, address beneficiary, uint256 amount) external;

    /// @dev determines beneficiary address that will be used in payouts targeting this contract
    /// returned address will override GIF default where the policy nft holder is treated as beneficiary
    function getBeneficiary(NftId policyId, NumberId claimId) external view returns (address beneficiary);
}