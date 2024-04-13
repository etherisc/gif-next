// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Pool} from "./Pool.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {IInstance} from "../instance/IInstance.sol";
import {IBundle} from "../instance/module/IBundle.sol";
import {TokenHandler} from "../instance/module/ITreasury.sol";
import {IComponents} from "../instance/module/IComponents.sol";
import {IPolicy} from "../instance/module/IPolicy.sol";

import {IVersionable} from "../shared/IVersionable.sol";
import {Versionable} from "../shared/Versionable.sol";
import {INftOwnable} from "../shared/INftOwnable.sol";

import {Amount, AmountLib} from "../type/Amount.sol";
import {Fee, FeeLib} from "../type/Fee.sol";
import {NftId, NftIdLib, zeroNftId} from "../type/NftId.sol";
import {ObjectType, POOL, BUNDLE} from "../type/ObjectType.sol";
import {PUBLIC_ROLE, POOL_OWNER_ROLE, POLICY_SERVICE_ROLE, RoleId} from "../type/RoleId.sol";
import {Fee, FeeLib} from "../type/Fee.sol";
import {Version, VersionLib} from "../type/Version.sol";
import {KEEP_STATE, StateId} from "../type/StateId.sol";
import {Seconds} from "../type/Seconds.sol";
import {TimestampLib, zeroTimestamp} from "../type/Timestamp.sol";
import {Version, VersionLib} from "../type/Version.sol";

import {IService} from "../shared/IService.sol";
import {Service} from "../shared/Service.sol";
import {BundleManager} from "../instance/BundleManager.sol";
import {ComponentService} from "../shared/ComponentService.sol";
import {IBundleService} from "./IBundleService.sol";
import {IPoolService} from "./IPoolService.sol";
import {IRegistryService} from "../registry/IRegistryService.sol";
import {InstanceService} from "../instance/InstanceService.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";
import {IComponent} from "../shared/IComponent.sol";
import {IPoolComponent} from "./IPoolComponent.sol";

string constant POOL_SERVICE_NAME = "PoolService";

