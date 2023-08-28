// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IOwnable, IRegistry, IRegistryLinked} from "../../registry/IRegistry.sol";
import {NftId} from "../../types/NftId.sol";

interface IPool {

    struct PoolInfo {
        NftId nftId;
        address wallet;
        address token;
        uint256 capital;
        uint256 lockedCapital;
    }
}

interface IPoolModule is
    IOwnable,
    IRegistryLinked,
    IPool
{
    
    function underwrite(
        NftId poolNftId,
        NftId policyNftId
    )
        external;

    function createPoolInfo(
        NftId nftId,
        address wallet,
        address token
    )
        external;

    function getPoolInfo(NftId nftId)
        external
        view
        returns(PoolInfo memory info);
}