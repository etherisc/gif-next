// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Fee} from "../types/Fee.sol";
import {NftId} from "../types/NftId.sol";
import {IComponentBase} from "./IComponentBase.sol";
import {IRegistry} from "../registry/IRegistry.sol";

interface IPoolBase is IComponentBase {

    struct PoolInfo {
        IRegistry.ObjectInfo forRegistry;
        NftId instanceNftId;
        NftId tokenNftId;
        address wallet;
        uint256 stakingFee;
        uint256 perfomanceFee;
    }

    function getPoolInfo() external view returns(PoolInfo memory info);

    function getStakingFee() external view returns (Fee memory stakingFee);

    function getPerformanceFee()
        external
        view
        returns (Fee memory performanceFee);
}
