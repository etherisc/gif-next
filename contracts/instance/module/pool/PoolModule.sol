// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegistry} from "../../../registry/IRegistry.sol";
import {IProductService} from "../../service/IProductService.sol";
import {IPoolService} from "../../service/IPoolService.sol";
import {IPolicy, IPolicyModule} from "../../module/policy/IPolicy.sol";
import {ITreasuryModule} from "../../module/treasury/ITreasury.sol";

import {NftId} from "../../../types/NftId.sol";
import {POOL} from "../../../types/ObjectType.sol";
import {LibNftIdSet} from "../../../types/NftIdSet.sol";
import {StateId, APPLIED} from "../../../types/StateId.sol";
import {UFixed} from "../../../types/UFixed.sol";

import {IKeyValueStore} from "../../base/IKeyValueStore.sol";
import {IPoolModule} from "./IPoolModule.sol";
import {ModuleBase} from "../../base/ModuleBase.sol";

abstract contract PoolModule is
    ModuleBase,
    IPoolModule
{
    using LibNftIdSet for LibNftIdSet.Set;

    // mapping(NftId poolNftId => PoolInfo info) private _poolInfo;
    mapping(NftId poolNftId => LibNftIdSet.Set bundles) private _bundlesForPool;


    // TODO try to keep 1 modifier in 1 place...
    modifier onlyComponentOwnerService() virtual {
        require(
            msg.sender == address(this.getComponentOwnerService()),
            "ERROR:CMP-001:NOT_COMPONENT_OWNER_SERVICE"
        );
        _;
    }

    modifier poolServiceCallingPool() {
        require(
            msg.sender == address(this.getPoolService()),
            "ERROR:PL-001:NOT_POOL_SERVICE"
        );
        _;
    }

    function initializePoolModule(IKeyValueStore keyValueStore) internal {
        _initialize(keyValueStore);
    }

    function registerPool(
        NftId nftId, 
        PoolInfo memory info
    )
        public
        onlyComponentOwnerService
        override
    {
        _create(POOL(), nftId, abi.encode(info));
    }

    function addBundleToPool(
        NftId bundleNftId,
        NftId poolNftId,
        uint256 // amount
    )
        external
        override
    {
        LibNftIdSet.Set storage bundleSet = _bundlesForPool[poolNftId];
        require(
            !bundleSet.contains(bundleNftId),
            "ERROR:PL-020:BUNDLE_ALREADY_ADDED");

        bundleSet.add(bundleNftId);
    }


    function getPoolInfo(
        NftId nftId
    ) external view override returns (PoolInfo memory info) {
        return abi.decode(_getData(POOL(), nftId), (PoolInfo));
    }


    function getBundleCount(NftId poolNftId) external view override returns (uint256 bundleCount) {
        return _bundlesForPool[poolNftId].getLength();
    }


    function getBundleNftId(NftId poolNftId, uint256 index) external view override returns (NftId bundleNftId) {
        return _bundlesForPool[poolNftId].getElementAt(index);
    }

}
