// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegistry, IRegistryLinked} from "../../../registry/IRegistry.sol";

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

    modifier onlyBundleProductService() {
        require(
            this.senderIsProductService(),
            "ERROR:BDL-001:NOT_PRODUCT_SERVICE"
        );
        _;
    }

    modifier onlyBundlePoolService() {
        require(
            this.senderIsPoolService(),
            "ERROR:BDL-002:NOT_POOL_SERVICE"
        );
        _;
    }

    constructor() {
        _lifecycleModule = LifecycleModule(address(this));
    }

    function createBundle(
        IRegistry.ObjectInfo memory poolInfo,
        address initialOwner,
        uint256 amount, 
        uint256 lifetime, 
        bytes calldata filter
    )
        external
        override
        onlyBundlePoolService
        returns(NftId nftId)
    {

        nftId = this.getRegistry().registerObjectForInstance(
            poolInfo.nftId,
            BUNDLE(),
            initialOwner,
            ""
        );

        _bundleInfo[nftId] = BundleInfo(
            nftId,
            _lifecycleModule.getInitialState(BUNDLE()),
            filter,
            amount, // capital
            0, // locked capital
            amount, // balance
            blockTimestamp(), // createdAt
            blockTimestamp().addSeconds(lifetime), // expiredAt
            zeroTimestamp(), // closedAt
            blockNumber() // updatedAt
        );

        // TODO add logging
    }

    function pauseBundle(NftId bundleNftId)
        external    
        onlyBundlePoolService
        override
    {

    }

    function activateBundle(NftId bundleNftId)
        external    
        onlyBundlePoolService
        override
    {

    }

    function extendBundle(
        NftId bundleNftId,
        uint256 lifetimeExtension
    )
        external
        onlyBundlePoolService
        override
    {

    }

    function closeBundle(NftId bundleNftId)
        external    
        onlyBundlePoolService
        override
    {

    }

    function processStake(
        NftId nftId,
        uint256 amount
    )
        external
        onlyBundlePoolService
        override
    {
        // TODO add validation (bundle active or paused, not closed, not expired)

        BundleInfo storage info = _bundleInfo[nftId];
        info.capitalAmount += amount;
        info.balanceAmount += amount;
        info.updatedIn = blockNumber();

        // TODO add logging
    }

    function processUnstake(
        NftId nftId,
        uint256 amount
    )
        external
        onlyBundlePoolService
        override
    {
        BundleInfo storage info = _bundleInfo[nftId];
        require(
            info.balanceAmount - info.lockedAmount >= amount,
            "ERROR:BDL-010:AMOUNT_TOO_LARGE");
        
        // TODO fix book keeping in a way that provides
        // continuous infor regarding profitability
        // this is needed to properly apply performance fees
        info.balanceAmount += amount;
        info.updatedIn = blockNumber();

        // TODO add logging
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
        BundleInfo storage info = _bundleInfo[bundleNftId];
        require(collateralAmount < info.balanceAmount - info.lockedAmount, "ERROR:BDL-020:CAPACITY_TOO_SMALL");
        // TODO add more validation (bundle active (not paused or closed), not closed, not expired)

        require(_collateralizationAmount[bundleNftId][policyNftId] == 0, "ERROR:BDL-021:ALREADY_COLLATERALIZED");
        _collateralizationAmount[bundleNftId][policyNftId] = collateralAmount;
        _collateralizedPolicies[bundleNftId].add(policyNftId);

        info.lockedAmount += collateralAmount;
        info.updatedIn = blockNumber();

        // TODO add logging
    }

    function processPremium(NftId bundleNftId, NftId policyNftId, uint256 amount)
        external
        onlyBundleProductService
        override
    {
    }

    function processPayout(NftId bundleNftId, NftId policyNftId, uint256 amount)
        external
        onlyBundleProductService
        override
    {
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
        require(_collateralizationAmount[bundleNftId][policyNftId] > 0, "ERROR:BDL-030:NOT_COLLATERALIZED");
        collateralAmount = _collateralizationAmount[bundleNftId][policyNftId];

        // TODO add more validation (policy is closed)

        delete _collateralizationAmount[bundleNftId][policyNftId];
        _collateralizedPolicies[bundleNftId].remove(policyNftId);

        BundleInfo storage info = _bundleInfo[bundleNftId];
        info.lockedAmount -= collateralAmount;
        info.updatedIn = blockNumber();

        // TODO add logging
    }
}