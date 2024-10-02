// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {IRegistryLinked} from "./IRegistryLinked.sol";
import {NftId} from "../type/NftId.sol";

interface INftOwnable is
    IERC165,
    IRegistryLinked
{
    event LogNftOwnableNftLinkedToAddress(NftId nftId, address owner);
    
    error ErrorNftOwnableInitialOwnerZero();
    error ErrorNftOwnableNotOwner(address account);

    error ErrorNftOwnableAlreadyLinked(NftId nftId);
    error ErrorNftOwnableContractNotRegistered(address contractAddress);

    function linkToRegisteredNftId() external returns (NftId);

    function getNftId() external view returns (NftId);
    function getOwner() external view returns (address);
}