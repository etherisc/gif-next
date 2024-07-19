// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {Amount} from "../type/Amount.sol";
import {ClaimId} from "../type/ClaimId.sol";
import {InitializableERC165} from "./InitializableERC165.sol";
import {IPolicyHolder} from "./IPolicyHolder.sol";
import {NftId} from "../type/NftId.sol";
import {PayoutId, PayoutIdLib} from "../type/PayoutId.sol";
import {RegistryLinked} from "./RegistryLinked.sol";

/// @dev template implementation for IPolicyHolder
contract PolicyHolder is
    InitializableERC165,
    RegistryLinked, // TODO need upgradeable version
    IPolicyHolder
{
    function _initializePolicyHolder(
        address registryAddress
    )
        internal
        virtual
        onlyInitializing()
    {
        _initializeRegistryLinked(registryAddress);
        _registerInterface(type(IPolicyHolder).interfaceId);
    }

    /// @dev empty default implementation
    function policyActivated(NftId policyNftId) external {}

    /// @dev empty default implementation
    function policyExpired(NftId policyNftId) external {}

    /// @dev empty default implementation
    function claimConfirmed(NftId policyNftId, ClaimId claimId, Amount amount) external {}

    /// @dev empty default implementation
    function payoutExecuted(NftId policyNftId, PayoutId payoutId, address beneficiary, Amount amount) external {}

    //--- IERC165 functions ---------------// 
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