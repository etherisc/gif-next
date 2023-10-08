// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegistry} from "../../../registry/IRegistry.sol";

import {IProductService} from "../../service/IProductService.sol";
import {IPoolService} from "../../service/IPoolService.sol";

import {NftId} from "../../../types/NftId.sol";
import {Key32, KeyId} from "../../../types/Key32.sol";
import {LibNftIdSet} from "../../../types/NftIdSet.sol";
import {ObjectType, PRODUCT, ORACLE, POOL, BUNDLE, POLICY} from "../../../types/ObjectType.sol";
import {StateId, ACTIVE, PAUSED, ARCHIVED, CLOSED, APPLIED, REVOKED, DECLINED} from "../../../types/StateId.sol";
import {Timestamp, blockTimestamp, zeroTimestamp} from "../../../types/Timestamp.sol";
import {Blocknumber, blockNumber} from "../../../types/Blocknumber.sol";

import {IKeyValueStore} from "../../base/IKeyValueStore.sol";
import {ModuleBase} from "../../base/ModuleBase.sol";

import {IBundleModule} from "./IBundle.sol";

abstract contract BundleModule is 
    ModuleBase,
    IBundleModule
{

    using LibNftIdSet for LibNftIdSet.Set;

    mapping(NftId bundleNftId => LibNftIdSet.Set policies) private _collateralizedPolicies;
    mapping(NftId bundleNftId => mapping(NftId policyNftId => uint256 amount)) private _collateralizationAmount;

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
        _initialize(keyValueStore, BUNDLE());
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
            poolNftId,
            filter,
            amount, // capital
            0, // locked capital
            amount, // balance
            blockTimestamp().addSeconds(lifetime), // expiredAt
            zeroTimestamp() // closedAt
        );

        _create(bundleNftId, abi.encode(bundleInfo));
    }

    function setBundleInfo(NftId bundleNftId, BundleInfo memory bundleInfo)
        external
        override
        onlyPoolOrProductService
    {
        _updateData(bundleNftId, abi.encode(bundleInfo));
    }

    function updateBundleState(NftId bundleNftId, StateId state)
        external
        override
        onlyBundlePoolService
    {
        _updateState(bundleNftId, state);
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
        return abi.decode(_getData(bundleNftId), (BundleInfo));
    }

    function getBundleState(NftId bundleNftId) external view override returns(StateId state) {
        return _getState(bundleNftId);
    }
}