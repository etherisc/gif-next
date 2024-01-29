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
import {POOL, BUNDLE} from "../../types/ObjectType.sol";
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
        // TODO while PoolService is not deployed in PoolServiceManager constructor
        //      owner is PoolServiceManager deployer
        _initializeService(_registryAddress, owner);

        _registerInterface(type(IService).interfaceId);
        _registerInterface(type(IPoolService).interfaceId);
    }

    function getName() public pure override(Service, IService) returns(string memory name) {
        return NAME;
    }

    function _finalizeComponentRegistration(NftId componentNftId, bytes memory initialObjData, IInstance instance) internal override {
        ISetup.PoolSetupInfo memory initialSetup = abi.decode(
            initialObjData,
            (ISetup.PoolSetupInfo)
        );
        instance.createPoolSetup(componentNftId, initialSetup);
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
        instance.createBundle(bundleNftId, bundleInfo);

        BundleManager bundleManager = instance.getBundleManager();
        bundleManager.add(bundleNftId);
        
        _processStakingByTreasury(
            instanceReader,
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
        (IRegistry.ObjectInfo memory info , IInstance instance) = _getAndVerifyComponentInfoAndInstance(POOL());
        InstanceReader instanceReader = instance.getInstanceReader();
        NftId poolNftId = info.nftId;

        IBundle.BundleInfo memory bundleInfo = instanceReader.getBundleInfo(bundleNftId);
        require(bundleInfo.poolNftId.gtz(), "ERROR:PLS-010:BUNDLE_UNKNOWN");
        require(poolNftId == bundleInfo.poolNftId, "ERROR:PLS-011:BUNDLE_POOL_MISMATCH");

        bundleInfo.fee = fee;

        instance.updateBundle(bundleNftId, bundleInfo, KEEP_STATE());
    }

    function updateBundle(NftId instanceNftId, NftId bundleNftId, IBundle.BundleInfo memory bundleInfo, StateId state) 
        external
        onlyService
    {
        IRegistry.ObjectInfo memory instanceInfo = getRegistry().getObjectInfo(instanceNftId);
        IInstance instance = IInstance(instanceInfo.objectAddress);
        instance.updateBundle(bundleNftId, bundleInfo, state);
    } 

    function lockBundle(NftId bundleNftId) 
        external
    {
        (, IInstance instance) = _getAndVerifyComponentInfoAndInstance(POOL());
        BundleManager bundleManager = instance.getBundleManager();
        bundleManager.lock(bundleNftId);
    }

    function unlockBundle(NftId bundleNftId) 
        external
    {
        (, IInstance instance) = _getAndVerifyComponentInfoAndInstance(POOL());
        BundleManager bundleManager = instance.getBundleManager();
        bundleManager.unlock(bundleNftId);
    }

    function underwritePolicy(IInstance instance,
        NftId policyNftId, 
        NftId bundleNftId, 
        uint256 collateralAmount,
        uint256 netPremiumAmount
    ) 
        external
        onlyService 
    {
        InstanceReader instanceReader = instance.getInstanceReader();
        IBundle.BundleInfo memory bundleInfo = instanceReader.getBundleInfo(bundleNftId);

        // lock collateral
        bundleInfo.lockedAmount += collateralAmount;
        bundleInfo.balanceAmount += netPremiumAmount;

        instance.updateBundle(bundleNftId, bundleInfo, KEEP_STATE());
        
        linkPolicy(instance, policyNftId);
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
            revert BundleManager.ErrorBundleManagerErrorPolicyAlreadyActivated(policyNftId);
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
        if (policyInfo.expiredAt < TimestampLib.blockTimestamp()
            || policyInfo.payoutAmount < policyInfo.sumInsuredAmount)
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
            ISetup.PoolSetupInfo memory poolInfo = instanceReader.getPoolSetupInfo(poolNftId);
            TokenHandler tokenHandler = poolInfo.tokenHandler;
            address bundleOwner = getRegistry().ownerOf(bundleNftId);
            Fee memory stakingFee = poolInfo.stakingFee;

            tokenHandler.transfer(
                bundleOwner,
                poolInfo.wallet,
                stakingAmount
            );


            if (! FeeLib.feeIsZero(stakingFee)) {
                (uint256 stakingFeeAmount, uint256 netAmount) = FeeLib.calculateFee(stakingFee, stakingAmount);
                // TODO: track staking fees in pool's state (issue #177)
            }
        }
    }
}
