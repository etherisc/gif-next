// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {ObjectType, POOL} from "../types/ObjectType.sol";
import {IPoolService} from "../instance/service/IPoolService.sol";
import {NftId} from "../types/NftId.sol";
import {Fee} from "../types/Fee.sol";
import {IPoolBase} from "./IPoolBase.sol";
import {ComponentBase} from "./ComponentBase.sol";

contract Pool is ComponentBase, IPoolBase {
    IPoolService private _poolService;

    constructor(
        address registry,
        NftId instanceNftid,
        // TODO refactor into tokenNftId
        address token
    ) ComponentBase(registry, instanceNftid, token)
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
}
