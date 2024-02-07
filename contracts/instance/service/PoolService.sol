// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Pool} from "../../components/Pool.sol";
import {IRegistry} from "../../registry/IRegistry.sol";
import {IInstance} from "../../instance/IInstance.sol";
import {IBundle} from "../../instance/module/IBundle.sol";
import {TokenHandler} from "../../instance/module/ITreasury.sol";
import {ISetup} from "../module/ISetup.sol";
import {IPolicy} from "../module/IPolicy.sol";

import {IVersionable} from "../../shared/IVersionable.sol";
import {Versionable} from "../../shared/Versionable.sol";
import {INftOwnable} from "../../shared/INftOwnable.sol";

import {NftId, NftIdLib, zeroNftId} from "../../types/NftId.sol";
import {ObjectType, POOL, BUNDLE} from "../../types/ObjectType.sol";
import {POOL_OWNER_ROLE, RoleId} from "../../types/RoleId.sol";
import {Fee, FeeLib} from "../../types/Fee.sol";
import {Version, VersionLib} from "../../types/Version.sol";
import {KEEP_STATE, StateId} from "../../types/StateId.sol";
import {TimestampLib, zeroTimestamp} from "../../types/Timestamp.sol";

import {IService} from "../../shared/IService.sol";
import {Service} from "../../shared/Service.sol";
import {BundleManager} from "../BundleManager.sol";
import {ComponentServiceBase} from "../base/ComponentServiceBase.sol";
import {IPoolService} from "./IPoolService.sol";
import {IRegistryService} from "../../registry/IRegistryService.sol";
import {InstanceService} from "../InstanceService.sol";
import {InstanceReader} from "../InstanceReader.sol";
import {IBaseComponent} from "../../components/IBaseComponent.sol";

string constant POOL_SERVICE_NAME = "PoolService";

contract PoolService is 
    ComponentServiceBase, 
    IPoolService 
{
    using NftIdLib for NftId;

    address internal _registryAddress;

    function _initialize(
        address owner, 
        bytes memory data
    )
        internal
        initializer
        virtual override
    {
        address registryAddress;
        address initialOwner;
        (registryAddress, initialOwner) = abi.decode(data, (address, address));
        // TODO while PoolService is not deployed in PoolServiceManager constructor
        //      owner is PoolServiceManager deployer
        _initializeService(registryAddress, owner);

        _registerInterface(type(IPoolService).interfaceId);
    }

    function getDomain() public pure override(Service, IService) returns(ObjectType) {
        return POOL();
    }

    function register(address poolAddress) 
        external
        returns(NftId poolNftId)
    {
        address poolOwner = msg.sender;
        IBaseComponent pool = IBaseComponent(poolAddress);

        IRegistry.ObjectInfo memory info;
        bytes memory data;
        (info, data) = getRegistryService().registerPool(pool, poolOwner);

        IInstance instance = _getInstance(info);

        bool hasRole = getInstanceService().hasRole(
            poolOwner, 
            POOL_OWNER_ROLE(), 
            address(instance));

        if(!hasRole) {
            revert ExpectedRoleMissing(POOL_OWNER_ROLE(), poolOwner);
        }

        poolNftId = info.nftId;
        ISetup.PoolSetupInfo memory initialSetup = _decodeAndVerifyPoolSetup(data);
        instance.createPoolSetup(poolNftId, initialSetup);
    }

    function _decodeAndVerifyPoolSetup(bytes memory data) internal returns(ISetup.PoolSetupInfo memory setup)
    {
        setup = abi.decode(
            data,
            (ISetup.PoolSetupInfo)
        );

        // TODO add checks if applicable 
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
}
