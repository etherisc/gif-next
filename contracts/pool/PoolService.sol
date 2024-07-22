// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IBundle} from "../instance/module/IBundle.sol";
import {IBundleService} from "./IBundleService.sol";
import {IComponents} from "../instance/module/IComponents.sol";
import {IComponentService} from "../shared/IComponentService.sol";
import {IInstance} from "../instance/IInstance.sol";
import {IInstanceService} from "../instance/IInstanceService.sol";
import {IPolicy} from "../instance/module/IPolicy.sol";
import {IPoolService} from "./IPoolService.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {IRegistryService} from "../registry/IRegistryService.sol";
import {IStaking} from "../staking/IStaking.sol";

import {Amount, AmountLib} from "../type/Amount.sol";
import {Fee, FeeLib} from "../type/Fee.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType, POOL, BUNDLE, COMPONENT, INSTANCE, REGISTRY} from "../type/ObjectType.sol";
import {RoleId, PUBLIC_ROLE} from "../type/RoleId.sol";
import {Fee, FeeLib} from "../type/Fee.sol";
import {KEEP_STATE} from "../type/StateId.sol";
import {Seconds} from "../type/Seconds.sol";
import {UFixed} from "../type/UFixed.sol";
import {ComponentVerifyingService} from "../shared/ComponentVerifyingService.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";
import {InstanceStore} from "../instance/InstanceStore.sol";

string constant POOL_SERVICE_NAME = "PoolService";

