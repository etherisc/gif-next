// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegistry} from "../../../registry/IRegistry.sol";
import {NftId} from "../../../types/NftId.sol";
import {UFixed} from "../../../types/UFixed.sol";
import {IProductService} from "../../service/IProductService.sol";
import {IPoolService} from "../../service/IPoolService.sol";

interface IPool {
    struct PoolInfo {
        bool isVerifying;
        UFixed collateralizationLevel;
    }
}

interface IPoolModule is IPool {

    function registerPool(
        NftId poolNftId, 
        bool isVerifying, 
        UFixed collateralizationLevel
    ) external;

    function addBundleToPool(
        NftId bundleNftId,
        NftId poolNftId,
        uint256 amount
    ) external;

    function getPoolInfo(
        NftId nftId
    ) external view returns (PoolInfo memory info);

    function getBundleCount(NftId poolNftId) external view returns (uint256 bundleCount);
    function getBundleNftId(NftId poolNftId, uint256 index) external view returns (NftId bundleNftId);

    // repeat service linked signatures to avoid linearization issues
    function getPoolService() external returns(IPoolService);
}
