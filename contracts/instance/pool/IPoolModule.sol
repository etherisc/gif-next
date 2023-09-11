// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IOwnable, IRegistry, IRegistryLinked} from "../../registry/IRegistry.sol";
import {NftId} from "../../types/NftId.sol";

interface IPool {
    struct PoolInfo {
        NftId nftId;
        uint256 capital;
        uint256 lockedCapital;
    }
}

interface IPoolModule is IOwnable, IRegistryLinked, IPool {

    function underwrite(NftId policyNftId, NftId productNftId) external;

    function registerPool(NftId nftId) external;

    function getPoolInfo(NftId nftId) external view returns (PoolInfo memory info);
}
