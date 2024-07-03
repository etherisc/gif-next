// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

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
import {NftId, NftIdLib} from "../type/NftId.sol";
import {ObjectType, POOL, BUNDLE, COMPONENT, INSTANCE, REGISTRY} from "../type/ObjectType.sol";
import {RoleId, PUBLIC_ROLE} from "../type/RoleId.sol";
import {Fee, FeeLib} from "../type/Fee.sol";
import {KEEP_STATE} from "../type/StateId.sol";
import {Seconds} from "../type/Seconds.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";
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
        initializer
        virtual override
    {
        (
            address registryAddress,, 
            //address managerAddress
            address authority
        ) = abi.decode(data, (address, address, address));

        initializeService(registryAddress, authority, owner);

        _registryService = IRegistryService(_getServiceAddress(REGISTRY()));
        _bundleService = IBundleService(_getServiceAddress(BUNDLE()));
        _instanceService = IInstanceService(_getServiceAddress(INSTANCE()));
        _componentService = IComponentService(_getServiceAddress(COMPONENT()));

        _staking = IStaking(getRegistry().getStakingAddress());

        registerInterface(type(IPoolService).interfaceId);
    }


    function setMaxCapitalAmount(Amount maxCapitalAmount)
        external
        virtual
    {
        /*
        (NftId poolNftId,, IInstance instance) = _getAndVerifyActiveComponent(POOL());
        InstanceReader instanceReader = instance.getInstanceReader();

        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(poolNftId);
        IComponents.PoolInfo memory poolInfo = abi.decode(componentInfo.data, (IComponents.PoolInfo));
        Amount previousMaxCapitalAmount = poolInfo.maxCapitalAmount;

        poolInfo.maxCapitalAmount = maxCapitalAmount;
        instance.getInstanceStore().updatePool(poolNftId, poolInfo, KEEP_STATE());

        emit LogPoolServiceMaxCapitalAmountUpdated(poolNftId, previousMaxCapitalAmount, maxCapitalAmount);
        */
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


    function setFees(
        Fee memory poolFee,
        Fee memory stakingFee,
        Fee memory performanceFee
    )
        external
        virtual
    {
        (NftId poolNftId,, IInstance instance) = _getAndVerifyActiveComponent(POOL());

        IComponents.PoolInfo memory poolInfo = instance.getInstanceReader().getPoolInfo(poolNftId);
        poolInfo.poolFee = poolFee;
        poolInfo.stakingFee = stakingFee;
        poolInfo.performanceFee = performanceFee;

        instance.getInstanceStore().updatePool(poolNftId, poolInfo, KEEP_STATE());

        // TODO add logging
    }

    /// @inheritdoc IPoolService
    function createBundle(
        address bundleOwner, // initial bundle owner
        Fee memory fee, // fees deducted from premium that go to bundle owner
        Amount stakingAmount, // staking amount - staking fees result in initial bundle capital
        Seconds lifetime, // initial duration for which new policies are covered
        bytes calldata filter // optional use case specific criteria that define if a policy may be covered by this bundle
    )
        external 
        virtual
        returns(NftId bundleNftId)
    {
        (NftId poolNftId,, IInstance instance) = _getAndVerifyActiveComponent(POOL());
        InstanceReader instanceReader = instance.getInstanceReader();

        (
            Amount stakingFeeAmount,
            Amount stakingNetAmount
        ) = FeeLib.calculateFee(
            _getStakingFee(instanceReader, poolNftId), 
            stakingAmount);

        // TODO: staking amount must be be > maxCapitalAmount

        bundleNftId = _bundleService.create(
            instance,
            poolNftId,
            bundleOwner,
            fee,
            stakingNetAmount,
            lifetime,
            filter);

        // pool book keeping
        _componentService.increasePoolBalance(
            instance.getInstanceStore(), 
            poolNftId, 
            stakingNetAmount, 
            stakingFeeAmount);

        // pool bookkeeping and collect tokens from bundle owner
        _collectStakingAmount(
            instanceReader, 
            poolNftId, 
            bundleOwner, 
            stakingAmount);

        emit LogPoolServiceBundleCreated(instance.getNftId(), poolNftId, bundleNftId);
    }

    function _getStakingFee(InstanceReader instanceReader, NftId poolNftId)
        internal
        virtual
        view
        returns (Fee memory stakingFee)
    {
        NftId productNftId = instanceReader.getPoolInfo(poolNftId).productNftId;
        return instanceReader.getPoolInfo(productNftId).stakingFee;
    }

    function closeBundle(NftId bundleNftId)
        external
        virtual
    {
        (NftId poolNftId,, IInstance instance) = _getAndVerifyActiveComponent(POOL());

        // TODO book keeping for pool collateral released outside of retention level

        // releasing collateral in bundle
        _bundleService.close(instance, bundleNftId);

        // TODO get performance fee for pool, transfer of remaining funds + bundle fees to bundle owner

        emit LogPoolServiceBundleClosed(instance.getNftId(), poolNftId, bundleNftId);
    }

    /// @inheritdoc IPoolService
    function stake(NftId bundleNftId, Amount amount) 
        external 
        virtual
        restricted()
        returns(Amount netAmount) 
    {
        (NftId poolNftId,, IInstance instance) = _getAndVerifyActiveComponent(POOL());
        InstanceReader instanceReader = instance.getInstanceReader();
        IBundle.BundleInfo memory bundleInfo = instanceReader.getBundleInfo(bundleNftId);
        IComponents.PoolInfo memory poolInfo = instanceReader.getPoolInfo(poolNftId);

        if (bundleInfo.poolNftId != poolNftId) {
            revert ErrorPoolServiceBundlePoolMismatch(bundleNftId, poolNftId);
        }

        Amount currentPoolBalance = instanceReader.getBalanceAmount(poolNftId);
        if (amount + currentPoolBalance > poolInfo.maxCapitalAmount) {
            revert ErrorPoolServiceMaxCapitalAmountExceeded(poolNftId, poolInfo.maxCapitalAmount, currentPoolBalance, amount);
        }

        // calculate fees
        (
            Amount feeAmount,
            Amount netAmount
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
        _collectStakingAmount(
            instanceReader, 
            poolNftId, 
            bundleOwner, 
            amount);

        emit LogPoolServiceBundleStaked(instance.getNftId(), poolNftId, bundleNftId, amount, netAmount);
    }

    /// @inheritdoc IPoolService
    function unstake(NftId bundleNftId, Amount amount) 
        external 
        virtual
        restricted()
        returns(Amount netAmount) 
    {
        (NftId poolNftId,, IInstance instance) = _getAndVerifyActiveComponent(POOL());
        InstanceReader instanceReader = instance.getInstanceReader();
        InstanceStore instanceStore = instance.getInstanceStore();
        IBundle.BundleInfo memory bundleInfo = instanceReader.getBundleInfo(bundleNftId);
        
        if (bundleInfo.poolNftId != poolNftId) {
            revert ErrorPoolServiceBundlePoolMismatch(bundleNftId, poolNftId);
        }

        if (amount.eqz()) {
            revert ErrorPoolServiceAmountIsZero();
        }

        // call bundle service for bookkeeping and additional checks
        _bundleService.unstake(instance, bundleNftId, amount);

        // TODO: handle performance fees (issue #477)

        // update pool bookkeeping - performance fees stay in the pool, but as fees 
        _componentService.decreasePoolBalance(
            instanceStore, 
            poolNftId, 
            amount, 
            AmountLib.zero());

        // check allowance
        IComponents.ComponentInfo memory poolComponentInfo = instanceReader.getComponentInfo(poolNftId);
        address poolWallet = poolComponentInfo.wallet;
        IERC20Metadata token = IERC20Metadata(poolComponentInfo.token);
        uint256 tokenAllowance = token.allowance(poolWallet, address(poolComponentInfo.tokenHandler));
        if (tokenAllowance < amount.toInt()) {
            revert ErrorPoolServiceWalletAllowanceTooSmall(poolWallet, address(poolComponentInfo.tokenHandler), tokenAllowance, amount.toInt());
        }

        // transfer amount to bundle owner
        address owner = getRegistry().ownerOf(bundleNftId);
        // TODO: centralize token handling (issue #471)
        poolComponentInfo.tokenHandler.transfer(poolWallet, owner, amount);
        
        emit LogPoolServiceBundleUnstaked(instance.getNftId(), poolNftId, bundleNftId, amount);

        return amount;
    }

    function _getPerformanceFee(InstanceReader instanceReader, NftId poolNftId)
        internal
        virtual
        view
        returns (Fee memory performanceFee)
    {
        NftId productNftId = instanceReader.getPoolInfo(poolNftId).productNftId;
        return instanceReader.getPoolInfo(productNftId).performanceFee;
    }

    function processSale(
        NftId bundleNftId, 
        IPolicy.Premium memory premium 
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

        Amount poolFeeAmount = AmountLib.toAmount(premium.poolFeeFixAmount + premium.poolFeeVarAmount);
        Amount bundleFeeAmount = AmountLib.toAmount(premium.bundleFeeFixAmount + premium.bundleFeeVarAmount);
        Amount bundleNetAmount = AmountLib.toAmount(premium.netPremiumAmount);

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


    // TODO create (I)TreasuryService that deals with all gif related token transfers
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
        TokenHandler tokenHandler = componentInfo.tokenHandler;
        address poolWallet = componentInfo.wallet;

        if(amount.gtz()) {
            // TODO: centralize token handling (issue #471)
            tokenHandler.transfer(
                bundleOwner,
                poolWallet,
                amount);
        }
    }

    function _getDomain() internal pure override returns(ObjectType) {
        return POOL();
    }
}