// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Pool} from "../../components/Pool.sol";
import {IRegistry} from "../../registry/IRegistry.sol";
import {IInstance} from "../../instance/IInstance.sol";
import {IBundle} from "../../instance/module/IBundle.sol";
import {TokenHandler} from "../../instance/module/ITreasury.sol";
import {IComponents} from "../module/IComponents.sol";
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
import {IBundleService} from "./IBundleService.sol";
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

    IBundleService internal _bundleService;

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

        _bundleService = IBundleService(getRegistry().getServiceAddress(BUNDLE(), getMajorVersion()));

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
        IComponents.ComponentInfo memory componentInfo = pool.getComponentInfo();
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
        (NftId poolNftId, IRegistry.ObjectInfo memory registryInfo, IInstance instance) = _getAndVerifyComponentInfoAndInstance(POOL());
        InstanceReader instanceReader = instance.getInstanceReader();

        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(poolNftId);
        IComponents.PoolInfo memory poolInfo = abi.decode(componentInfo.data, (IComponents.PoolInfo));
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
        (NftId poolNftId, IRegistry.ObjectInfo memory registryInfo, IInstance instance) = _getAndVerifyComponentInfoAndInstance(POOL());
        InstanceReader instanceReader = instance.getInstanceReader();

        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(poolNftId);
        IComponents.PoolInfo memory poolInfo = abi.decode(componentInfo.data, (IComponents.PoolInfo));

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
        (NftId poolNftId, IRegistry.ObjectInfo memory registryInfo, IInstance instance) = _getAndVerifyComponentInfoAndInstance(POOL());
        InstanceReader instanceReader = instance.getInstanceReader();

        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(poolNftId);
        IComponents.PoolInfo memory poolInfo = abi.decode(componentInfo.data, (IComponents.PoolInfo));

        poolInfo.poolFee = poolFee;
        poolInfo.stakingFee = stakingFee;
        poolInfo.performanceFee = performanceFee;
        componentInfo.data = abi.encode(poolInfo);
        instance.updatePoolSetup(poolNftId, componentInfo, KEEP_STATE());

        // TODO add logging
    }


    function lockCollateral(
        IInstance instance, 
        NftId productNftId,
        NftId applicationNftId,
        IPolicy.PolicyInfo memory applicationInfo,
        uint256 premiumAmount // premium amount after product and distribution fees
    )
        external
        virtual
        // TODO add restricted and granting for policy service
    {
        InstanceReader instanceReader = instance.getInstanceReader();
        NftId poolNftId = instanceReader.getProductSetupInfo(productNftId).poolNftId;
        NftId bundleNftId = applicationInfo.bundleNftId;

        // TODO move this check to application creation and don't repeat this here
        // ensure that pool for bundle from application matches with pool for product of application
        IBundle.BundleInfo memory bundleInfo = instanceReader.getBundleInfo(bundleNftId);
        if(bundleInfo.poolNftId != poolNftId) {
            revert ErrorPoolServiceBundlePoolMismatch(bundleInfo.poolNftId, poolNftId);
        }

        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(poolNftId);
        IComponents.PoolInfo memory poolInfo = abi.decode(componentInfo.data, (IComponents.PoolInfo));

        // TODO add correct required collateral calculation (collateralization level mibht be != 1, retention level might be < 1)
        uint256 collateralAmount = applicationInfo.sumInsuredAmount;

        // TODO add correct net premium calculation (pool fee might be > 0)
        uint256 premiumAfterPoolFeeAmount = premiumAmount;

        // lock collateral amount from involvedd bundle
        _bundleService.lockCollateral(
            instance,
            applicationNftId, 
            bundleNftId,
            collateralAmount,
            premiumAfterPoolFeeAmount);

        // also verify/confirm application by pool if necessary
        if(poolInfo.isVerifyingApplications) {
            address poolAddress = getRegistry().getObjectInfo(poolNftId).objectAddress;
            IPoolComponent(poolAddress).verifyApplication(
                applicationNftId, 
                applicationInfo.applicationData, 
                bundleNftId,
                bundleInfo.filter,
                collateralAmount);
        }
    }


    /// @dev releases the remaining collateral linked to the specified policy
    /// may only be called by the policy service for unlocked pool components
    function releaseCollateral(
        IInstance instance, 
        NftId policyNftId, 
        IPolicy.PolicyInfo memory policyInfo
    )
        external
        virtual
        // TODO add restricted and granting for policy service
    {
        // release collateral from involved bundle
        _bundleService.releaseCollateral(
            instance, 
            policyNftId, 
            policyInfo.bundleNftId, 
            policyInfo.sumInsuredAmount);
    }

}