contract PoolService is 
    ComponentVerifyingService, 
    IPoolService 
{
    IBundleService internal _bundleService;
    IComponentService internal _componentService;
    IInstanceService private _instanceService;
    IRegistryService private _registryService;

    IStaking private _staking;

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
        _bundleService = IBundleService(_getServiceAddress(BUNDLE()));
        _instanceService = IInstanceService(_getServiceAddress(INSTANCE()));
        _componentService = IComponentService(_getServiceAddress(COMPONENT()));

        _staking = IStaking(getRegistry().getStakingAddress());

        _registerInterface(type(IPoolService).interfaceId);
    }

    /// @inheritdoc IPoolService
    function setMaxBalanceAmount(Amount maxBalanceAmount)
        external
        virtual
    {
        (NftId poolNftId,, IInstance instance) = _getAndVerifyActiveComponent(POOL());
        InstanceReader instanceReader = instance.getInstanceReader();
        IComponents.PoolInfo memory poolInfo = instanceReader.getPoolInfo(poolNftId);

        Amount previousMaxBalanceAmount = poolInfo.maxBalanceAmount;
        poolInfo.maxBalanceAmount = maxBalanceAmount;
        instance.getInstanceStore().updatePool(poolNftId, poolInfo, KEEP_STATE());

        emit LogPoolServiceMaxBalanceAmountUpdated(poolNftId, previousMaxBalanceAmount, maxBalanceAmount);
    }

    function setBundleOwnerRole(RoleId bundleOwnerRole)
        external
        virtual
    {
        (NftId poolNftId,, IInstance instance) = _getAndVerifyActiveComponent(POOL());
        InstanceReader instanceReader = instance.getInstanceReader();

        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(poolNftId);
        IComponents.PoolInfo memory poolInfo = abi.decode(componentInfo.data, (IComponents.PoolInfo));

        // bundle owner role may only be set once per pool
        if(poolInfo.bundleOwnerRole != PUBLIC_ROLE()) {
            revert ErrorPoolServiceBundleOwnerRoleAlreadySet(poolNftId);
        }

        poolInfo.bundleOwnerRole = bundleOwnerRole;
        instance.getInstanceStore().updatePool(poolNftId, poolInfo, KEEP_STATE());

        emit LogPoolServiceBundleOwnerRoleSet(poolNftId, bundleOwnerRole);
    }

    /// @inheritdoc IPoolService
    function createBundle(
        address bundleOwner, // initial bundle owner
        Fee memory fee, // fees deducted from premium that go to bundle owner
        Seconds lifetime, // initial duration for which new policies are covered
        bytes calldata filter // optional use case specific criteria that define if a policy may be covered by this bundle
    )
        external 
        virtual
        returns(NftId bundleNftId)
    {
        (NftId poolNftId,, IInstance instance) = _getAndVerifyActiveComponent(POOL());

        // create the empty bundle
        bundleNftId = _bundleService.create(
            instance,
            poolNftId,
            bundleOwner,
            fee,
            AmountLib.zero(), 
            lifetime,
            filter);

        emit LogPoolServiceBundleCreated(instance.getNftId(), poolNftId, bundleNftId);
    }

    function _getStakingFee(InstanceReader instanceReader, NftId poolNftId)
        internal
        virtual
        view
        returns (Fee memory stakingFee)
    {
        NftId productNftId = instanceReader.getComponentInfo(poolNftId).productNftId;
        return instanceReader.getProductInfo(productNftId).stakingFee;
    }

    function closeBundle(NftId bundleNftId)
        external
        virtual
    {
        (NftId poolNftId,, IInstance instance) = _getAndVerifyActiveComponent(POOL());

        // TODO get performance fee for pool (#477)

        // releasing collateral in bundle
        (Amount unstakedAmount, Amount feeAmount) = _bundleService.close(instance, bundleNftId);

        _componentService.decreasePoolBalance(
            instance.getInstanceStore(), 
            poolNftId, 
            unstakedAmount +  feeAmount, 
            AmountLib.zero());
        
        emit LogPoolServiceBundleClosed(instance.getNftId(), poolNftId, bundleNftId);

        if ((unstakedAmount + feeAmount).gtz()){
            IComponents.ComponentInfo memory poolComponentInfo = instance.getInstanceReader().getComponentInfo(poolNftId);
            poolComponentInfo.tokenHandler.distributeTokens(
                poolComponentInfo.wallet, 
                getRegistry().ownerOf(bundleNftId), 
                unstakedAmount + feeAmount);
        }
    }

    /// @inheritdoc IPoolService
    function stake(NftId bundleNftId, Amount amount) 
        external 
        virtual
        // TODO: restricted() (once #462 is done)
        returns(Amount netAmount) 
    {
        (NftId poolNftId,, IInstance instance) = _getAndVerifyActiveComponent(POOL());
        InstanceReader instanceReader = instance.getInstanceReader();
        IBundle.BundleInfo memory bundleInfo = instanceReader.getBundleInfo(bundleNftId);
        IComponents.PoolInfo memory poolInfo = instanceReader.getPoolInfo(poolNftId);

        if (bundleInfo.poolNftId != poolNftId) {
            revert ErrorPoolServiceBundlePoolMismatch(bundleNftId, poolNftId);
        }

        {
            Amount currentPoolBalance = instanceReader.getBalanceAmount(poolNftId);
            if (currentPoolBalance + amount > poolInfo.maxBalanceAmount) {
                revert ErrorPoolServiceMaxBalanceAmountExceeded(poolNftId, poolInfo.maxBalanceAmount, currentPoolBalance, amount);
            }
        }

        // calculate fees
        Amount feeAmount;
        (
            feeAmount,
            netAmount
        ) = FeeLib.calculateFee(
            _getStakingFee(instanceReader, poolNftId), 
            amount);

        // do all the bookkeeping
        _componentService.increasePoolBalance(
            instance.getInstanceStore(), 
            poolNftId, 
            netAmount, 
            feeAmount);

        _bundleService.stake(instance, bundleNftId, netAmount);

        // collect tokens from bundle owner
        address bundleOwner = getRegistry().ownerOf(bundleNftId);
        emit LogPoolServiceBundleStaked(instance.getNftId(), poolNftId, bundleNftId, amount, netAmount);

        // TODO only collect staking token when pool is not externally managed 
        _collectStakingAmount(
            instanceReader, 
            poolNftId, 
            bundleOwner, 
            amount);
    }

    /// @inheritdoc IPoolService
    function unstake(NftId bundleNftId, Amount amount) 
        external 
        virtual
        // TODO: restricted() (once #462 is done)
        returns(Amount netAmount) 
    {
        (NftId poolNftId,, IInstance instance) = _getAndVerifyActiveComponent(POOL());
        InstanceReader instanceReader = instance.getInstanceReader();
        InstanceStore instanceStore = instance.getInstanceStore();
        IBundle.BundleInfo memory bundleInfo = instanceReader.getBundleInfo(bundleNftId);
        
        if (bundleInfo.poolNftId != poolNftId) {
            revert ErrorPoolServiceBundlePoolMismatch(bundleNftId, poolNftId);
        }

        // call bundle service for bookkeeping and additional checks
        Amount unstakedAmount = _bundleService.unstake(instance, bundleNftId, amount);

        // Important: from now on work only with unstakedAmount as it is the only reliable amount.
        // if amount was max, this was set to the available amount

        // TODO: handle performance fees (issue #477)

        // update pool bookkeeping - performance fees stay in the pool, but as fees 
        _componentService.decreasePoolBalance(
            instanceStore, 
            poolNftId, 
            unstakedAmount, 
            AmountLib.zero());

        IComponents.ComponentInfo memory poolComponentInfo = instanceReader.getComponentInfo(poolNftId);
        address poolWallet = poolComponentInfo.wallet;
        // transfer amount to bundle owner
        address owner = getRegistry().ownerOf(bundleNftId);
        emit LogPoolServiceBundleUnstaked(instance.getNftId(), poolNftId, bundleNftId, unstakedAmount);
        poolComponentInfo.tokenHandler.distributeTokens(
            poolWallet, 
            owner, 
            unstakedAmount);
        return unstakedAmount;
    }


    function fundPoolWallet(NftId poolNftId, Amount amount)
        external
        virtual
        restricted()
    {
        // TODO check that poolNftId is externally managed
        // TODO implement
    }


    function defundPoolWallet(NftId poolNftId, Amount amount)
        external
        virtual
        restricted()
    {
        // TODO check that poolNftId is externally managed
        // TODO implement
    }

    function processSale(
        NftId bundleNftId, 
        IPolicy.PremiumInfo memory premium 
    ) 
        external
        virtual
        restricted()
    {
        IRegistry registry = getRegistry();
        IRegistry.ObjectInfo memory bundleObjectInfo = registry.getObjectInfo(bundleNftId);
        IRegistry.ObjectInfo memory poolObjectInfo = registry.getObjectInfo(bundleObjectInfo.parentNftId);
        IRegistry.ObjectInfo memory instanceObjectInfo = registry.getObjectInfo(poolObjectInfo.parentNftId);
        IInstance instance = IInstance(instanceObjectInfo.objectAddress);

        Amount poolFeeAmount = premium.poolFeeFixAmount + premium.poolFeeVarAmount;
        Amount bundleFeeAmount = premium.bundleFeeFixAmount + premium.bundleFeeVarAmount;
        Amount bundleNetAmount = premium.netPremiumAmount;

        InstanceStore instanceStore = instance.getInstanceStore();
        _componentService.increasePoolBalance(
            instanceStore,
            poolObjectInfo.nftId,
            bundleNetAmount + bundleFeeAmount, 
            poolFeeAmount);

        _componentService.increaseBundleBalance(
            instanceStore,
            bundleObjectInfo.nftId,
            bundleNetAmount, 
            bundleFeeAmount);
    }


    function lockCollateral(
        IInstance instance, 
        address token,
        NftId productNftId,
        NftId applicationNftId,
        NftId bundleNftId,
        Amount sumInsuredAmount // premium amount after product and distribution fees
    )
        external
        virtual
        restricted()
        returns (
            Amount localCollateralAmount,
            Amount totalCollateralAmount
        )
    {
        (
            localCollateralAmount,
            totalCollateralAmount
        ) = calculateRequiredCollateral(
            instance.getInstanceReader(),
            productNftId, 
            sumInsuredAmount);

        // lock collateral amount from involved bundle
        _bundleService.lockCollateral(
            instance,
            applicationNftId, 
            bundleNftId,
            localCollateralAmount);

        // update value locked with staking service
        _staking.increaseTotalValueLocked(
            instance.getNftId(),
            token,
            totalCollateralAmount);

        // hierarhical riskpool setup
        // TODO loop in with pool component to guarantee availability of external capital
        if(totalCollateralAmount > localCollateralAmount) {

        }
    }


    function reduceCollateral(
        IInstance instance, 
        address token,
        NftId policyNftId, 
        IPolicy.PolicyInfo memory policyInfo,
        Amount payoutAmount
    )
        external
        virtual
        restricted()
    {
        _bundleService.releaseCollateral(
            instance, 
            policyNftId, 
            policyInfo.bundleNftId, 
            payoutAmount);

        // update value locked with staking service
        _staking.decreaseTotalValueLocked(
            instance.getNftId(),
            token,
            payoutAmount);
    }


    /// @dev releases the remaining collateral linked to the specified policy
    /// may only be called by the policy service for unlocked pool components
    function releaseCollateral(
        IInstance instance, 
        address token,
        NftId policyNftId, 
        IPolicy.PolicyInfo memory policyInfo
    )
        external
        virtual
        restricted()
    {
        Amount remainingCollateralAmount = policyInfo.sumInsuredAmount - policyInfo.claimAmount;

        _bundleService.releaseCollateral(
            instance, 
            policyNftId, 
            policyInfo.bundleNftId, 
            remainingCollateralAmount);

        _bundleService.unlinkPolicy(
            instance, 
            policyNftId);

        // update value locked with staking service
        _staking.decreaseTotalValueLocked(
            instance.getNftId(),
            token,
            remainingCollateralAmount);
    }


    function calculateRequiredCollateral(
        InstanceReader instanceReader,
        NftId productNftId, 
        Amount sumInsuredAmount
    )
        public
        view 
        returns(
            Amount localCollateralAmount,
            Amount totalCollateralAmount
        )
    {
        NftId poolNftId = instanceReader.getProductInfo(productNftId).poolNftId;
        IComponents.PoolInfo memory poolInfo = instanceReader.getPoolInfo(poolNftId);

        (
            localCollateralAmount,
            totalCollateralAmount
        ) = calculateRequiredCollateral(
            poolInfo.collateralizationLevel,
            poolInfo.retentionLevel,
            sumInsuredAmount);
    }


    function calculateRequiredCollateral(
        UFixed collateralizationLevel, 
        UFixed retentionLevel, 
        Amount sumInsuredAmount
    )
        public
        pure 
        returns(
            Amount localCollateralAmount,
            Amount totalCollateralAmount
        )
    {
        // TODO define if only applies to local collateral
        // TODO add minimalistic implementation

        // assumptions 
        // - collateralizationLevel == 1.0
        // - retentionLevel == 1.0
        localCollateralAmount = sumInsuredAmount;
        totalCollateralAmount = localCollateralAmount;
    }


    function _processStakingFees(
        Fee memory stakingFee, 
        Amount stakingAmount
    )
        internal
        returns (Amount stakingNetAmount)
    {
        stakingNetAmount = stakingAmount;

        // check if any staking fees apply
        if (FeeLib.gtz(stakingFee)) {
            (Amount feeAmount, Amount netAmount) = FeeLib.calculateFee(stakingFee, stakingAmount);
            stakingNetAmount = netAmount;

            // TODO update fee balance for pool
        }
    }


    /// @dev transfers the specified amount from the bundle owner to the pool's wallet
    function _collectStakingAmount(
        InstanceReader instanceReader,
        NftId poolNftId,
        address bundleOwner,
        Amount amount
    )
        internal
    {

        // collecting investor token
        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(poolNftId);
        address poolWallet = componentInfo.wallet;
        componentInfo.tokenHandler.collectTokens(
            bundleOwner,
            poolWallet,
            amount);
    }

    function _getDomain() internal pure override returns(ObjectType) {
        return POOL();
    }
}