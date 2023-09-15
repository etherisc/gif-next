// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {ObjectType, POOL} from "../types/ObjectType.sol";
import {IPoolService} from "../instance/service/IPoolService.sol";
import {NftId} from "../types/NftId.sol";
import {Fee} from "../types/Fee.sol";
import {IPoolComponent} from "./IPool.sol";
import {Component} from "./Component.sol";

contract Pool is Component, IPoolComponent {
    IPoolService private _poolService;

    constructor(
        address registry,
        address instance,
        address token
    ) Component(registry, instance, token)
    {
        _poolService = _instance.getPoolService();
    }

    function _createBundle(
        address bundleOwner,
        uint256 amount,
        uint256 lifetime, 
        bytes calldata filter
    )
        internal
        returns(NftId bundleNftId)
    {
        bundleNftId = _poolService.createBundle(
            bundleOwner,
            amount,
            lifetime,
            filter
        );
    }

    // from pool component
    function getStakingFee()
        external
        view
        override
        returns (Fee memory stakingFee)
    {
        return _instance.getPoolSetup(getNftId()).stakingFee;
    }

    function getPerformanceFee()
        external
        view
        override
        returns (Fee memory performanceFee)
    {
        return _instance.getPoolSetup(getNftId()).performanceFee;
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
