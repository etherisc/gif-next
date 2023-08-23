// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IPool} from "./IPool.sol";
import {Component} from "./Component.sol";


contract Pool is
    Component,
    IPool
{

    constructor(
        address registry, 
        address instance
    )
        Component(registry, instance)
    { }

    // from registerable
    function getType() public view override returns(uint256) {
        return _registry.POOL();
    }

    // from registerable
    function getData() external view override returns(bytes memory data) {
        return bytes(abi.encode(getInstance().getNftId()));
    }
}