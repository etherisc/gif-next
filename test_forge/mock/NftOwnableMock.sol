// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {NftOwnable} from "../../contracts/shared/NftOwnable.sol";

contract NftOwnableMock is NftOwnable {

    constructor() {
        initializeOwner(msg.sender);
    }

    function linkToNftOwnable(address registryAddress, address nftOwnableAddress) external {
        _linkToNftOwnable(registryAddress, nftOwnableAddress);
    }
}


contract NftOwnableMockUninitialized is NftOwnable {

    function initialize(
        address initialOwner,
        address registry
    )
        public
        initializer()
    {
        initializeNftOwnable(initialOwner, registry);
    }

    function linkToNftOwnable(address registryAddress, address nftOwnableAddress) external {
        _linkToNftOwnable(registryAddress, nftOwnableAddress);
    }
}