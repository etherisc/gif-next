// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegistry} from "../../registry/IRegistry.sol";
import {IInstance} from "../../instance/IInstance.sol";
import {IBundle} from "../../instance/module/bundle/IBundle.sol";
import {ITreasury, ITreasuryModule, TokenHandler} from "../../instance/module/treasury/ITreasury.sol";

import {IVersionable} from "../../shared/IVersionable.sol";
import {Versionable} from "../../shared/Versionable.sol";

import {NftId, NftIdLib, zeroNftId} from "../../types/NftId.sol";
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
        NftId registryNftId,
        address initialOwner
    ) ComponentServiceBase(registry, registryNftId, initialOwner)
    {
        _registerInterface(type(IPoolService).interfaceId);
    }

    function getName() external pure override returns(string memory name) {
        return NAME;
    }

    function setFees(
        Fee memory poolFee,
        Fee memory stakingFee,
        Fee memory performanceFee
    )
        external
        override
    {
        (IRegistry.ObjectInfo memory poolInfo, IInstance instance) = _getAndVerifyComponentInfoAndInstance(POOL());

        NftId productNftId = instance.getProductNftId(poolInfo.nftId);
        ITreasury.TreasuryInfo memory treasuryInfo = instance.getTreasuryInfo(productNftId);
        treasuryInfo.poolFee = poolFee;
        treasuryInfo.stakingFee = stakingFee;
        treasuryInfo.performanceFee = performanceFee;
        instance.setTreasuryInfo(productNftId, treasuryInfo);
    }

    function createBundle(
        address owner, 
        Fee memory fee, 
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
        bundleNftId = getRegistry().registerFrom(
            msg.sender, 
            IRegistry.ObjectInfo(
                zeroNftId(),
                poolNftId,
                BUNDLE(),
                address(0),
                owner,
                ""
            )
        );

        // create bundle info in instance
        instance.createBundleInfo(
            bundleNftId,
            poolNftId,
            fee,
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

    function setBundleFee(
        NftId bundleNftId,
        Fee memory fee
    )
        external
        override
    {
        (IRegistry.ObjectInfo memory poolInfo, IInstance instance) = _getAndVerifyComponentInfoAndInstance(POOL());
        IBundle.BundleInfo memory bundleInfo = instance.getBundleInfo(bundleNftId);
        require(bundleInfo.poolNftId.gtz(), "ERROR:PLS-010:BUNDLE_UNKNOWN");
        require(poolInfo.nftId == bundleInfo.poolNftId, "ERROR:PLS-011:BUNDLE_POOL_MISMATCH");
        bundleInfo.fee = fee;
        instance.setBundleInfo(bundleNftId, bundleInfo);
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
            address bundleOwner = getRegistry().ownerOf(bundleNftId);
            address poolWallet = instance.getComponentWallet(poolNftId);

            tokenHandler.transfer(
                bundleOwner,
                poolWallet,
                stakingAmount
            );
        }
    }
}
