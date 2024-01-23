// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Pool} from "../../components/Pool.sol";
import {IRegistry} from "../../registry/IRegistry.sol";
import {IInstance} from "../../instance/IInstance.sol";
import {IBundle} from "../../instance/module/IBundle.sol";
import {TokenHandler} from "../../instance/module/ITreasury.sol";
import {ISetup} from "../module/ISetup.sol";

import {IVersionable} from "../../shared/IVersionable.sol";
import {Versionable} from "../../shared/Versionable.sol";
import {INftOwnable} from "../../shared/INftOwnable.sol";

import {NftId, NftIdLib, zeroNftId} from "../../types/NftId.sol";
import {POOL, BUNDLE} from "../../types/ObjectType.sol";
import {POOL_OWNER_ROLE, RoleId} from "../../types/RoleId.sol";
import {Fee, FeeLib} from "../../types/Fee.sol";
import {Version, VersionLib} from "../../types/Version.sol";
import {KEEP_STATE} from "../../types/StateId.sol";
import {zeroTimestamp} from "../../types/Timestamp.sol";

import {IService} from "../../shared/IService.sol";
import {Service} from "../../shared/Service.sol";
import {ComponentServiceBase} from "../base/ComponentServiceBase.sol";
import {IPoolService} from "./IPoolService.sol";
import {IRegistryService} from "../../registry/IRegistryService.sol";
import {InstanceService} from "../InstanceService.sol";
import {InstanceReader} from "../InstanceReader.sol";


string constant POOL_SERVICE_NAME = "PoolService";

contract PoolService is 
    ComponentServiceBase, 
    IPoolService 
{
    using NftIdLib for NftId;

    string public constant NAME = "PoolService";

    address internal _registryAddress;

    function _initialize(
        address owner, 
        bytes memory data
    )
        internal
        initializer
        virtual override
    {
        address initialOwner = address(0);
        (_registryAddress, initialOwner) = abi.decode(data, (address, address));

        _initializeService(_registryAddress, initialOwner);

        _registerInterface(type(IService).interfaceId);
        _registerInterface(type(IPoolService).interfaceId);
    }

    function getName() public pure override(Service, IService) returns(string memory name) {
        return NAME;
    }

    function register(address poolComponentAddress) 
        external 
        onlyInstanceRole(POOL_OWNER_ROLE(), poolComponentAddress)
        returns (NftId poolNftId)
    {
        address componentOwner = msg.sender;
        Pool pool = Pool(poolComponentAddress);
        IInstance instance = pool.getInstance();
        
        IRegistryService registryService = getRegistryService();
        (IRegistry.ObjectInfo memory poolObjInfo, bytes memory initialObjData ) = registryService.registerPool(
            pool,
            componentOwner
        );
        poolNftId = poolObjInfo.nftId;

        ISetup.PoolSetupInfo memory initialSetup = abi.decode(
            initialObjData,
            (ISetup.PoolSetupInfo)
        );
        instance.createPoolSetup(poolNftId, initialSetup);
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
        InstanceReader instanceReader = instance.getInstanceReader();
        NftId poolNftId = poolInfo.nftId;

        ISetup.PoolSetupInfo memory poolSetupInfo = instanceReader.getPoolSetupInfo(poolNftId);
        poolSetupInfo.poolFee = poolFee;
        poolSetupInfo.stakingFee = stakingFee;
        poolSetupInfo.performanceFee = performanceFee;
        
        instance.updatePoolSetup(poolNftId, poolSetupInfo, KEEP_STATE());
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
        InstanceReader instanceReader = instance.getInstanceReader();
        NftId poolNftId = info.nftId;

        IBundle.BundleInfo  memory bundleInfo = IBundle.BundleInfo(
            poolNftId,
            FeeLib.zeroFee(),
            filter,
            stakingAmount,
            0,
            stakingAmount,
            lifetime,
            zeroTimestamp(),
            zeroTimestamp()
        );

        // register bundle with registry
        bundleNftId = getRegistryService().registerBundle(
            IRegistry.ObjectInfo(
                zeroNftId(), 
                poolNftId,
                BUNDLE(),
                false, // intercepting property for bundles is defined on pool
                address(0),
                owner,
                abi.encode(bundleInfo)
            )
        );

        // create bundle info in instance
        instance.createBundle(bundleNftId, bundleInfo);

        // TODO add bundle to pool in instance
        
        // TODO collect capital
        // _processStakingByTreasury(
        //     instanceReader,
        //     zeroNftId(),
        //     poolNftId,
        //     bundleNftId,
        //     stakingAmount);

        // TODO add logging
    }

    function setBundleFee(
        NftId bundleNftId,
        Fee memory fee
    )
        external
        override
    {
        (IRegistry.ObjectInfo memory info , IInstance instance) = _getAndVerifyComponentInfoAndInstance(POOL());
        InstanceReader instanceReader = instance.getInstanceReader();
        NftId poolNftId = info.nftId;

        IBundle.BundleInfo memory bundleInfo = instanceReader.getBundleInfo(bundleNftId);
        require(bundleInfo.poolNftId.gtz(), "ERROR:PLS-010:BUNDLE_UNKNOWN");
        require(poolNftId == bundleInfo.poolNftId, "ERROR:PLS-011:BUNDLE_POOL_MISMATCH");

        bundleInfo.fee = fee;

        instance.updateBundle(bundleNftId, bundleInfo, KEEP_STATE());
    }



    function _processStakingByTreasury(
        InstanceReader instanceReader,
        NftId productNftId,
        NftId poolNftId,
        NftId bundleNftId,
        uint256 stakingAmount
    )
        internal
    {
        // process token transfer(s)
        if(stakingAmount > 0) {
            TokenHandler tokenHandler = TokenHandler(instanceReader.getTokenHandler(productNftId));
            address bundleOwner = getRegistry().ownerOf(bundleNftId);
            ISetup.PoolSetupInfo memory poolInfo = instanceReader.getPoolSetupInfo(poolNftId);
            
            tokenHandler.transfer(
                bundleOwner,
                poolInfo.wallet,
                stakingAmount
            );
        }
    }
}
