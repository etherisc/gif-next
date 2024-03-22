// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IBundle} from "../../instance/module/IBundle.sol";
import {IComponents} from "../module/IComponents.sol";
import {IRegistry} from "../../registry/IRegistry.sol";
import {IInstance} from "../../instance/IInstance.sol";
import {TokenHandler} from "../../instance/module/ITreasury.sol";
import {ISetup} from "../module/ISetup.sol";
import {IPolicy} from "../module/IPolicy.sol";

import {IVersionable} from "../../shared/IVersionable.sol";
import {INftOwnable} from "../../shared/INftOwnable.sol";
import {NftId, NftIdLib, zeroNftId} from "../../types/NftId.sol";
import {ObjectType, POOL, BUNDLE} from "../../types/ObjectType.sol";
import {POOL_OWNER_ROLE, RoleId} from "../../types/RoleId.sol";
import {Pool} from "../../components/Pool.sol";

import {Fee, FeeLib} from "../../types/Fee.sol";
import {StateId, ACTIVE, PAUSED, CLOSED, KEEP_STATE} from "../../types/StateId.sol";
import {Seconds} from "../../types/Seconds.sol";
import {TimestampLib, zeroTimestamp} from "../../types/Timestamp.sol";
import {Version, VersionLib} from "../../types/Version.sol";
import {Versionable} from "../../shared/Versionable.sol";

import {IService} from "../../shared/IService.sol";
import {Service} from "../../shared/Service.sol";
import {BundleManager} from "../BundleManager.sol";
import {ComponentService} from "../base/ComponentService.sol";
import {IBundleService} from "./IBundleService.sol";
import {IRegistryService} from "../../registry/IRegistryService.sol";
import {InstanceService} from "../InstanceService.sol";
import {InstanceReader} from "../InstanceReader.sol";

string constant BUNDLE_SERVICE_NAME = "BundleService";

