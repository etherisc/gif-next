// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IOwnable, IRegistry, IRegistryLinked} from "../../registry/IRegistry.sol";

interface IPool {

    struct PoolInfo {
        uint256 nftId;
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
        uint256 poolNftId,
        uint256 policyNftId
    )
        external;

    function createPoolInfo(
        uint256 nftId,
        address wallet,
        address token
    )
        external;

    function getPoolInfo(uint256 nftId)
        external
        view
        returns(PoolInfo memory info);
}