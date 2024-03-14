// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {NftOwnable} from "../../contracts/shared/NftOwnable.sol";

contract NftOwnableMock is NftOwnable {

    constructor(address registry) {
        initialize(registry);
    }

    function initialize(address registry) public initializer() {
        initializeNftOwnable(msg.sender, registry);
    }

    function linkToNftOwnable(address nftOwnableAddress) external {
        _linkToNftOwnable(nftOwnableAddress);
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

    function linkToNftOwnable(address nftOwnableAddress) external {
        _linkToNftOwnable(nftOwnableAddress);
    }
}