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

import {Amount, AmountLib} from "../../types/Amount.sol";
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
        initializeService(registryAddress, address(0), owner);
        registerInterface(type(IBundleService).interfaceId);
    }

    function getDomain() public pure override returns(ObjectType) {
        return BUNDLE();
    }

    // TODO staking/unstaking as well as collateralize need to go to pool service
    // it will also be the pool service that is updating the pool info data
    // collateralize -> potentially accumulate pool fees
    // collateralize: additional reason to move to pool, pool might has retential level < 1 ...
    // staking -> potentially accumulate staking fees
    // unstaking -> potentially accumulate performance fees
    function _updatePoolWithStakes(
        IInstance instance,
        NftId poolNftId,
        uint256 stakingAmount
    )
        internal
        returns (
            TokenHandler tokenHandler,
            address wallet,
            uint256 netStakingAmount
        )
    {
        if(stakingAmount > 0) {
            InstanceReader instanceReader = instance.getInstanceReader();
            IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(poolNftId);

            tokenHandler = componentInfo.tokenHandler;
            wallet = componentInfo.wallet;

            IComponents.PoolInfo memory poolInfo = abi.decode(componentInfo.data, (IComponents.PoolInfo));
            uint256 poolFeeAmount;

            // calculate pool fee and net staking amount
            (poolFeeAmount, netStakingAmount) = FeeLib.calculateFee(poolInfo.stakingFee, stakingAmount);

            // update pool balance and fee amount
            poolInfo.balanceAmount += netStakingAmount;

            if(poolFeeAmount > 0) {
                poolInfo.feeAmount += poolFeeAmount;
            }

            // save updated pool info
            componentInfo.data = abi.encode(poolInfo);
            instance.getInstanceStore().updatePoolSetup(poolNftId, componentInfo, KEEP_STATE());
        }
    }


    function create(
        IInstance instance,
        NftId poolNftId,
        address owner, 
        Fee memory fee, 
        Amount stakingAmount, 
        Seconds lifetime, 
        bytes calldata filter
    )
        external
        override
        // TODO add restricted and add authz for pool service
        returns(NftId bundleNftId)
    {
        InstanceReader instanceReader = instance.getInstanceReader();

        // create initial bundle info
        IBundle.BundleInfo  memory bundleInfo = IBundle.BundleInfo(
            poolNftId,
            fee,
            filter,
            stakingAmount,
            AmountLib.zero(),
            AmountLib.zero(),
            lifetime,
            TimestampLib.blockTimestamp().addSeconds(lifetime),
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
                "" // bundle data to be stored in registry
            )
        );

        // create bundle info in instance
        instance.getInstanceStore().createBundle(bundleNftId, bundleInfo);

        // put bundle under bundle managemet
        BundleManager bundleManager = instance.getBundleManager();
        bundleManager.add(bundleNftId);
        
        // transfer full staking amount to pool wallet
        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(poolNftId);
        componentInfo.tokenHandler.transfer(
            owner,
            componentInfo.wallet,
            stakingAmount.toInt()
        );

        // TODO add logging
    }

    function setFee(
        NftId bundleNftId,
        Fee memory fee
    )
        external
        override
    {
        (NftId poolNftId,, IInstance instance) = _getAndVerifyCallingComponentAndInstance(POOL());
        InstanceReader instanceReader = instance.getInstanceReader();
        IBundle.BundleInfo memory bundleInfo = instanceReader.getBundleInfo(bundleNftId);
        if(bundleInfo.poolNftId.eqz()) {
            revert ErrorBundleServiceBundleUnknown(bundleNftId);
        }

        if(bundleInfo.poolNftId != poolNftId) {
            revert ErrorBundleServiceBundlePoolMismatch(bundleNftId, bundleInfo.poolNftId, poolNftId);
        }

        bundleInfo.fee = fee;
        instance.getInstanceStore().updateBundle(bundleNftId, bundleInfo, KEEP_STATE());
    }


    // the bundle MUST be unlocked (active) for linking (underwriting) and registered with this instance
    function lockCollateral(
        IInstance instance,
        NftId policyNftId, 
        NftId bundleNftId, 
        uint256 collateralAmount, // required amount to collateralize policy
        uint256 premiumAmount // premium part that reaches bundle for this policy
    ) 
        external
        onlyService // TODO replace with restricted + appropriate granting
    {
        InstanceReader instanceReader = instance.getInstanceReader();
        StateId bundleState = instanceReader.getMetadata(bundleNftId.toKey32(BUNDLE())).state;
        IBundle.BundleInfo memory bundleInfo = instanceReader.getBundleInfo(bundleNftId);

        // ensure bundle is active and not yet expired
        if(bundleState != ACTIVE() || bundleInfo.expiredAt < TimestampLib.blockTimestamp()) {
            revert ErrorBundleServiceBundleNotOpen(bundleNftId, bundleState, bundleInfo.expiredAt);
        }

        // ensure bundle capacity is sufficent to collateralize policy
        uint capacity = bundleInfo.capitalAmount.toInt() + premiumAmount - bundleInfo.lockedAmount.toInt();
        if(capacity < collateralAmount) {
            revert ErrorBundleServiceCapacityInsufficient(bundleNftId, capacity, collateralAmount);
        }

        // TODO add more validation
        
        // updated locked amount
        bundleInfo.lockedAmount = AmountLib.toAmount(bundleInfo.lockedAmount.toInt() + collateralAmount);

        // update capital and fees when premiums are involved
        _updateBundleWithPremium(instance, bundleNftId, bundleInfo, premiumAmount);
        
        // link policy to bundle in bundle manger
        _linkPolicy(instance, policyNftId);
    }


    function _updateBundleWithPremium(
        IInstance instance,
        NftId bundleNftId,
        IBundle.BundleInfo memory bundleInfo,
        uint256 premiumAmount
    )
        internal
    {
        // update bundle capital and fee amounts
        if(premiumAmount > 0) {
            // calculate fees and net premium amounts
            (
                , 
                uint256 netPremiumAmount
            ) = FeeLib.calculateFee(bundleInfo.fee, premiumAmount);

            // update bundle info with additional capital
            bundleInfo.capitalAmount = AmountLib.toAmount(bundleInfo.capitalAmount.toInt() + netPremiumAmount);
        }

        // save updated bundle info
        instance.getInstanceStore().updateBundle(bundleNftId, bundleInfo, KEEP_STATE());
    }

    function updateBundleFees(
        IInstance instance,
        NftId bundleNftId,
        Amount feeAmount
    )
        external
    {
        IBundle.BundleInfo memory bundleInfo = instance.getInstanceReader().getBundleInfo(bundleNftId);
        bundleInfo.feeAmount = bundleInfo.feeAmount.add(feeAmount);
        instance.getInstanceStore().updateBundle(bundleNftId, bundleInfo, KEEP_STATE());
    }

    function lock(NftId bundleNftId) 
        external
        virtual
    {
        (,, IInstance instance) = _getAndVerifyCallingComponentAndInstance(POOL());

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
        (,, IInstance instance) = _getAndVerifyCallingComponentAndInstance(POOL());

        // udpate bundle state
        instance.getInstanceStore().updateBundleState(bundleNftId, ACTIVE());

        // update set of active bundles
        BundleManager bundleManager = instance.getBundleManager();
        bundleManager.unlock(bundleNftId);

        emit LogBundleServiceBundleActivated(bundleNftId);
    }


    function close(
        IInstance instance,
        NftId bundleNftId
    ) 
        external
        virtual
        // TODO add restricted and autz for pool service
    {
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
    }


    function increaseBalance(
        IInstance instance,
        NftId bundleNftId, 
        uint256 premiumAmount
    ) 
        external
        onlyService 
    {
        InstanceReader instanceReader = instance.getInstanceReader();
        IBundle.BundleInfo memory bundleInfo = instanceReader.getBundleInfo(bundleNftId);

        // update capital and fees when premiums are involved
        _updateBundleWithPremium(instance, bundleNftId, bundleInfo, premiumAmount);

        // TODO add logging (?)
    }

    function releaseCollateral(IInstance instance,
        NftId policyNftId, 
        NftId bundleNftId, 
        uint256 collateralAmount
    ) 
        external
        onlyService 
    {
        InstanceReader instanceReader = instance.getInstanceReader();
        IBundle.BundleInfo memory bundleInfo = instanceReader.getBundleInfo(bundleNftId);

        // reduce locked amount by released collateral amount
        bundleInfo.lockedAmount = AmountLib.toAmount(bundleInfo.lockedAmount.toInt() - collateralAmount);

        instance.getInstanceStore().updateBundle(bundleNftId, bundleInfo, KEEP_STATE());
        
        _unlinkPolicy(instance, policyNftId);
    }

    /// @dev links policy to bundle
    function _linkPolicy(IInstance instance, NftId policyNftId) 
        internal
    {
        InstanceReader instanceReader = instance.getInstanceReader();
        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);

        // ensure policy has not yet been activated in a previous tx already
        if (policyInfo.activatedAt.gtz() && policyInfo.activatedAt < TimestampLib.blockTimestamp()) {
            revert BundleManager.ErrorBundleManagerPolicyAlreadyActivated(policyNftId);
        }
        
        BundleManager bundleManager = instance.getBundleManager();
        bundleManager.linkPolicy(policyNftId);
    }

        /// @dev unlinks policy from bundle
    function _unlinkPolicy(IInstance instance, NftId policyNftId) 
        internal
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
            && policyInfo.payoutAmount.toInt() < policyInfo.sumInsuredAmount)
        {
            revert BundleManager.ErrorBundleManagerPolicyNotCloseable(policyNftId);
        }
        
        BundleManager bundleManager = instance.getBundleManager();
        bundleManager.unlinkPolicy(policyNftId);
    }

    // TODO move this to pool service
    function _processStakingByTreasury(
        InstanceReader instanceReader,
        NftId poolNftId,
        NftId bundleNftId,
        Amount stakingAmount
    )
        internal
    {
        // process token transfer(s)
        if(stakingAmount.gtz()) {
            IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(poolNftId);
            IComponents.PoolInfo memory poolInfo = abi.decode(componentInfo.data, (IComponents.PoolInfo));

            TokenHandler tokenHandler = componentInfo.tokenHandler;
            address bundleOwner = getRegistry().ownerOf(bundleNftId);
            Fee memory stakingFee = poolInfo.stakingFee;

            // pool fee and bundle capital book keeping
            if (FeeLib.gtz(stakingFee)) {
                (uint256 stakingFeeAmount, uint256 netAmount) = FeeLib.calculateFee(stakingFee, stakingAmount.toInt());


                // TODO: track staking fees in pool's state (issue #177)
            }

            // transfer full staking amount to pool wallet
            tokenHandler.transfer(
                bundleOwner,
                componentInfo.wallet,
                stakingAmount.toInt()
            );
        }
    }
}
