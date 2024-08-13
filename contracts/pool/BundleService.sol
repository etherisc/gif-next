// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IBundle} from "../instance/module/IBundle.sol";
import {IBundleService} from "./IBundleService.sol";
import {IComponents} from "../instance/module/IComponents.sol";
import {IComponentService} from "../shared/IComponentService.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {IRegistryService} from "../registry/IRegistryService.sol";
import {IInstance} from "../instance/IInstance.sol";
import {InstanceStore} from "../instance/InstanceStore.sol";
import {IPolicy} from "../instance/module/IPolicy.sol";

import {Amount, AmountLib} from "../type/Amount.sol";
import {BundleSet} from "../instance/BundleSet.sol";
import {ComponentVerifyingService} from "../shared/ComponentVerifyingService.sol";
import {Fee} from "../type/Fee.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";
import {NftId, NftIdLib} from "../type/NftId.sol";
import {ObjectType, COMPONENT, POOL, BUNDLE, REGISTRY} from "../type/ObjectType.sol";
import {StateId, ACTIVE, PAUSED, CLOSED, KEEP_STATE} from "../type/StateId.sol";
import {Seconds} from "../type/Seconds.sol";
import {Timestamp, TimestampLib, zeroTimestamp} from "../type/Timestamp.sol";

string constant BUNDLE_SERVICE_NAME = "BundleService";

