// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccountingService} from "../accounting/IAccountingService.sol";
import {IBundle} from "../instance/module/IBundle.sol";
import {IBundleService} from "./IBundleService.sol";
import {IComponents} from "../instance/module/IComponents.sol";
import {IComponentService} from "../shared/IComponentService.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {IRegistryService} from "../registry/IRegistryService.sol";
import {IInstance} from "../instance/IInstance.sol";
import {InstanceStore} from "../instance/InstanceStore.sol";

import {Amount, AmountLib} from "../type/Amount.sol";
import {BundleSet} from "../instance/BundleSet.sol";
import {ComponentVerifyingService} from "../shared/ComponentVerifyingService.sol";
import {Fee} from "../type/Fee.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";
import {NftId, NftIdLib} from "../type/NftId.sol";
import {ObjectType, ACCOUNTING, COMPONENT, POOL, BUNDLE, POLICY, REGISTRY} from "../type/ObjectType.sol";
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
    IAccountingService private _accountingService;
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
            address authority,
            address registry
        ) = abi.decode(data, (address, address));

        __Service_init(authority, registry, owner);

        _registryService = IRegistryService(_getServiceAddress(REGISTRY()));
        _accountingService = IAccountingService(_getServiceAddress(ACCOUNTING()));
        _componentService = IComponentService(_getServiceAddress(COMPONENT()));

        _registerInterface(type(IBundleService).interfaceId);
    }


    function setFee(
        NftId bundleNftId,
        Fee memory fee
    )
        external
        virtual
        restricted()
    {
        _checkNftType(bundleNftId, BUNDLE());

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
        address owner, 
        Fee memory bundleFee, 
        Seconds lifetime, 
        bytes calldata filter
    )
        external
        virtual
        restricted()
        returns(NftId bundleNftId)
    {
        (NftId poolNftId,, IInstance instance) = _getAndVerifyActiveComponent(POOL());

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

        // put bundle under bundle managemet
        BundleSet bundleManager = instance.getBundleSet();
        bundleManager.add(bundleNftId);

        emit LogBundleServiceBundleCreated(bundleNftId, poolNftId);
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
        _checkNftType(policyNftId, POLICY());
        _checkNftType(bundleNftId, BUNDLE());

        InstanceReader instanceReader = instance.getInstanceReader();

        {
            StateId bundleState = instance.getInstanceReader().getBundleState(bundleNftId);
            IBundle.BundleInfo memory bundleInfo = instanceReader.getBundleInfo(bundleNftId);

            // ensure bundle is active and not yet expired
            if(bundleState != ACTIVE() || bundleInfo.expiredAt < TimestampLib.blockTimestamp()) {
                revert ErrorBundleServiceBundleNotOpen(bundleNftId, bundleState, bundleInfo.expiredAt);
            }
        }

        InstanceStore instanceStore = instance.getInstanceStore();

        {
            // ensure bundle capacity is sufficent to collateralize policy
            (
                Amount balanceAmount,
                Amount lockedAmount,
                Amount feeAmount
            ) = instanceStore.getAmounts(bundleNftId);

            Amount capacity = balanceAmount - (lockedAmount + feeAmount);
            if(capacity < collateralAmount) {
                revert ErrorBundleServiceCapacityInsufficient(bundleNftId, capacity, collateralAmount);
            }
        }

        // updated locked amount
        instanceStore.increaseLocked(bundleNftId, collateralAmount);
    }


    function lock(NftId bundleNftId) 
        external
        virtual
        restricted()
    {
        _checkNftType(bundleNftId, BUNDLE());

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
        restricted()
    {
        _checkNftType(bundleNftId, BUNDLE());

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
        restricted()
        returns (Amount unstakedAmount, Amount feeAmount)
    {
        _checkNftType(bundleNftId, BUNDLE());

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
            _accountingService.decreaseBundleBalance(instanceStore, bundleNftId, unstakedAmount, feeAmount);
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
        restricted()
    {
        _checkNftType(bundleNftId, BUNDLE());

        IBundle.BundleInfo memory bundleInfo = instance.getInstanceReader().getBundleInfo(bundleNftId);
        StateId bundleState = instance.getInstanceReader().getBundleState(bundleNftId);

        if( (bundleState != ACTIVE() && bundleState != PAUSED()) // locked bundles can be staked
            || bundleInfo.expiredAt < TimestampLib.blockTimestamp() 
            || bundleInfo.closedAt.gtz()) {
            revert ErrorBundleServiceBundleNotOpen(bundleNftId, bundleState, bundleInfo.expiredAt);
        }

        _accountingService.increaseBundleBalance(
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
        restricted()
        returns (Amount unstakedAmount)
    {
        _checkNftType(bundleNftId, BUNDLE());

        InstanceStore instanceStore = instance.getInstanceStore();
        (
            Amount balanceAmount,
            Amount lockedAmount,
            Amount feeAmount
        ) = instanceStore.getAmounts(bundleNftId);

        unstakedAmount = amount;
        Amount availableAmount = balanceAmount - (lockedAmount + feeAmount);

        // if amount is max, then unstake all available 
        if (amount.gte(AmountLib.max())) {
            unstakedAmount = availableAmount;
        }
        
        // ensure unstaked amount does not exceed available amount
        if (unstakedAmount > availableAmount) {
            revert ErrorBundleServiceUnstakeAmountExceedsLimit(amount, availableAmount);
        }

        _accountingService.decreaseBundleBalance(
            instanceStore, 
            bundleNftId, 
            unstakedAmount, 
            AmountLib.zero());
    }

    /// @inheritdoc IBundleService
    function extend(NftId bundleNftId, Seconds lifetimeExtension) 
        external 
        virtual
        restricted()
        returns (Timestamp extendedExpiredAt) 
    {
        _checkNftType(bundleNftId, BUNDLE());

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
        _checkNftType(policyNftId, POLICY());
        _checkNftType(bundleNftId, BUNDLE());

        instance.getInstanceStore().decreaseLocked(bundleNftId, collateralAmount);
    }


    /// @inheritdoc IBundleService
    function withdrawBundleFees(NftId bundleNftId, Amount amount) 
        public 
        virtual
        restricted()
        returns (Amount withdrawnAmount) 
    {
        _checkNftType(bundleNftId, BUNDLE());

        (NftId poolNftId,, IInstance instance) = _getAndVerifyActiveComponent(POOL());
        InstanceReader reader = instance.getInstanceReader();
        
        IComponents.ComponentInfo memory poolInfo = reader.getComponentInfo(poolNftId);
        address poolWallet = poolInfo.tokenHandler.getWallet();
        
        // IBundle.BundleInfo memory bundleInfo = reader.getBundleInfo(bundleNftId);
        
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
            _accountingService.decreaseBundleBalance(store, bundleNftId, AmountLib.zero(), withdrawnAmount);
            // decrease pool balance 
            _accountingService.decreasePoolBalance(store, poolNftId, withdrawnAmount, AmountLib.zero());
        }

        // transfer amount to bundle owner
        {
            address bundleOwner = getRegistry().ownerOf(bundleNftId);
            emit LogBundleServiceFeesWithdrawn(bundleNftId, bundleOwner, address(poolInfo.token), withdrawnAmount);
            poolInfo.tokenHandler.pushToken(bundleOwner, withdrawnAmount);
        }
    }

    function _getDomain() internal pure override returns(ObjectType) {
        return BUNDLE();
    }
}