contract BundleService is 
    ComponentService, 
    IBundleService 
{
    using NftIdLib for NftId;

    string public constant NAME = "BundleService";

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
        registerInterface(type(IBundleService).interfaceId);
    }

    function getDomain() public pure override(Service, IService) returns(ObjectType) {
        return BUNDLE();
    }

    function create(
        address owner, 
        Fee memory fee, 
        uint256 stakingAmount, 
        Seconds lifetime, 
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
            fee,
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
        instance.getInstanceStore().createBundle(bundleNftId, bundleInfo);

        BundleManager bundleManager = instance.getBundleManager();
        bundleManager.add(bundleNftId);
        
        _processStakingByTreasury(
            instanceReader,
            poolNftId,
            bundleNftId,
            stakingAmount);

        // TODO add logging
    }

    function setFee(
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

        instance.getInstanceStore().updateBundle(bundleNftId, bundleInfo, KEEP_STATE());
    }


    function lockCollateral(
        IInstance instance,
        NftId policyNftId, 
        NftId bundleNftId, 
        uint256 collateralAmount,
        uint256 netPremiumAmount
    ) 
        external
        onlyService
        returns (
            IBundle.BundleInfo memory bundleInfo
        )
    {
        InstanceReader instanceReader = instance.getInstanceReader();
        bundleInfo = instanceReader.getBundleInfo(bundleNftId);

        // TODO add validation

        // lock collateral
        bundleInfo.lockedAmount += collateralAmount;
        bundleInfo.balanceAmount += netPremiumAmount;

        instance.getInstanceStore().updateBundle(bundleNftId, bundleInfo, KEEP_STATE());
        
        linkPolicy(instance, policyNftId);
    }


    function lock(NftId bundleNftId) 
        external
        virtual
    {
        (, IInstance instance) = _getAndVerifyComponentInfoAndInstance(POOL());

        // udpate bundle state
        instance.getInstanceStore().updateBundleState(bundleNftId, PAUSED());

        // update set of active bundles
        BundleManager bundleManager = instance.getBundleManager();
        bundleManager.lock(bundleNftId);

        emit LogBundleServiceBundleLocked(bundleNftId);
    }


    function unlock(NftId bundleNftId) 
        external
        virtual
    {
        (, IInstance instance) = _getAndVerifyComponentInfoAndInstance(POOL());

        // udpate bundle state
        instance.getInstanceStore().updateBundleState(bundleNftId, ACTIVE());

        // update set of active bundles
        BundleManager bundleManager = instance.getBundleManager();
        bundleManager.unlock(bundleNftId);

        emit LogBundleServiceBundleActivated(bundleNftId);
    }


    function close(NftId bundleNftId) 
        external
        virtual
    {
        (, IInstance instance) = _getAndVerifyComponentInfoAndInstance(POOL());

        // udpate bundle state
        instance.getInstanceStore().updateBundleState(bundleNftId, CLOSED());

        // ensure no open policies attached to bundle
        BundleManager bundleManager = instance.getBundleManager();
        uint256 openPolicies = bundleManager.activePolicies(bundleNftId);
        if(openPolicies > 0) {
            revert ErrorBundleServiceBundleWithOpenPolicies(bundleNftId, openPolicies);
        }

        // update set of active bundles
        bundleManager.lock(bundleNftId);

        emit LogBundleServiceBundleClosed(bundleNftId);
    }


    function increaseBalance(IInstance instance,
        NftId bundleNftId, 
        uint256 amount
    ) 
        external
        onlyService 
    {
        InstanceReader instanceReader = instance.getInstanceReader();
        IBundle.BundleInfo memory bundleInfo = instanceReader.getBundleInfo(bundleNftId);

        bundleInfo.balanceAmount += amount;

        instance.getInstanceStore().updateBundle(bundleNftId, bundleInfo, KEEP_STATE());
    }

    function closePolicy(IInstance instance,
        NftId policyNftId, 
        NftId bundleNftId, 
        uint256 collateralAmount
    ) 
        external
        onlyService 
    {
        InstanceReader instanceReader = instance.getInstanceReader();
        IBundle.BundleInfo memory bundleInfo = instanceReader.getBundleInfo(bundleNftId);

        // lock collateral
        bundleInfo.lockedAmount -= collateralAmount;

        instance.getInstanceStore().updateBundle(bundleNftId, bundleInfo, KEEP_STATE());
        
        unlinkPolicy(instance, policyNftId);
    }

    /// @dev links policy to bundle
    function linkPolicy(IInstance instance, NftId policyNftId) 
        internal
        onlyService 
    {
        InstanceReader instanceReader = instance.getInstanceReader();
        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);

        // ensure policy has not yet been activated
        if (policyInfo.activatedAt.gtz()) {
            revert BundleManager.ErrorBundleManagerPolicyAlreadyActivated(policyNftId);
        }

        BundleManager bundleManager = instance.getBundleManager();
        bundleManager.linkPolicy(policyNftId);
    }

        /// @dev unlinks policy from bundle
    function unlinkPolicy(IInstance instance, NftId policyNftId) 
        internal
        onlyService 
    {
        InstanceReader instanceReader = instance.getInstanceReader();
        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);

        // ensure policy has no open claims
        if (policyInfo.openClaimsCount > 0) {
            revert BundleManager.ErrorBundleManagerPolicyWithOpenClaims(
                policyNftId, 
                policyInfo.openClaimsCount);
        }

        // ensure policy is closeable
        if ( TimestampLib.blockTimestamp() < policyInfo.expiredAt
            && policyInfo.payoutAmount < policyInfo.sumInsuredAmount)
        {
            revert BundleManager.ErrorBundleManagerPolicyNotCloseable(policyNftId);
        }
        
        BundleManager bundleManager = instance.getBundleManager();
        bundleManager.unlinkPolicy(policyNftId);
    }

    function _processStakingByTreasury(
        InstanceReader instanceReader,
        NftId poolNftId,
        NftId bundleNftId,
        uint256 stakingAmount
    )
        internal
    {
        // process token transfer(s)
        if(stakingAmount > 0) {
            IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(poolNftId);
            IComponents.PoolInfo memory poolInfo = abi.decode(
                componentInfo.data, (IComponents.PoolInfo));

            TokenHandler tokenHandler = componentInfo.tokenHandler;
            address bundleOwner = getRegistry().ownerOf(bundleNftId);
            Fee memory stakingFee = poolInfo.stakingFee;

            tokenHandler.transfer(
                bundleOwner,
                componentInfo.wallet,
                stakingAmount
            );

            if (! FeeLib.feeIsZero(stakingFee)) {
                (uint256 stakingFeeAmount, uint256 netAmount) = FeeLib.calculateFee(stakingFee, stakingAmount);
                // TODO: track staking fees in pool's state (issue #177)
            }
        }
    }
}
