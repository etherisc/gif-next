// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegistry} from "../../../registry/IRegistry.sol";

import {LifecycleModule} from "../lifecycle/LifecycleModule.sol";
import {IProductService} from "../../service/IProductService.sol";
import {IPoolService} from "../../service/IPoolService.sol";

import {NftId} from "../../../types/NftId.sol";
import {LibNftIdSet} from "../../../types/NftIdSet.sol";
import {ObjectType, PRODUCT, ORACLE, POOL, BUNDLE, POLICY} from "../../../types/ObjectType.sol";
import {StateId, ACTIVE, PAUSED, ARCHIVED, CLOSED, APPLIED, REVOKED, DECLINED} from "../../../types/StateId.sol";
import {Timestamp, blockTimestamp, zeroTimestamp} from "../../../types/Timestamp.sol";
import {Blocknumber, blockNumber} from "../../../types/Blocknumber.sol";

import {ILifecycleModule} from "../lifecycle/ILifecycle.sol";
import {IBundleModule} from "./IBundle.sol";

abstract contract BundleModule is
    IBundleModule
{

    using LibNftIdSet for LibNftIdSet.Set;

    mapping(NftId bundleNftId => BundleInfo info) private _bundleInfo;
    mapping(NftId bundleNftId => LibNftIdSet.Set policies) private _collateralizedPolicies;
    mapping(NftId bundleNftId => mapping(NftId policyNftId => uint256 amount)) private _collateralizationAmount;

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

    constructor() {
        _lifecycleModule = LifecycleModule(address(this));
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

        _bundleInfo[bundleNftId] = BundleInfo(
            bundleNftId,
            poolNftId,
            _lifecycleModule.getInitialState(BUNDLE()),
            filter,
            amount, // capital
            0, // locked capital
            amount, // balance
            blockTimestamp(), // createdAt
            blockTimestamp().addSeconds(lifetime), // expiredAt
            zeroTimestamp(), // closedAt
            blockNumber() // updatedIn
        );

        // TODO add logging
    }

    function setBundleInfo(BundleInfo memory bundleInfo)
        external
        override
        onlyPoolOrProductService
    {
        _bundleInfo[bundleInfo.nftId] = bundleInfo;
    }

    // function updateBundleState(
    //     NftId bundleNftId,
    //     StateId newState
    // )
    //     external    
    //     // add authz (both product and pool service)
    //     override
    // {
    //     BundleInfo storage info = _bundleInfo[bundleNftId];
    //     info.state = newState;
    //     info.updatedIn = blockNumber();
    // }

    // function extendBundle(
    //     NftId bundleNftId,
    //     uint256 lifetimeExtension
    // )
    //     external
    //     onlyBundlePoolService
    //     override
    // {
    //     BundleInfo storage info = _bundleInfo[bundleNftId];
    //     info.expiredAt = info.expiredAt.addSeconds(lifetimeExtension);
    //     info.updatedIn = blockNumber();
    // }

    // function closeBundle(
    //     NftId bundleNftId
    // )
    //     external
    //     onlyBundlePoolService
    //     override
    // {
    //     BundleInfo storage info = _bundleInfo[bundleNftId];
    //     info.state = CLOSED();
    //     info.closedAt = blockTimestamp();
    //     info.updatedIn = blockNumber();
    // }

    // function processStake(
    //     NftId nftId,
    //     uint256 amount
    // )
    //     external
    //     onlyBundlePoolService
    //     override
    // {
    //     BundleInfo storage info = _bundleInfo[nftId];
    //     info.capitalAmount += amount;
    //     info.balanceAmount += amount;
    //     info.updatedIn = blockNumber();
    // }

    // function processUnstake(
    //     NftId nftId,
    //     uint256 amount
    // )
    //     external
    //     onlyBundlePoolService
    //     override
    // {
    //     BundleInfo storage info = _bundleInfo[nftId];
    //     // TODO fix book keeping in a way that provides
    //     // continuous infor regarding profitability
    //     // this is needed to properly apply performance fees
    //     info.capitalAmount -= amount;
    //     info.balanceAmount -= amount;
    //     info.updatedIn = blockNumber();
    // }

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
    //     BundleInfo storage info = _bundleInfo[bundleNftId];
    //     info.lockedAmount -= collateralAmount;
    //     info.updatedIn = blockNumber();

        collateralAmount = _collateralizationAmount[bundleNftId][policyNftId];
        delete _collateralizationAmount[bundleNftId][policyNftId];
        _collateralizedPolicies[bundleNftId].remove(policyNftId);
    }

    // function addPremium(NftId bundleNftId, uint256 amount)
    //     external
    //     onlyBundleProductService
    //     override
    // {
    //     BundleInfo storage info = _bundleInfo[bundleNftId];
    //     info.capitalAmount += amount;
    //     info.balanceAmount += amount;
    //     info.updatedIn = blockNumber();
    // }

    // function subtractPayout(NftId bundleNftId, NftId policyNftId, uint256 amount)
    //     external
    //     onlyBundleProductService
    //     override
    // {
    //     BundleInfo storage info = _bundleInfo[bundleNftId];
    //     info.capitalAmount -= amount;
    //     info.lockedAmount -= amount;
    //     info.balanceAmount -= amount;
    //     info.updatedIn = blockNumber();

    //     // deduct amount from sum insured for this policy
    //     _collateralizationAmount[bundleNftId][policyNftId] -= amount;
    // }

    function getBundleInfo(NftId bundleNftId) external view override returns(BundleInfo memory bundleInfo) {
        return _bundleInfo[bundleNftId];
    }
}