// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccountingService} from "../accounting/IAccountingService.sol";
import {IBundleService} from "./IBundleService.sol";
import {IComponents} from "../instance/module/IComponents.sol";
import {IComponentService} from "../shared/IComponentService.sol";
import {IInstance} from "../instance/IInstance.sol";
import {IPolicy} from "../instance/module/IPolicy.sol";
import {IPoolComponent} from "../pool/IPoolComponent.sol";
import {IPoolService} from "./IPoolService.sol";
import {IProductComponent} from "../product/IProductComponent.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {IStaking} from "../staking/IStaking.sol";

import {Amount, AmountLib} from "../type/Amount.sol";
import {ClaimId} from "../type/ClaimId.sol";
import {ContractLib} from "../shared/ContractLib.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";
import {InstanceStore} from "../instance/InstanceStore.sol";
import {KEEP_STATE} from "../type/StateId.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType, ACCOUNTING, POOL, BUNDLE, PRODUCT, POLICY, COMPONENT} from "../type/ObjectType.sol";
import {PayoutId} from "../type/PayoutId.sol";
import {PoolLib} from "./PoolLib.sol";
import {Service} from "../shared/Service.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";


contract PoolService is 
    Service, 
    IPoolService 
{
    // keccak256(abi.encode(uint256(keccak256("etherisc.gif.PoolService@3.0.0")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 public constant POOL_SERVICE_STORAGE_LOCATION_V3_0 = 0x99b25f02200e1434f4531a215abb8fd8c59ad15f6abb6b06ffa8223eb7162700;

    struct PoolServiceStorage {
        IAccountingService _accountingService;
        IBundleService _bundleService;
        IComponentService _componentService;
        IStaking _staking;
    }

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

        PoolServiceStorage storage $ = _getPoolServiceStorage();
        $._accountingService = IAccountingService(_getServiceAddress(ACCOUNTING()));
        $._bundleService = IBundleService(_getServiceAddress(BUNDLE()));
        $._componentService = IComponentService(_getServiceAddress(COMPONENT()));
        $._staking = IStaking(getRegistry().getStakingAddress());

        _registerInterface(type(IPoolService).interfaceId);
    }


    /// @inheritdoc IPoolService
    function setMaxBalanceAmount(Amount maxBalanceAmount)
        external
        virtual
        restricted()
    {
        (NftId poolNftId, IInstance instance) = _getAndVerifyActivePool();
        InstanceReader instanceReader = instance.getInstanceReader();
        IComponents.PoolInfo memory poolInfo = instanceReader.getPoolInfo(poolNftId);

        Amount previousMaxBalanceAmount = poolInfo.maxBalanceAmount;
        poolInfo.maxBalanceAmount = maxBalanceAmount;
        instance.getInstanceStore().updatePool(poolNftId, poolInfo, KEEP_STATE());

        emit LogPoolServiceMaxBalanceAmountUpdated(poolNftId, previousMaxBalanceAmount, maxBalanceAmount);
    }


    function closeBundle(NftId bundleNftId)
        external
        restricted()
        virtual
    {
        _checkNftType(bundleNftId, BUNDLE());

        (NftId poolNftId, IInstance instance) = _getAndVerifyActivePool();

        // TODO get performance fee for pool (#477)

        // releasing collateral in bundle
        PoolServiceStorage storage $ = _getPoolServiceStorage();
        (Amount unstakedAmount, Amount feeAmount) = $._bundleService.close(instance, bundleNftId);

        $._accountingService.decreasePoolBalance(
            instance.getInstanceStore(), 
            poolNftId, 
            unstakedAmount +  feeAmount, 
            AmountLib.zero());
        
        emit LogPoolServiceBundleClosed(instance.getNftId(), poolNftId, bundleNftId);

        if ((unstakedAmount + feeAmount).gtz()){
            IComponents.ComponentInfo memory poolComponentInfo = instance.getInstanceReader().getComponentInfo(poolNftId);
            poolComponentInfo.tokenHandler.pushToken(
                getRegistry().ownerOf(bundleNftId), 
                unstakedAmount + feeAmount);
        }
    }


    /// @inheritdoc IPoolService
    function processFundedClaim(
        NftId policyNftId, 
        ClaimId claimId, 
        Amount availableAmount
    ) 
        external
        restricted()
        virtual
    {
        _checkNftType(policyNftId, POLICY());

        (NftId poolNftId, IInstance instance) = _getAndVerifyActivePool();
        InstanceReader instanceReader = instance.getInstanceReader();
        NftId productNftId = getRegistry().getParentNftId(poolNftId);
        NftId policyProductNftId = getRegistry().getParentNftId(policyNftId);

        // check policy matches with calling pool
        if(policyProductNftId != productNftId) {
            revert ErrorPoolServicePolicyPoolMismatch(
                policyNftId, 
                policyProductNftId, 
                productNftId);
        }

        emit LogPoolServiceProcessFundedClaim(policyNftId, claimId, availableAmount);

        // callback to product component if applicable
        if (instanceReader.getProductInfo(productNftId).isProcessingFundedClaims) {
            address productAddress = getRegistry().getObjectAddress(productNftId);
            IProductComponent(productAddress).processFundedClaim(policyNftId, claimId, availableAmount);
        }
    }


    // function _checkAndGetPoolInfo(NftId bundleNftId)
    //     internal
    //     view
    //     returns (
    //         InstanceReader instanceReader,
    //         InstanceStore instanceStore,
    //         NftId instanceNftId,
    //         NftId poolNftId,
    //         IComponents.PoolInfo memory poolInfo
    //     )
    // {
    //     _checkNftType(bundleNftId, BUNDLE());

    //     (NftId poolNftId, IInstance instance) = _getAndVerifyActivePool();
    //     instanceReader = instance.getInstanceReader();
    //     instanceStore = instance.getInstanceStore();
    //     instanceNftId = instance.getNftId();
    //     poolInfo = instanceReader.getPoolInfo(poolNftId);

    //     if (getRegistry().getParentNftId(bundleNftId) != poolNftId) {
    //         revert ErrorPoolServiceBundlePoolMismatch(bundleNftId, poolNftId);
    //     }
    // }


    /// @inheritdoc IPoolService
    function stake(NftId bundleNftId, Amount amount) 
        external 
        virtual
        restricted()
        returns(
            Amount netAmount
        ) 
    {
        (
            InstanceReader instanceReader,
            InstanceStore instanceStore,
            NftId instanceNftId,
            NftId poolNftId,
            IComponents.PoolInfo memory poolInfo
        ) = PoolLib.checkAndGetPoolInfo(getRegistry(), msg.sender, bundleNftId);

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
        ) = PoolLib.calculateStakingAmounts(
            getRegistry(),
            instanceReader,
            poolNftId,
            amount);

        // do all the book keeping
        PoolServiceStorage storage $ = _getPoolServiceStorage();
        $._accountingService.increasePoolBalance(
            instanceStore, 
            poolNftId, 
            netAmount, 
            feeAmount);

        $._bundleService.stake(instanceReader, instanceStore, bundleNftId, netAmount);

        emit LogPoolServiceBundleStaked(instanceNftId, poolNftId, bundleNftId, amount, netAmount);

        // only collect staking amount when pool is not externally managed
        if (!poolInfo.isExternallyManaged) {

            // collect tokens from bundle owner
            address bundleOwner = getRegistry().ownerOf(bundleNftId);
            PoolLib.pullStakingAmount(
                instanceReader,
                poolNftId, 
                bundleOwner, 
                amount);
        }
    }


    /// @inheritdoc IPoolService
    function unstake(NftId bundleNftId, Amount amount) 
        external 
        virtual
        restricted()
        returns(Amount netAmount) 
    {
        (
            InstanceReader instanceReader,
            InstanceStore instanceStore,
            NftId instanceNftId,
            NftId poolNftId,
        ) = PoolLib.checkAndGetPoolInfo(getRegistry(), msg.sender, bundleNftId);

        // call bundle service for bookkeeping and additional checks
        PoolServiceStorage storage $ = _getPoolServiceStorage();
        Amount unstakedAmount = $._bundleService.unstake(instanceStore, bundleNftId, amount);

        // Important: from now on work only with unstakedAmount as it is the only reliable amount.
        // if amount was max, this was set to the available amount

        // TODO: handle performance fees (issue #477)
        netAmount = unstakedAmount;

        // update pool bookkeeping - performance fees stay in the pool, but as fees
        $._accountingService.decreasePoolBalance(
            instanceStore, 
            poolNftId, 
            unstakedAmount, 
            AmountLib.zero());


        emit LogPoolServiceBundleUnstaked(instanceNftId, poolNftId, bundleNftId, unstakedAmount, netAmount);

        // only distribute staking amount when pool is not externally managed
        if (!instanceReader.getPoolInfo(poolNftId).isExternallyManaged) {

            // transfer amount to bundle owner
            address bundleOwner = getRegistry().ownerOf(bundleNftId);
            PoolLib.pushUnstakingAmount(
                instanceReader,
                poolNftId, 
                bundleOwner, 
                netAmount);
        }
    }


    function fundPoolWallet(Amount amount)
        external
        virtual
        restricted()
    {
        (
            NftId poolNftId,
            IInstance instance
        ) = _getAndVerifyActivePool();

        // check that pool is externally managed
        InstanceReader reader = instance.getInstanceReader();
        if (!reader.getPoolInfo(poolNftId).isExternallyManaged) {
            revert ErrorPoolServicePoolNotExternallyManaged(poolNftId);
        }

        address poolOwner = getRegistry().ownerOf(poolNftId);
        emit LogPoolServiceWalletFunded(poolNftId, poolOwner, amount);

        PoolLib.pullStakingAmount(
            reader,
            poolNftId, 
            poolOwner, 
            amount);
    }


    function defundPoolWallet(Amount amount)
        external
        virtual
        restricted()
    {
        (
            NftId poolNftId,
            IInstance instance
        ) = _getAndVerifyActivePool();

        // check that pool is externally managed
        InstanceReader reader = instance.getInstanceReader();
        if (!reader.getPoolInfo(poolNftId).isExternallyManaged) {
            revert ErrorPoolServicePoolNotExternallyManaged(poolNftId);
        }

        address poolOwner = getRegistry().ownerOf(poolNftId);
        emit LogPoolServiceWalletDefunded(poolNftId, poolOwner, amount);

        PoolLib.pushUnstakingAmount(
            reader,
            poolNftId, 
            poolOwner, 
            amount);
    }


    function processSale(
        NftId bundleNftId, 
        IPolicy.PremiumInfo memory premium 
    ) 
        external
        virtual
        restricted()
    {
        _checkNftType(bundleNftId, BUNDLE());

        IRegistry registry = getRegistry();
        NftId poolNftId = registry.getParentNftId(bundleNftId);
        (, address instanceAddress) = ContractLib.getInfoAndInstance(registry, poolNftId, true);
        IInstance instance = IInstance(instanceAddress);

        Amount poolFeeAmount = premium.poolFeeFixAmount + premium.poolFeeVarAmount;
        Amount bundleFeeAmount = premium.bundleFeeFixAmount + premium.bundleFeeVarAmount;
        Amount bundleNetAmount = premium.netPremiumAmount;

        InstanceStore instanceStore = instance.getInstanceStore();
        PoolServiceStorage storage $ = _getPoolServiceStorage();
        $._accountingService.increasePoolBalance(
            instanceStore,
            poolNftId,
            bundleNetAmount + bundleFeeAmount, 
            poolFeeAmount);

        $._accountingService.increaseBundleBalanceForPool(
            instanceStore,
            bundleNftId,
            bundleNetAmount, 
            bundleFeeAmount);

        emit LogPoolServiceSaleProcessed(poolNftId, bundleNftId, bundleNetAmount, bundleFeeAmount, poolFeeAmount);
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
            Amount totalCollateralAmount,
            Amount localCollateralAmount
        )
    {
        _checkNftType(productNftId, PRODUCT());
        _checkNftType(applicationNftId, POLICY());
        _checkNftType(bundleNftId, BUNDLE());

        NftId poolNftId;
        bool poolIsVerifyingApplications;
        (
            poolNftId,
            totalCollateralAmount,
            localCollateralAmount,
            poolIsVerifyingApplications
        ) = PoolLib.calculateRequiredCollateral(
            instance.getInstanceReader(),
            productNftId, 
            sumInsuredAmount);

        // lock collateral amount from involved bundle
        PoolServiceStorage storage $ = _getPoolServiceStorage();
        $._bundleService.lockCollateral(
            instance,
            applicationNftId, 
            bundleNftId,
            localCollateralAmount);

        // update value locked with staking service
        $._staking.increaseTotalValueLocked(
            instance.getNftId(),
            token,
            totalCollateralAmount);

        // pool callback when required
        if (poolIsVerifyingApplications) {
            IPoolComponent pool = IPoolComponent(
                getRegistry().getObjectAddress(poolNftId));

            pool.verifyApplication(
                applicationNftId, 
                bundleNftId, 
                totalCollateralAmount);

            emit LogPoolServiceApplicationVerified(poolNftId, bundleNftId, applicationNftId, totalCollateralAmount);
        }

        emit LogPoolServiceCollateralLocked(
            poolNftId,
            bundleNftId, 
            applicationNftId, 
            totalCollateralAmount, 
            localCollateralAmount);
    }

    function processPayout(
        InstanceReader instanceReader,
        InstanceStore instanceStore, 
        NftId productNftId,
        NftId policyNftId, 
        NftId bundleNftId,
        PayoutId payoutId,
        Amount payoutAmount,
        address payoutBeneficiary
    )
        external
        virtual
        restricted()
        returns (
            Amount netPayoutAmount,
            Amount processingFeeAmount
        )
    {
        // checks
        _checkNftType(policyNftId, POLICY());

        // effects
        NftId poolNftId = getRegistry().getParentNftId(bundleNftId);
        PoolServiceStorage storage $ = _getPoolServiceStorage();
        
        $._accountingService.decreasePoolBalance(
            instanceStore,
            poolNftId,
            payoutAmount, 
            AmountLib.zero());

        $._accountingService.decreaseBundleBalanceForPool(
            instanceStore,
            bundleNftId,
            payoutAmount, 
            AmountLib.zero());

        $._bundleService.releaseCollateral(
            instanceStore, 
            policyNftId, 
            bundleNftId, 
            payoutAmount);

        // update value locked with staking service
        TokenHandler poolTokenHandler = instanceReader.getTokenHandler(poolNftId);

        $._staking.decreaseTotalValueLocked(
            instanceReader.getInstanceNftId(), 
            address(poolTokenHandler.TOKEN()),
            payoutAmount);

        // interactions
        (netPayoutAmount, processingFeeAmount) = PoolLib.transferTokenAndNotifyPolicyHolder(
            getRegistry(),
            instanceReader, 
            poolTokenHandler,
            productNftId, 
            policyNftId, 
            payoutId, 
            payoutAmount, 
            payoutBeneficiary);
        
        if (processingFeeAmount.gtz()) {
            $._accountingService.increaseProductFeesForPool(
                instanceStore,
                productNftId,
                processingFeeAmount);
        }

        emit LogPoolServicePayoutProcessed(
            poolNftId,
            bundleNftId, 
            policyNftId, 
            payoutId, 
            netPayoutAmount, 
            processingFeeAmount,
            payoutBeneficiary);
    }


    /// @inheritdoc IPoolService
    function withdrawBundleFees(
        NftId bundleNftId,
        Amount amount
    ) 
        public 
        virtual
        restricted()
        returns (Amount withdrawnAmount) 
    {
        // checks
        _checkNftType(bundleNftId, BUNDLE());

        (NftId poolNftId, IInstance instance) = _getAndVerifyActivePool();
        InstanceReader reader = instance.getInstanceReader();
        
        // determine withdrawn amount
        withdrawnAmount = amount;
        if (withdrawnAmount.gte(AmountLib.max())) {
            withdrawnAmount = reader.getFeeAmount(bundleNftId);
        } else {
            if (withdrawnAmount > reader.getFeeAmount(bundleNftId)) {
                revert ErrorPoolServiceFeesWithdrawAmountExceedsLimit(withdrawnAmount, reader.getFeeAmount(bundleNftId));
            }
        }

        // effects
        // decrease fee counters by withdrawnAmount
        {
            InstanceStore store = instance.getInstanceStore();
            PoolServiceStorage storage $ = _getPoolServiceStorage();
            // decrease fee amount of the bundle
            $._accountingService.decreaseBundleBalanceForPool(store, bundleNftId, AmountLib.zero(), withdrawnAmount);
            // decrease pool balance 
            $._accountingService.decreasePoolBalance(store, poolNftId, withdrawnAmount, AmountLib.zero());
        }

        // interactions
        // transfer amount to bundle owner
        {
            address bundleOwner = getRegistry().ownerOf(bundleNftId);
            TokenHandler tokenHandler = reader.getTokenHandler(poolNftId);
            address token = address(tokenHandler.TOKEN());
            emit LogPoolServiceFeesWithdrawn(bundleNftId, bundleOwner, token, withdrawnAmount);

            tokenHandler.pushToken(bundleOwner, withdrawnAmount);
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
        restricted()
    {
        _checkNftType(policyNftId, POLICY());

        Amount remainingCollateralAmount = policyInfo.sumInsuredAmount - policyInfo.claimAmount;

        // effects
        PoolServiceStorage storage $ = _getPoolServiceStorage();
        $._bundleService.releaseCollateral(
            instance.getInstanceStore(), 
            policyNftId, 
            policyInfo.bundleNftId, 
            remainingCollateralAmount);

        // update value locked with staking service
        InstanceReader instanceReader = instance.getInstanceReader();
        $._staking.decreaseTotalValueLocked(
            instanceReader.getInstanceNftId(),
            address(instanceReader.getToken(policyInfo.productNftId)),
            remainingCollateralAmount);

        emit LogPoolServiceCollateralReleased(
            policyInfo.bundleNftId, 
            policyNftId, 
            remainingCollateralAmount);
    }


    function _getAndVerifyActivePool()
        internal
        virtual
        view
        returns (
            NftId poolNftId,
            IInstance instance
        )
    {
        return PoolLib.getAndVerifyActivePool(getRegistry(), msg.sender);
    }

    function _getPoolServiceStorage() private pure returns (PoolServiceStorage storage $) {
        assembly {
            $.slot := POOL_SERVICE_STORAGE_LOCATION_V3_0
        }
    }


    function _getDomain() internal pure override returns(ObjectType) {
        return POOL();
    }
}