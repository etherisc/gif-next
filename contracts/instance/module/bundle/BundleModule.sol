// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegistry} from "../../../registry/IRegistry.sol";

import {LifecycleModule} from "../lifecycle/LifecycleModule.sol";
import {IProductService} from "../../service/IProductService.sol";
import {IPoolService} from "../../service/IPoolService.sol";

import {NftId} from "../../../types/NftId.sol";
import {Key32, KeyId} from "../../../types/Key32.sol";
import {LibNftIdSet} from "../../../types/NftIdSet.sol";
import {ObjectType, PRODUCT, ORACLE, POOL, BUNDLE, POLICY} from "../../../types/ObjectType.sol";
import {StateId, ACTIVE, PAUSED, ARCHIVED, CLOSED, APPLIED, REVOKED, DECLINED} from "../../../types/StateId.sol";
import {Timestamp, blockTimestamp, zeroTimestamp} from "../../../types/Timestamp.sol";
import {Blocknumber, blockNumber} from "../../../types/Blocknumber.sol";

import {IKeyValueStore} from "../../IKeyValueStore.sol";
import {ILifecycleModule} from "../lifecycle/ILifecycle.sol";
import {IBundleModule} from "./IBundle.sol";

abstract contract BundleModule is
    IBundleModule
{

    using LibNftIdSet for LibNftIdSet.Set;

    mapping(NftId bundleNftId => LibNftIdSet.Set policies) private _collateralizedPolicies;
    mapping(NftId bundleNftId => mapping(NftId policyNftId => uint256 amount)) private _collateralizationAmount;

    IKeyValueStore private _keyValueStore;
    LifecycleModule private _lifecycleModule;

    modifier onlyBundlePoolService() {
        require(
            msg.sender == address(this.getPoolService()),
            "ERROR:BDL-001:NOT_POOL_SERVICE"
        );
        _;
    }

    modifier onlyBundleProductService() {
        require(
            msg.sender == address(this.getProductService()),
            "ERROR:BDL-002:NOT_PRODUCT_SERVICE"
        );
        _;
    }

    modifier onlyPoolOrProductService() {
        require(
            msg.sender == address(this.getPoolService())
                || msg.sender == address(this.getProductService()),
            "ERROR:BDL-003:NOT_POOL_OR_PRODUCT_SERVICE"
        );
        _;
    }

    function initializeBundleModule(IKeyValueStore keyValueStore) internal {
        _lifecycleModule = LifecycleModule(address(this));
        _keyValueStore = keyValueStore;
    }

    function createBundleInfo(
        NftId bundleNftId,
        NftId poolNftId,
        uint256 amount, 
        uint256 lifetime, 
        bytes calldata filter
    )
        external
        onlyBundlePoolService
        override
    {
        BundleInfo memory bundleInfo = BundleInfo(
            bundleNftId,
            poolNftId,
            filter,
            amount, // capital
            0, // locked capital
            amount, // balance
            blockTimestamp().addSeconds(lifetime), // expiredAt
            zeroTimestamp() // closedAt
        );

        _keyValueStore.createWithNftId(
            bundleNftId, 
            BUNDLE(),
            abi.encode(bundleInfo));

        // _keyValueStore.create(
        //     _toKey32(bundleNftId), 
        //     BUNDLE(), 
        //     _lifecycleModule.getInitialState(BUNDLE()),
        //     abi.encode(bundleInfo));
    }

    function setBundleInfo(BundleInfo memory bundleInfo)
        external
        override
        onlyPoolOrProductService
    {
        // Key32 key = _toKey32(bundleInfo.nftId);
        _keyValueStore.updateDataWithNftId(bundleInfo.nftId, abi.encode(bundleInfo));

        // Key32 key = _toKey32(bundleInfo.nftId);
        // _keyValueStore.updateData(key, abi.encode(bundleInfo));
    }

    function setBundleState(NftId bundleNftId, StateId state)
        external
        override
        onlyBundlePoolService
    {
        _keyValueStore.updateStateWithNftId(bundleNftId, state);

        // Key32 key = _toKey32(bundleNftId);
        // _keyValueStore.updateState(key, state);
    }

    function collateralizePolicy(
        NftId bundleNftId, 
        NftId policyNftId, 
        uint256 collateralAmount
    )
        external
        onlyBundleProductService
        override
    {
        _collateralizationAmount[bundleNftId][policyNftId] = collateralAmount;
        _collateralizedPolicies[bundleNftId].add(policyNftId);
    }

    function releasePolicy(
        NftId bundleNftId,
        NftId policyNftId
    )
        external
        onlyBundleProductService
        override 
        returns(uint256 collateralAmount)
    {
        collateralAmount = _collateralizationAmount[bundleNftId][policyNftId];
        delete _collateralizationAmount[bundleNftId][policyNftId];
        _collateralizedPolicies[bundleNftId].remove(policyNftId);
    }

    function getBundleInfo(NftId bundleNftId) external view override returns(BundleInfo memory bundleInfo) {
        // return _bundleInfo[bundleNftId];
        Key32 key = _toKey32(bundleNftId);
        return abi.decode(_keyValueStore.getData(key), (BundleInfo));
    }

    function _toKey32(NftId bundleNftId) private pure returns (Key32 key) {
        return bundleNftId.toKey32(BUNDLE());
    }    
}