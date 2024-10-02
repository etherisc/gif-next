// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {NftOwnable} from "../../contracts/shared/NftOwnable.sol";

contract NftOwnableMock is NftOwnable {

    constructor() {
        initialize();
    }

    function initialize() public initializer() {
        __NftOwnable_init(msg.sender);
    }

    function initializeNftOwnable(address owner) public initializer() {
        __NftOwnable_init(owner);
    }

    function linkToNftOwnable(address nftOwnableAddress) external {
        _linkToNftOwnable(nftOwnableAddress);
    }

}


contract NftOwnableMockUninitialized is NftOwnable {

    function initialize(
        address initialOwner
    )
        public
        initializer()
    {
        __NftOwnable_init(initialOwner);
    }
/*
    function linkToNftOwnable(address nftOwnableAddress) external {
        _linkToNftOwnable(nftOwnableAddress);
    }
*/
}