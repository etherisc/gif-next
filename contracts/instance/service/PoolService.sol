// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegistry} from "../../registry/IRegistry.sol";
import {IInstance} from "../../instance/IInstance.sol";
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
        (IRegistry.ObjectInfo memory info, IInstance instance) = _getAndVerifyComponentInfoAndInstance(POOL());
        instance.setPoolFees(info.nftId, stakingFee, performanceFee);
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
        IRegistry.ObjectInfo memory bundleInfo = IRegistry.ObjectInfo(
            zeroNftId(),
            poolNftId,  
            BUNDLE(),
            address(0),
            owner,
            "" 
        );
        bundleNftId = _registry.registerFrom(msg.sender, bundleInfo);

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
            TokenHandler tokenHandler = instance.getTokenHandler(poolNftId);
            address bundleOwner = _registry.ownerOf(bundleNftId);
            address poolWallet = instance.getPoolSetup(poolNftId).wallet;

            tokenHandler.transfer(
                bundleOwner,
                poolWallet,
                stakingAmount
            );
        }
    }
}
