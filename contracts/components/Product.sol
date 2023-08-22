// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Component} from "./Component.sol";


contract Product is Component {

    constructor(address instance) Component(instance) { }

    // from registerable
    function getType() public view override returns(uint256) {
        return _registry.PRODUCT();
    }

    // from registerable
    function getData() external view override returns(bytes memory data) {
        return bytes(abi.encode(getInstance().getNftId()));
    }
}