contract BundleService is 
    ComponentVerifyingService, 
    IBundleService 
{
    
    string public constant NAME = "BundleService";

    address private _registryAddress;
    IRegistryService private _registryService;
    IComponentService private _componentService;

    function _initialize(
        address owner, 
        bytes memory data
    )
        internal
        virtual override
        initializer()
    {
        (
            address registryAddress,
            address authority
        ) = abi.decode(data, (address, address));

        _initializeService(registryAddress, authority, owner);

        _registryService = IRegistryService(_getServiceAddress(REGISTRY()));
        _componentService = IComponentService(_getServiceAddress(COMPONENT()));

        _registerInterface(type(IBundleService).interfaceId);
    }


    function setFee(
        NftId bundleNftId,
        Fee memory fee
    )
        external
        virtual
    {
        (NftId poolNftId,, IInstance instance) = _getAndVerifyActiveComponent(POOL());
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


    function create(
        IInstance instance,
        NftId poolNftId,
        address owner, 
        Fee memory bundleFee, 
        Amount stakingAmount, 
        Seconds lifetime, 
        bytes calldata filter
    )
        external
        override
        restricted
        returns(NftId bundleNftId)
    {
        // register bundle with registry
        bundleNftId = _registryService.registerBundle(
            IRegistry.ObjectInfo(
                NftIdLib.zero(), 
                poolNftId,
                BUNDLE(),
                false, // intercepting property for bundles is defined on pool
                address(0),
                owner,
                "" // bundle data to be stored in registry
            )
        );

        // create bundle info in instance
        InstanceStore instanceStore = instance.getInstanceStore();
        instanceStore.createBundle(
            bundleNftId, 
            IBundle.BundleInfo({
                poolNftId: poolNftId,
                fee: bundleFee,
                filter: filter,
                activatedAt: TimestampLib.blockTimestamp(),
                expiredAt: TimestampLib.blockTimestamp().addSeconds(lifetime),
                closedAt: zeroTimestamp()
            })
        );

        if (stakingAmount.gtz()) {
            // bundle book keeping
            _componentService.increaseBundleBalance(
                instanceStore, 
                bundleNftId, 
                stakingAmount, 
                AmountLib.zero()); // fee amount
        }

        // put bundle under bundle managemet
        BundleSet bundleManager = instance.getBundleSet();
        bundleManager.add(bundleNftId);
        // TODO add logging
    }


    // the bundle MUST be unlocked (active) for linking (underwriting) and registered with this instance
    function lockCollateral(
        IInstance instance,
        NftId policyNftId, 
        NftId bundleNftId, 
        Amount collateralAmount // required local amount to collateralize policy
    ) 
        external
        virtual
        restricted()
    {
        InstanceReader instanceReader = instance.getInstanceReader();
        StateId bundleState = instance.getInstanceReader().getBundleState(bundleNftId);
        IBundle.BundleInfo memory bundleInfo = instanceReader.getBundleInfo(bundleNftId);

        // ensure bundle is active and not yet expired
        if(bundleState != ACTIVE() || bundleInfo.expiredAt < TimestampLib.blockTimestamp()) {
            revert ErrorBundleServiceBundleNotOpen(bundleNftId, bundleState, bundleInfo.expiredAt);
        }

        // ensure bundle capacity is sufficent to collateralize policy
        InstanceStore instanceStore = instance.getInstanceStore();
        (
            Amount balanceAmount,
            Amount lockedAmount,
            Amount feeAmount
        ) = instanceStore.getAmounts(bundleNftId);

        Amount capacity = balanceAmount - (lockedAmount + feeAmount);
        if(capacity < collateralAmount) {
            revert ErrorBundleServiceCapacityInsufficient(bundleNftId, capacity, collateralAmount);
        }

        // updated locked amount
        instanceStore.increaseLocked(bundleNftId, collateralAmount);
    }


    function lock(NftId bundleNftId) 
        external
        virtual
    {
        (,, IInstance instance) = _getAndVerifyActiveComponent(POOL());

        // udpate bundle state
        instance.getInstanceStore().updateBundleState(bundleNftId, PAUSED());

        // update set of active bundles
        BundleSet bundleManager = instance.getBundleSet();
        bundleManager.lock(bundleNftId);

        emit LogBundleServiceBundleLocked(bundleNftId);
    }


    function unlock(NftId bundleNftId) 
        external
        virtual
    {
        (,, IInstance instance) = _getAndVerifyActiveComponent(POOL());

        // udpate bundle state
        instance.getInstanceStore().updateBundleState(bundleNftId, ACTIVE());

        // update set of active bundles
        BundleSet bundleManager = instance.getBundleSet();
        bundleManager.unlock(bundleNftId);

        emit LogBundleServiceBundleActivated(bundleNftId);
    }


    function close(
        IInstance instance,
        NftId bundleNftId
    ) 
        external
        virtual
        restricted
        returns (Amount unstakedAmount, Amount feeAmount)
    {
        InstanceReader instanceReader = instance.getInstanceReader();

        // ensure no open policies attached to bundle
        BundleSet bundleManager = instance.getBundleSet();
        uint256 openPolicies = bundleManager.activePolicies(bundleNftId);
        if(openPolicies > 0) {
            revert ErrorBundleServiceBundleWithOpenPolicies(bundleNftId, openPolicies);
        }

        {
            // update bundle state
            InstanceStore instanceStore = instance.getInstanceStore();
            instanceStore.updateBundleState(bundleNftId, CLOSED());
            bundleManager.lock(bundleNftId);

            // decrease bundle counters
            Amount balanceAmountWithFees = instanceReader.getBalanceAmount(bundleNftId);
            feeAmount = instanceReader.getFeeAmount(bundleNftId);
            unstakedAmount = balanceAmountWithFees - feeAmount;
            _componentService.decreaseBundleBalance(instanceStore, bundleNftId, unstakedAmount, feeAmount);
        }
    }

    /// @inheritdoc IBundleService
    function stake(
        IInstance instance,
        NftId bundleNftId, 
        Amount amount
    ) 
        external 
        virtual
        // TODO: restricted() (once #462 is done)
    {
        IBundle.BundleInfo memory bundleInfo = instance.getInstanceReader().getBundleInfo(bundleNftId);
        StateId bundleState = instance.getInstanceReader().getBundleState(bundleNftId);

        if( (bundleState != ACTIVE() && bundleState != PAUSED()) // locked bundles can be staked
            || bundleInfo.expiredAt < TimestampLib.blockTimestamp() 
            || bundleInfo.closedAt.gtz()) {
            revert ErrorBundleServiceBundleNotOpen(bundleNftId, bundleState, bundleInfo.expiredAt);
        }

        _componentService.increaseBundleBalance(
            instance.getInstanceStore(), 
            bundleNftId, 
            amount, 
            AmountLib.zero());
    }

    /// @inheritdoc IBundleService
    function unstake(
        IInstance instance, 
        NftId bundleNftId, 
        Amount amount
    ) 
        external 
        virtual
        // TODO: restricted() (once #462 is done)
        returns (Amount unstakedAmount)
    {
        InstanceStore instanceStore = instance.getInstanceStore();
        (
            Amount balanceAmount,
            Amount lockedAmount,
            Amount feeAmount
        ) = instanceStore.getAmounts(bundleNftId);

        Amount unstakedAmount = amount;
        Amount availableAmount = balanceAmount - (lockedAmount + feeAmount);

        // if amount is max, then unstake all available 
        if (amount.gte(AmountLib.max())) {
            unstakedAmount = availableAmount;
        }
        
        // ensure unstaked amount does not exceed available amount
        if (unstakedAmount > availableAmount) {
            revert ErrorBundleServiceUnstakeAmountExceedsLimit(amount, availableAmount);
        }

        _componentService.decreaseBundleBalance(
            instanceStore, 
            bundleNftId, 
            unstakedAmount, 
            AmountLib.zero());

        return unstakedAmount;
    }

    /// @inheritdoc IBundleService
    function extend(NftId bundleNftId, Seconds lifetimeExtension) 
        external 
        virtual
        // TODO: restricted() (once #462 is done)
        returns (Timestamp extendedExpiredAt) 
    {
        (NftId poolNftId,, IInstance instance) = _getAndVerifyActiveComponent(POOL());
        IBundle.BundleInfo memory bundleInfo = instance.getInstanceReader().getBundleInfo(bundleNftId);
        StateId bundleState = instance.getInstanceReader().getBundleState(bundleNftId);

        // ensure bundle belongs to the pool
        if (bundleInfo.poolNftId != poolNftId) {
            revert ErrorBundleServiceBundlePoolMismatch(bundleNftId, bundleInfo.poolNftId, poolNftId);
        }

        // ensure bundle is active and not yet expired
        if(bundleState != ACTIVE() || bundleInfo.expiredAt < TimestampLib.blockTimestamp()) {
            revert ErrorBundleServiceBundleNotOpen(bundleNftId, bundleState, bundleInfo.expiredAt);
        }

        if (lifetimeExtension.eqz()) {
            revert ErrorBundleServiceExtensionLifetimeIsZero();
        }

        bundleInfo.expiredAt = bundleInfo.expiredAt.addSeconds(lifetimeExtension);
        instance.getInstanceStore().updateBundle(bundleNftId, bundleInfo, KEEP_STATE());

        emit LogBundleServiceBundleExtended(bundleNftId, lifetimeExtension, bundleInfo.expiredAt);

        return bundleInfo.expiredAt;
    }


    function releaseCollateral(
        IInstance instance,
        NftId policyNftId, 
        NftId bundleNftId, 
        Amount collateralAmount
    ) 
        external
        virtual
        restricted()
    {
        instance.getInstanceStore().decreaseLocked(bundleNftId, collateralAmount);
    }

    // TODO cleanup
    // /// @dev unlinks policy from bundle
    // function unlinkPolicy(
    //     IInstance instance, 
    //     NftId policyNftId
    // ) 
    //     external
    //     virtual
    //     restricted
    // {
    //     // ensure policy is closeable
    //     if (!policyIsCloseable(instance, policyNftId)) {
    //         revert ErrorBundleServicePolicyNotCloseable(policyNftId);
    //     }

    //     instance.getBundleSet().unlinkPolicy(policyNftId);
    // }

    /// @inheritdoc IBundleService
    function withdrawBundleFees(NftId bundleNftId, Amount amount) 
        public 
        virtual
        // TODO: restricted() (once #462 is done)
        returns (Amount withdrawnAmount) 
    {
        (NftId poolNftId,, IInstance instance) = _getAndVerifyActiveComponent(POOL());
        InstanceReader reader = instance.getInstanceReader();
        
        IComponents.ComponentInfo memory poolInfo = reader.getComponentInfo(poolNftId);
        address poolWallet = poolInfo.wallet;
        
        IBundle.BundleInfo memory bundleInfo = reader.getBundleInfo(bundleNftId);
        
        // determine withdrawn amount
        withdrawnAmount = amount;
        if (withdrawnAmount.gte(AmountLib.max())) {
            withdrawnAmount = reader.getFeeAmount(bundleNftId);
        } else {
            if (withdrawnAmount.gt(reader.getFeeAmount(bundleNftId))) {
                revert ErrorBundleServiceFeesWithdrawAmountExceedsLimit(withdrawnAmount, reader.getFeeAmount(bundleNftId));
            }
        }

        // decrease fee counters by withdrawnAmount
        {
            InstanceStore store = instance.getInstanceStore();
            // decrease fee amount of the bundle
            _componentService.decreaseBundleBalance(store, bundleNftId, AmountLib.zero(), withdrawnAmount);
            // decrease pool balance 
            _componentService.decreasePoolBalance(store, poolNftId, withdrawnAmount, AmountLib.zero());
        }

        // transfer amount to bundle owner
        {
            address owner = getRegistry().ownerOf(bundleNftId);
            emit LogBundleServiceFeesWithdrawn(bundleNftId, owner, address(poolInfo.token), withdrawnAmount);
            poolInfo.tokenHandler.distributeTokens(poolWallet, owner, withdrawnAmount);
        }
    }

    // TODO cleanup
    // /// @dev links policy to bundle
    // function _linkPolicy(IInstance instance, NftId policyNftId) 
    //     internal
    // {
    //     InstanceReader instanceReader = instance.getInstanceReader();
    //     IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);

    //     // ensure policy has not yet been activated in a previous tx already
    //     if (policyInfo.activatedAt.gtz() && policyInfo.activatedAt < TimestampLib.blockTimestamp()) {
    //         revert BundleSet.ErrorBundleSetPolicyAlreadyActivated(policyNftId);
    //     }

    //     // 
    //     BundleSet bundleManager = instance.getBundleSet();
    //     bundleManager.linkPolicy(policyNftId);
    // }

    function _getDomain() internal pure override returns(ObjectType) {
        return BUNDLE();
    }
}
