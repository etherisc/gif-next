// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {IPolicyHolder} from "./IPolicyHolder.sol";

import {Amount} from "../type/Amount.sol";
import {ClaimId} from "../type/ClaimId.sol";
import {InitializableERC165} from "./InitializableERC165.sol";
import {NftId} from "../type/NftId.sol";
import {PayoutId} from "../type/PayoutId.sol";
import {RegistryLinked} from "./RegistryLinked.sol";
import {Timestamp} from "../type/Timestamp.sol";

/// @dev template implementation for IPolicyHolder
contract PolicyHolder is
    InitializableERC165,
    RegistryLinked,
    IPolicyHolder
{
    // TODO add modifier to protect callback functions from unauthorized access
    // callbacks must only be allowed from the policy and claim services
    // will need a release parameter to fetch the right service addresses for the modifiers

    function __PolicyHolder_init(
    )
        internal
        virtual
        onlyInitializing()
    {
        _initializeERC165();
        _registerInterface(type(IPolicyHolder).interfaceId);
    }

    /// @dev empty default implementation
    function policyActivated(NftId policyNftId, Timestamp activatedAt) external virtual {}

    /// @dev empty default implementation
    function policyExpired(NftId policyNftId, Timestamp expiredAt) external virtual {}

    /// @dev empty default implementation
    function claimConfirmed(NftId policyNftId, ClaimId claimId, Amount amount) external virtual {}

    /// @dev empty default implementation
    function payoutExecuted(NftId policyNftId, PayoutId payoutId, Amount amount, address beneficiary) external virtual {}

    //--- IERC721 functions ---------------// 
    function onERC721Received(
        address, // operator
        address, // from
        uint256, // tokenId
        bytes calldata // data
    )
        external
        virtual
        returns (bytes4)
    {
        return IERC721Receiver.onERC721Received.selector;
    }
}