// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {ObjectType, POOL} from "../types/ObjectType.sol";
import {Fee} from "../types/Fee.sol";
import {IPoolComponent} from "./IPool.sol";
import {Component} from "./Component.sol";

contract Pool is Component, IPoolComponent {
    Fee private _stakingFee;
    Fee private _performanceFee;

    constructor(
        address registry,
        address instance,
        address token,
        Fee memory stakingFee,
        Fee memory performanceFee
    ) Component(registry, instance, token) {
        _stakingFee = stakingFee;
        _performanceFee = performanceFee;
    }

    // from pool component
    function getStakingFee()
        external
        view
        override
        returns (Fee memory stakingFee)
    {
        return _stakingFee;
    }

    function getPerformanceFee()
        external
        view
        override
        returns (Fee memory performanceFee)
    {
        return _performanceFee;
    }

    // from registerable
    function getType() public pure override returns (ObjectType) {
        return POOL();
    }

    // from registerable
    function getData() external view override returns (bytes memory data) {
        return bytes(abi.encode(getInstance().getNftId()));
    }
}
