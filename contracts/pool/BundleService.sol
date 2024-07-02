// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

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
import {Fee, FeeLib} from "../type/Fee.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";
import {NftId, NftIdLib} from "../type/NftId.sol";
import {ObjectType, COMPONENT, POOL, BUNDLE, REGISTRY} from "../type/ObjectType.sol";
import {StateId, ACTIVE, PAUSED, CLOSED, KEEP_STATE} from "../type/StateId.sol";
import {Seconds} from "../type/Seconds.sol";
import {TimestampLib, zeroTimestamp} from "../type/Timestamp.sol";

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
        initializer
        virtual override
    {
        address registryAddress;
        address initialOwner;
        (registryAddress, initialOwner) = abi.decode(data, (address, address));
        // TODO while PoolService is not deployed in PoolServiceManager constructor
        //      owner is PoolServiceManager deployer
        initializeService(registryAddress, address(0), owner);

        _registryService = IRegistryService(_getServiceAddress(REGISTRY()));
        _componentService = IComponentService(_getServiceAddress(COMPONENT()));

        registerInterface(type(IBundleService).interfaceId);
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
            IBundle.BundleInfo(
                poolNftId,
                bundleFee,
                filter,
                lifetime,
                TimestampLib.blockTimestamp().addSeconds(lifetime),
                zeroTimestamp()));

        // bundle book keeping
        _componentService.increaseBundleBalance(
            instanceStore, 
            bundleNftId, 
            stakingAmount, 
            AmountLib.zero()); // fee amount

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
        StateId bundleState = instanceReader.getMetadata(bundleNftId.toKey32(BUNDLE())).state;
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
        
        // link policy to bundle in bundle manger
        _linkPolicy(instance, policyNftId);
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
    {
        // udpate bundle state
        instance.getInstanceStore().updateBundleState(bundleNftId, CLOSED());

        // ensure no open policies attached to bundle
        BundleSet bundleManager = instance.getBundleSet();
        uint256 openPolicies = bundleManager.activePolicies(bundleNftId);
        if(openPolicies > 0) {
            revert ErrorBundleServiceBundleWithOpenPolicies(bundleNftId, openPolicies);
        }

        // update set of active bundles
        bundleManager.lock(bundleNftId);
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
        // TODO: check not locked
        // TODO: check not expired
        // TODO: check not closed

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
        restricted()
    {
        InstanceStore instanceStore = instance.getInstanceStore();
        (
            Amount balanceAmount,
            Amount lockedAmount,
            Amount feeAmount
        ) = instanceStore.getAmounts(bundleNftId);

        // TODO: should the available amount include the fees or not? 
        Amount availableAmount = balanceAmount - (lockedAmount + feeAmount);
        
        if (availableAmount < amount) {
            revert ErrorBundleServiceStakeAmountExceedsLimit(amount, availableAmount);
        }

        _componentService.decreaseBundleBalance(
            instanceStore, 
            bundleNftId, 
            amount, 
            // TODO: if above includes fees, how to split this? 
            AmountLib.zero());
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

    /// @dev unlinks policy from bundle
    function unlinkPolicy(
        IInstance instance, 
        NftId policyNftId
    ) 
        external
        virtual
        restricted
    {
        // ensure policy is closeable
        if (!instance.getInstanceReader().policyIsCloseable(policyNftId)) {
            revert ErrorBundleServicePolicyNotCloseable(policyNftId);
        }

        instance.getBundleSet().unlinkPolicy(policyNftId);
    }

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

        if (withdrawnAmount.eqz()) {
            revert ErrorBundleServiceFeesWithdrawAmountIsZero();
        }

        // check allowance
        IERC20Metadata token = IERC20Metadata(poolInfo.token);
        uint256 tokenAllowance = token.allowance(poolWallet, address(poolInfo.tokenHandler));
        if (tokenAllowance < withdrawnAmount.toInt()) {
            revert ErrorBundleServiceWalletAllowanceTooSmall(poolWallet, address(poolInfo.tokenHandler), tokenAllowance, withdrawnAmount.toInt());
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
            // TODO: centralize token handling (issue #471)
            poolInfo.tokenHandler.transfer(poolWallet, owner, withdrawnAmount);

            emit LogBundleServiceFeesWithdrawn(bundleNftId, owner, address(token), withdrawnAmount);
        }
    }

    /// @dev links policy to bundle
    function _linkPolicy(IInstance instance, NftId policyNftId) 
        internal
    {
        InstanceReader instanceReader = instance.getInstanceReader();
        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);

        // ensure policy has not yet been activated in a previous tx already
        if (policyInfo.activatedAt.gtz() && policyInfo.activatedAt < TimestampLib.blockTimestamp()) {
            revert BundleSet.ErrorBundleSetPolicyAlreadyActivated(policyNftId);
        }
        
        BundleSet bundleManager = instance.getBundleSet();
        bundleManager.linkPolicy(policyNftId);
    }

    function _getDomain() internal pure override returns(ObjectType) {
        return BUNDLE();
    }
}
