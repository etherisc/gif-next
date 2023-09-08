// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {ObjectType, POOL} from "../types/ObjectType.sol";
import {IPoolComponent} from "./IPool.sol";
import {Component} from "./Component.sol";

contract Pool is Component, IPoolComponent {
    constructor(
        address registry,
        address instance,
        address token
    ) Component(registry, instance, token) {}

    // from registerable
    function getType() public pure override returns(ObjectType) {
        return POOL();
    }

    // from registerable
    function getData() external view override returns (bytes memory data) {
        return bytes(abi.encode(getInstance().getNftId()));
    }
}
