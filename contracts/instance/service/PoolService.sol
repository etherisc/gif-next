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

import {Fee, FeeLib} from "../../types/Fee.sol";
import {NftId, NftIdLib, zeroNftId} from "../../types/NftId.sol";
import {ObjectType, POOL, BUNDLE} from "../../types/ObjectType.sol";
import {RoleId, POOL_OWNER_ROLE, PUBLIC_ROLE} from "../../types/RoleId.sol";
import {StateId, KEEP_STATE} from "../../types/StateId.sol";
import {TimestampLib, zeroTimestamp} from "../../types/Timestamp.sol";
import {Version, VersionLib} from "../../types/Version.sol";

import {IService} from "../../shared/IService.sol";
import {Service} from "../../shared/Service.sol";
import {BundleManager} from "../BundleManager.sol";
import {ComponentService} from "../base/ComponentService.sol";
import {IPoolService} from "./IPoolService.sol";
import {IRegistryService} from "../../registry/IRegistryService.sol";
import {InstanceService} from "../InstanceService.sol";
import {InstanceReader} from "../InstanceReader.sol";
import {IComponent} from "../../components/IComponent.sol";
import {IPoolComponent} from "../../components/IPoolComponent.sol";

string constant POOL_SERVICE_NAME = "PoolService";

contract PoolService is 
    ComponentService, 
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
        initializeService(registryAddress, owner);
        registerInterface(type(IPoolService).interfaceId);
    }

    function getDomain() public pure override(Service, IService) returns(ObjectType) {
        return POOL();
    }

    function register(address poolAddress) 
        external
        returns(NftId poolNftId)
    {
        (
            IComponent component,
            address owner,
            IInstance instance,
            NftId instanceNftId
        ) = _checkComponentForRegistration(
            poolAddress,
            POOL(),
            POOL_OWNER_ROLE());

        IPoolComponent pool = IPoolComponent(poolAddress);
        IRegistry.ObjectInfo memory registryInfo = getRegistryService().registerPool(pool, owner);
        pool.linkToRegisteredNftId();
        poolNftId = registryInfo.nftId;

        // amend component info with pool specific token handler
        ISetup.ComponentInfo memory componentInfo = pool.getComponentInfo();
        componentInfo.tokenHandler = new TokenHandler(address(componentInfo.token));

        // save amended component info with instance
        instance.createPoolSetup(poolNftId, componentInfo);

        getInstanceService().createGifTarget(instanceNftId, poolAddress, pool.getName());
        getInstanceService().grantPoolDefaultPermissions(instanceNftId, poolAddress, pool.getName());
    }


    function setMaxCapitalAmount(uint256 maxCapitalAmount)
        external
        virtual
    {
        (IRegistry.ObjectInfo memory registryInfo, IInstance instance) = _getAndVerifyComponentInfoAndInstance(POOL());
        InstanceReader instanceReader = instance.getInstanceReader();
        NftId poolNftId = registryInfo.nftId;

        ISetup.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(poolNftId);
        ISetup.PoolInfo memory poolInfo = abi.decode(componentInfo.data, (ISetup.PoolInfo));
        uint256 previousMaxCapitalAmount = poolInfo.maxCapitalAmount;

        poolInfo.maxCapitalAmount = maxCapitalAmount;
        componentInfo.data = abi.encode(poolInfo);
        instance.updatePoolSetup(poolNftId, componentInfo, KEEP_STATE());

        emit LogPoolServiceMaxCapitalAmountUpdated(poolNftId, previousMaxCapitalAmount, maxCapitalAmount);
    }

    function setBundleOwnerRole(RoleId bundleOwnerRole)
        external
        virtual
    {
        (IRegistry.ObjectInfo memory registryInfo, IInstance instance) = _getAndVerifyComponentInfoAndInstance(POOL());
        InstanceReader instanceReader = instance.getInstanceReader();
        NftId poolNftId = registryInfo.nftId;

        ISetup.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(poolNftId);
        ISetup.PoolInfo memory poolInfo = abi.decode(componentInfo.data, (ISetup.PoolInfo));

        // bundle owner role may only be set once per pool
        if(poolInfo.bundleOwnerRole != PUBLIC_ROLE()) {
            revert ErrorPoolServiceBundleOwnerRoleAlreadySet(poolNftId);
        }

        poolInfo.bundleOwnerRole = bundleOwnerRole;
        componentInfo.data = abi.encode(poolInfo);
        instance.updatePoolSetup(poolNftId, componentInfo, KEEP_STATE());

        emit LogPoolServiceBundleOwnerRoleSet(poolNftId, bundleOwnerRole);
    }


    function setFees(
        Fee memory poolFee,
        Fee memory stakingFee,
        Fee memory performanceFee
    )
        external
        virtual
    {
        (IRegistry.ObjectInfo memory registryInfo, IInstance instance) = _getAndVerifyComponentInfoAndInstance(POOL());
        InstanceReader instanceReader = instance.getInstanceReader();
        NftId poolNftId = registryInfo.nftId;

        ISetup.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(poolNftId);
        ISetup.PoolInfo memory poolInfo = abi.decode(componentInfo.data, (ISetup.PoolInfo));

        poolInfo.poolFee = poolFee;
        poolInfo.stakingFee = stakingFee;
        poolInfo.performanceFee = performanceFee;
        componentInfo.data = abi.encode(poolInfo);
        instance.updatePoolSetup(poolNftId, componentInfo, KEEP_STATE());

        // TODO add logging
    }
}