contract PoolService is 
    ComponentService, 
    IPoolService 
{
    using NftIdLib for NftId;
    using AmountLib for Amount;

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
        initializeService(registryAddress, address(0), owner);

        _bundleService = IBundleService(getRegistry().getServiceAddress(BUNDLE(), getVersion().toMajorPart()));
/*
        // configure in access manager;
        // call it
        // TODO but in this case service should know access manager -> better to do role stuff outside of service???
        accessManager.
        policyService.poolService.lockCollateral();
        policyService.poolService.releaseCollateral();
        // !!! or just save addresses of calling services from config????
        //     and use common modifier -> on,yServiceAddress(_savedServiceAddresFromConfig/Registry)
        //     get addresses from registry by domain -> implies registration order -> unidirected graph
        // for example _> bundle service should already be registered???
        _policyService = IPolicyService(getRegistry().getServiceAddress(POLICY(), getVersion().toMajorPart()));
*/
        registerInterface(type(IPoolService).interfaceId);
    }

    function getDomain() public pure override returns(ObjectType) {
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
        instance.getInstanceStore().createPoolSetup(poolNftId, componentInfo);

        bytes4[][] memory selectors = new bytes4[][](2);
        selectors[0] = new bytes4[](1);
        selectors[1] = new bytes4[](1);

        selectors[0][0] = IPoolComponent.setFees.selector;
        selectors[1][0] = IPoolComponent.verifyApplication.selector;

        RoleId[] memory roles = new RoleId[](2);
        roles[0] = POOL_OWNER_ROLE();
        roles[1] = POLICY_SERVICE_ROLE();

        getInstanceService().createGifTarget(
            instanceNftId, 
            poolAddress, 
            pool.getName(), 
            selectors, 
            roles);
    }


    function setMaxCapitalAmount(Amount maxCapitalAmount)
        external
        virtual
    {
        (NftId poolNftId,, IInstance instance) = _getAndVerifyCallingComponentAndInstance(POOL());
        InstanceReader instanceReader = instance.getInstanceReader();

        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(poolNftId);
        IComponents.PoolInfo memory poolInfo = abi.decode(componentInfo.data, (IComponents.PoolInfo));
        Amount previousMaxCapitalAmount = poolInfo.maxCapitalAmount;

        poolInfo.maxCapitalAmount = maxCapitalAmount;
        componentInfo.data = abi.encode(poolInfo);
        instance.getInstanceStore().updatePoolSetup(poolNftId, componentInfo, KEEP_STATE());

        emit LogPoolServiceMaxCapitalAmountUpdated(poolNftId, previousMaxCapitalAmount, maxCapitalAmount);
    }

    function setBundleOwnerRole(RoleId bundleOwnerRole)
        external
        virtual
    {
        (NftId poolNftId,, IInstance instance) = _getAndVerifyCallingComponentAndInstance(POOL());
        InstanceReader instanceReader = instance.getInstanceReader();

        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(poolNftId);
        IComponents.PoolInfo memory poolInfo = abi.decode(componentInfo.data, (IComponents.PoolInfo));

        // bundle owner role may only be set once per pool
        if(poolInfo.bundleOwnerRole != PUBLIC_ROLE()) {
            revert ErrorPoolServiceBundleOwnerRoleAlreadySet(poolNftId);
        }

        poolInfo.bundleOwnerRole = bundleOwnerRole;
        componentInfo.data = abi.encode(poolInfo);
        instance.getInstanceStore().updatePoolSetup(poolNftId, componentInfo, KEEP_STATE());

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
        (NftId poolNftId,, IInstance instance) = _getAndVerifyCallingComponentAndInstance(POOL());
        InstanceReader instanceReader = instance.getInstanceReader();

        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(poolNftId);
        IComponents.PoolInfo memory poolInfo = abi.decode(componentInfo.data, (IComponents.PoolInfo));

        poolInfo.poolFee = poolFee;
        poolInfo.stakingFee = stakingFee;
        poolInfo.performanceFee = performanceFee;
        componentInfo.data = abi.encode(poolInfo);
        instance.getInstanceStore().updatePoolSetup(poolNftId, componentInfo, KEEP_STATE());

        // TODO add logging
    }

    function createBundle(
        address owner, // initial bundle owner
        Fee memory fee, // fees deducted from premium that go to bundle owner
        Amount stakingAmount, // staking amount - staking fees result in initial bundle capital
        Seconds lifetime, // initial duration for which new policies are covered
        bytes calldata filter // optional use case specific criteria that define if a policy may be covered by this bundle
    )
        external 
        virtual
        returns(NftId bundleNftId)
    {
        (NftId poolNftId,, IInstance instance) = _getAndVerifyCallingComponentAndInstance(POOL());
        InstanceReader instanceReader = instance.getInstanceReader();

        // pool fee book keeping
        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(poolNftId);
        Amount stakingNetAmount = _processStakingFees(componentInfo, stakingAmount);

        bundleNftId = _bundleService.create(
            instance,
            poolNftId,
            owner,
            fee,
            stakingNetAmount,
            lifetime,
            filter);

        // collect tokens from bundle owner
        _transferStakingAmount(componentInfo, owner, stakingAmount);

        emit LogPoolServiceBundleCreated(instance.getNftId(), poolNftId, bundleNftId);
    }


    function closeBundle(NftId bundleNftId)
        external
        virtual
    {
        (NftId poolNftId,, IInstance instance) = _getAndVerifyCallingComponentAndInstance(POOL());

        // TODO book keeping for pool collateral released outside of retention level

        // releasing collateral in bundle
        _bundleService.close(instance, bundleNftId);

        // TODO get performance fee for pool, transfer of remaining funds + bundle fees to bundle owner

        emit LogPoolServiceBundleClosed(instance.getNftId(), poolNftId, bundleNftId);
    }

    function processSale(
        NftId bundleNftId, 
        IPolicy.Premium memory premium, 
        Amount actualAmountTransferred
    ) 
        external
        virtual
        restricted
    {
        IRegistry registry = getRegistry();
        IRegistry.ObjectInfo memory bundleObjectInfo = registry.getObjectInfo(bundleNftId);
        IRegistry.ObjectInfo memory poolObjectInfo = registry.getObjectInfo(bundleObjectInfo.parentNftId);
        IRegistry.ObjectInfo memory instanceObjectInfo = registry.getObjectInfo(poolObjectInfo.parentNftId);
        IInstance instance = IInstance(instanceObjectInfo.objectAddress);

        Amount poolFeeAmount = AmountLib.toAmount(premium.poolFeeFixAmount + premium.poolFeeVarAmount);
        Amount bundleFeeAmount = AmountLib.toAmount(premium.bundleFeeFixAmount + premium.bundleFeeVarAmount);
        Amount expectedTransferAmount = AmountLib.toAmount(premium.netPremiumAmount) + poolFeeAmount + bundleFeeAmount;
        if (!(actualAmountTransferred == expectedTransferAmount)) {
            revert ErrorPoolServiceInvalidTransferAmount(expectedTransferAmount, actualAmountTransferred);
        }
        
        // update pool fee balance
        if (poolFeeAmount.gtz()) {
            IComponents.ComponentInfo memory poolComponentInfo = instance.getInstanceReader().getComponentInfo(poolObjectInfo.nftId);
            poolComponentInfo.feeAmount = poolComponentInfo.feeAmount.add(poolFeeAmount);
            instance.getInstanceStore().updatePoolSetup(poolObjectInfo.nftId, poolComponentInfo, KEEP_STATE());
        }

        if (bundleFeeAmount.gtz()) {
            _bundleService.updateBundleFees(instance, bundleNftId, bundleFeeAmount);
        }
    }

    function lockCollateral(
        IInstance instance, 
        NftId productNftId,
        NftId applicationNftId,
        IPolicy.PolicyInfo memory applicationInfo,
        Amount premiumAmount // premium amount after product and distribution fees
    )
        external
        virtual
        restricted
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
        Amount collateralAmount = applicationInfo.sumInsuredAmount;

        // TODO add correct net premium calculation (pool fee might be > 0)
        Amount premiumAfterPoolFeeAmount = premiumAmount;

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


    function reduceCollateral(
        IInstance instance, 
        NftId policyNftId, 
        IPolicy.PolicyInfo memory policyInfo,
        Amount payoutAmount
    )
        external
        virtual
        restricted
    {
        _bundleService.releaseCollateral(
            instance, 
            policyNftId, 
            policyInfo.bundleNftId, 
            payoutAmount);
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
        restricted
    {
        _bundleService.releaseCollateral(
            instance, 
            policyNftId, 
            policyInfo.bundleNftId, 
            policyInfo.sumInsuredAmount - policyInfo.claimAmount);

        _bundleService.unlinkPolicy(
            instance, 
            policyNftId);
    }


    function _processStakingFees(
        IComponents.ComponentInfo memory componentInfo, 
        Amount stakingAmount
    )
        internal
        returns (Amount stakingNetAmount)
    {
        stakingNetAmount = stakingAmount;

        // check if any staking fees apply
        Fee memory stakingFee = abi.decode(componentInfo.data, (IComponents.PoolInfo)).stakingFee;
        if (FeeLib.gtz(stakingFee)) {
            (Amount feeAmount, Amount netAmount) = FeeLib.calculateFee(stakingFee, stakingAmount);
            stakingNetAmount = netAmount;

            // TODO update fee balance for pool
        }
    }


    // TODO create (I)TreasuryService that deals with all gif related token transfers
    /// @dev transfers the specified amount from the bundle owner to the pool's wallet
    function _transferStakingAmount(
        IComponents.ComponentInfo memory componentInfo,
        address bundleOwner,
        Amount stakingAmount
    )
        internal
    {
        TokenHandler tokenHandler = componentInfo.tokenHandler;
        address poolWallet = componentInfo.wallet;

        if(stakingAmount.gtz()) {
            tokenHandler.transfer(
                bundleOwner,
                poolWallet,
                stakingAmount
            );
        }
    }

}