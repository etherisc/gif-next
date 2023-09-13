// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegistry, IRegistryLinked} from "../../registry/IRegistry.sol";
import {NftId} from "../../types/NftId.sol";
import {ObjectType, PRODUCT, ORACLE, POOL, BUNDLE, POLICY} from "../../types/ObjectType.sol";
import {StateId, ACTIVE, PAUSED, ARCHIVED, CLOSED, APPLIED, REVOKED, DECLINED} from "../../types/StateId.sol";
import {ILifecycleModule} from "../lifecycle/ILifecycle.sol";
import {IBundleModule} from "./IBundle.sol";

abstract contract BundleModule is
    IRegistryLinked, 
    IBundleModule
{

    function createBundle(
        IRegistry.RegistryInfo memory bundleInfo,
        uint256 amount, 
        uint256 lifetime, 
        bytes calldata filter
    )
        external
        override
        returns(NftId nftId)
    {

    }

    function fundBundle(NftId bundleNftId, uint256 amount) external override {

    }

    function defundBundle(NftId bundleNftId, uint256 amount) external override {

    }

    function pauseBundle(NftId bundleNftId) external override {

    }

    function activateBundle(NftId bundleNftId) external override {

    }

    function extendBundle(NftId bundleNftId, uint256 lifetimeExtension) external override {

    }

    function closeBundle(NftId bundleNftId) external override {

    }

    function collateralizePolicy(NftId bundleNftId, NftId policyNftId, uint256 collateralAmount) external override {

    }

    function releasePolicy(NftId bundleNftId, NftId policyNftId) external override returns(uint256 collateralAmount) {

    }

    function processPremium(uint256 bundleId, bytes32 processId, uint256 amount) external override {

    }

    function processPayout(uint256 bundleId, bytes32 processId, uint256 amount) external override {

    }
}