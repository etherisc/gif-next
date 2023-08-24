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

interface IPoolCreateInfo is {

    function createPoolInfo(
        uint256 nftId,
        address wallet,
        address token
    )
        external;

}

interface IPoolModule is
    IOwnable,
    IRegistryLinked,
    IPoolCreateInfo,
    IPool
{
    
    function underwrite(
        uint256 poolNftId,
        uint256 policyNftId
    )
        external;

    function getPoolInfo(uint256 nftId)
        external
        view
        returns(PoolInfo memory info);
}