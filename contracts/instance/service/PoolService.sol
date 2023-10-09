// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegistry} from "../../registry/IRegistry.sol";
import {IInstance} from "../../instance/IInstance.sol";
import {ITreasury, ITreasuryModule, TokenHandler} from "../../instance/module/treasury/ITreasury.sol";

import {IVersionable} from "../../shared/IVersionable.sol";
import {Versionable} from "../../shared/Versionable.sol";

import {NftId, NftIdLib} from "../../types/NftId.sol";
import {POOL, BUNDLE} from "../../types/ObjectType.sol";
import {Fee} from "../../types/Fee.sol";
import {Version, VersionLib} from "../../types/Version.sol";

import {ComponentServiceBase} from "../base/ComponentServiceBase.sol";
import {IPoolService} from "./IPoolService.sol";


contract PoolService is ComponentServiceBase, IPoolService {
    using NftIdLib for NftId;

    string public constant NAME = "PoolService";

    constructor(
        address registry,
        NftId registryNftId
    ) ComponentServiceBase(registry, registryNftId) // solhint-disable-next-line no-empty-blocks
    {
        _registerInterface(type(IPoolService).interfaceId);
    }

    function getVersion()
        public 
        pure 
        virtual override (IVersionable, Versionable)
        returns(Version)
    {
        return VersionLib.toVersion(3,0,0);
    }

    function getName() external pure override returns(string memory name) {
        return NAME;
    }

    function setFees(
        Fee memory stakingFee,
        Fee memory performanceFee
    )
        external
        override
    {
        (IRegistry.ObjectInfo memory poolInfo, IInstance instance) = _getAndVerifyComponentInfoAndInstance(POOL());

        NftId productNftId = instance.getProductNftId(poolInfo.nftId);
        ITreasury.TreasuryInfo memory treasuryInfo = instance.getTreasuryInfo(productNftId);
        treasuryInfo.stakingFee = stakingFee;
        treasuryInfo.performanceFee = performanceFee;
        instance.setTreasuryInfo(productNftId, treasuryInfo);
    }

    function createBundle(
        address owner, 
        uint256 stakingAmount, 
        uint256 lifetime, 
        bytes calldata filter
    )
        external
        override
        returns(NftId bundleNftId)
    {
        (IRegistry.ObjectInfo memory info, IInstance instance) = _getAndVerifyComponentInfoAndInstance(POOL());

        // register bundle with registry
        NftId poolNftId = info.nftId;
        bundleNftId = _registry.registerObjectForInstance(
            poolNftId, 
            BUNDLE(), 
            owner,
            "");

        // create bundle info in instance
        instance.createBundleInfo(
            bundleNftId,
            poolNftId,
            stakingAmount,
            lifetime,
            filter);

        // add bundle to pool in instance
        instance.addBundleToPool(
            bundleNftId,
            poolNftId,
            stakingAmount);

        // collect capital
        _processStakingByTreasury(
            instance,
            poolNftId,
            bundleNftId,
            stakingAmount);

        // TODO add logging
    }


    function _processStakingByTreasury(
        IInstance instance,
        NftId poolNftId,
        NftId bundleNftId,
        uint256 stakingAmount
    )
        internal
    {
        // process token transfer(s)
        if(stakingAmount > 0) {
            NftId productNftId = instance.getProductNftId(poolNftId);
            TokenHandler tokenHandler = instance.getTokenHandler(productNftId);
            address bundleOwner = _registry.getOwner(bundleNftId);
            address poolWallet = instance.getComponentWallet(poolNftId);

            tokenHandler.transfer(
                bundleOwner,
                poolWallet,
                stakingAmount
            );
        }
    }
}
