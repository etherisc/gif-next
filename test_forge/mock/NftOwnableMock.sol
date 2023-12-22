// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {NftOwnable} from "../../contracts/shared/NftOwnable.sol";

contract NftOwnableMock is NftOwnable {

    constructor() NftOwnable() {}

    function initializeNftOwnable(address initialOwner, address registryAddress) external {
        _initializeNftOwnable(initialOwner, registryAddress);
    }

    function linkToNftOwnable(address registryAddress, address nftOwnableAddress) external {
        _linkToNftOwnable(registryAddress, nftOwnableAddress);
    }
}