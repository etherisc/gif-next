// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccountingService} from "../accounting/IAccountingService.sol";
import {IBundle} from "../instance/module/IBundle.sol";
import {IBundleService} from "./IBundleService.sol";
import {IComponents} from "../instance/module/IComponents.sol";
import {IComponentService} from "../shared/IComponentService.sol";
import {IInstance} from "../instance/IInstance.sol";
import {IPolicy} from "../instance/module/IPolicy.sol";
import {IPolicyHolder} from "../shared/IPolicyHolder.sol";
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
import {UFixed} from "../type/UFixed.sol";

string constant POOL_SERVICE_NAME = "PoolService";


contract PoolService is 
    Service, 
    IPoolService 
{
    IAccountingService private _accountingService;
    IBundleService internal _bundleService;
    IComponentService internal _componentService;
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
            address authority,
            address registry
        ) = abi.decode(data, (address, address));

        __Service_init(authority, registry, owner);

        _accountingService = IAccountingService(_getServiceAddress(ACCOUNTING()));
        _bundleService = IBundleService(_getServiceAddress(BUNDLE()));
        _componentService = IComponentService(_getServiceAddress(COMPONENT()));
        _staking = IStaking(getRegistry().getStakingAddress());

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
        (Amount unstakedAmount, Amount feeAmount) = _bundleService.close(instance, bundleNftId);

        _accountingService.decreasePoolBalance(
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

        // check policy matches with calling pool
        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
        if(policyInfo.productNftId != productNftId) {
            revert ErrorPoolServicePolicyPoolMismatch(
                policyNftId, 
                policyInfo.productNftId, 
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
        _accountingService.increasePoolBalance(
            instanceStore, 
            poolNftId, 
            netAmount, 
            feeAmount);

        _bundleService.stake(instanceReader, instanceStore, bundleNftId, netAmount);

        emit LogPoolServiceBundleStaked(instanceNftId, poolNftId, bundleNftId, amount, netAmount);

        // only collect staking amount when pool is not externally managed
        if (!poolInfo.isExternallyManaged) {

            // collect tokens from bundle owner
            address bundleOwner = getRegistry().ownerOf(bundleNftId);
            _pullStakingAmount(
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
        Amount unstakedAmount = _bundleService.unstake(instanceStore, bundleNftId, amount);

        // Important: from now on work only with unstakedAmount as it is the only reliable amount.
        // if amount was max, this was set to the available amount

        // TODO: handle performance fees (issue #477)
        netAmount = unstakedAmount;

        // update pool bookkeeping - performance fees stay in the pool, but as fees 
        _accountingService.decreasePoolBalance(
            instanceStore, 
            poolNftId, 
            unstakedAmount, 
            AmountLib.zero());


        emit LogPoolServiceBundleUnstaked(instanceNftId, poolNftId, bundleNftId, unstakedAmount, netAmount);

        // only distribute staking amount when pool is not externally managed
        if (!instanceReader.getPoolInfo(poolNftId).isExternallyManaged) {

            // transfer amount to bundle owner
            address bundleOwner = getRegistry().ownerOf(bundleNftId);
            _pushUnstakingAmount(
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

        _pullStakingAmount(
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

        _pushUnstakingAmount(
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
        _accountingService.increasePoolBalance(
            instanceStore,
            poolNftId,
            bundleNetAmount + bundleFeeAmount, 
            poolFeeAmount);

        _accountingService.increaseBundleBalanceForPool(
            instanceStore,
            bundleNftId,
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

        // pool callback when required
        if (poolIsVerifyingApplications) {
            IPoolComponent pool = IPoolComponent(
                getRegistry().getObjectAddress(poolNftId));

            pool.verifyApplication(
                applicationNftId, 
                bundleNftId, 
                totalCollateralAmount);

            // TODO add logging
        }

        // TODO add logging
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
    {
        // checks
        _checkNftType(policyNftId, POLICY());

        // effects
        NftId poolNftId = getRegistry().getParentNftId(bundleNftId);
        
        _accountingService.decreasePoolBalance(
            instanceStore,
            poolNftId,
            payoutAmount, 
            AmountLib.zero());

        _accountingService.decreaseBundleBalanceForPool(
            instanceStore,
            bundleNftId,
            payoutAmount, 
            AmountLib.zero());

        _bundleService.releaseCollateral(
            instanceStore, 
            policyNftId, 
            bundleNftId, 
            payoutAmount);

        // update value locked with staking service
        TokenHandler poolTokenHandler = TokenHandler(
            instanceReader.getTokenHandler(
                poolNftId));

        _staking.decreaseTotalValueLocked(
            instanceReader.getInstanceNftId(), 
            address(poolTokenHandler.TOKEN()),
            payoutAmount);

        // interactions
        _transferTokenAndNotifyPolicyHolder(
            instanceReader, 
            poolTokenHandler,
            productNftId, 
            policyNftId, 
            payoutId, 
            payoutAmount, 
            payoutBeneficiary);
    }

    function _transferTokenAndNotifyPolicyHolder(
        InstanceReader instanceReader,
        TokenHandler poolTokenHandler,
        NftId productNftId,
        NftId policyNftId,
        PayoutId payoutId,
        Amount payoutAmount,
        address payoutBeneficiary
    )
        internal
    {
        (
            Amount netPayoutAmount,
            Amount processingFeeAmount,
            address beneficiary
        ) = PoolLib.calculatePayoutAmounts(
            getRegistry(),
            instanceReader,
            productNftId, 
            policyNftId,
            payoutAmount,
            payoutBeneficiary);

        // 1st token tx to payout to beneficiary
        poolTokenHandler.pushToken(
            beneficiary, 
            netPayoutAmount);

        // 2nd token tx to transfer processing fees to product wallet
        // if processingFeeAmount > 0
        if (processingFeeAmount.gtz()) {
            poolTokenHandler.pushToken(
                instanceReader.getWallet(productNftId), 
                processingFeeAmount);
        }

        // callback to policy holder if applicable
        _policyHolderPayoutExecuted(
            policyNftId, 
            payoutId, 
            beneficiary, 
            netPayoutAmount);
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
            // decrease fee amount of the bundle
            _accountingService.decreaseBundleBalanceForPool(store, bundleNftId, AmountLib.zero(), withdrawnAmount);
            // decrease pool balance 
            _accountingService.decreasePoolBalance(store, poolNftId, withdrawnAmount, AmountLib.zero());
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

        _bundleService.releaseCollateral(
            instance.getInstanceStore(), 
            policyNftId, 
            policyInfo.bundleNftId, 
            remainingCollateralAmount);

        // update value locked with staking service
        InstanceReader instanceReader = instance.getInstanceReader();
        _staking.decreaseTotalValueLocked(
            instanceReader.getInstanceNftId(),
            address(instanceReader.getToken(policyInfo.productNftId)),
            remainingCollateralAmount);
    }


    // function calculateRequiredCollateral(
    //     InstanceReader instanceReader,
    //     NftId productNftId, 
    //     Amount sumInsuredAmount
    // )
    //     public
    //     view 
    //     returns(
    //         NftId poolNftId,
    //         Amount totalCollateralAmount,
    //         Amount localCollateralAmount,
    //         bool poolIsVerifyingApplications
    //     )
    // {
    //     return CollateralLib.calculateRequiredCollateral(
    //         instanceReader,
    //         productNftId, 
    //         sumInsuredAmount);
    // }

    //     _checkNftType(productNftId, PRODUCT());

    //     poolNftId = instanceReader.getProductInfo(productNftId).poolNftId;
    //     IComponents.PoolInfo memory poolInfo = instanceReader.getPoolInfo(poolNftId);
    //     poolIsVerifyingApplications = poolInfo.isVerifyingApplications;

    //     (
    //         totalCollateralAmount,
    //         localCollateralAmount
    //     ) = calculateRequiredCollateral(
    //         poolInfo.collateralizationLevel,
    //         poolInfo.retentionLevel,
    //         sumInsuredAmount);
    // }


    // function calculateRequiredCollateral(
    //     UFixed collateralizationLevel, 
    //     UFixed retentionLevel, 
    //     Amount sumInsuredAmount
    // )
    //     public
    //     pure 
    //     returns(
    //         Amount totalCollateralAmount,
    //         Amount localCollateralAmount
    //     )
    // {
    //     // collateralization is applied to sum insured
    //     UFixed totalUFixed = collateralizationLevel * sumInsuredAmount.toUFixed();
    //     totalCollateralAmount = AmountLib.toAmount(totalUFixed.toInt());

    //     // retention level defines how much capital is required locally
    //     localCollateralAmount = AmountLib.toAmount(
    //         (retentionLevel * totalUFixed).toInt());
    // }




    function _policyHolderPayoutExecuted(
        NftId policyNftId, 
        PayoutId payoutId,
        address beneficiary,
        Amount payoutAmount
    )
        internal
    {
        IPolicyHolder policyHolder = PoolLib.getPolicyHolder(getRegistry(), policyNftId);
        if(address(policyHolder) != address(0)) {
            policyHolder.payoutExecuted(policyNftId, payoutId, payoutAmount, beneficiary);
        }
    }


    /// @dev Transfers the specified amount from the "from account" to the pool's wallet
    function _pullStakingAmount(
        InstanceReader reader,
        NftId poolNftId,
        address from,
        Amount amount
    )
        internal
    {
        IComponents.ComponentInfo memory info = reader.getComponentInfo(poolNftId);
        info.tokenHandler.pullToken(
            from,
            amount);
    }

    /// @dev Transfers the specified amount from the pool's wallet to the "to account"
    function _pushUnstakingAmount(
        InstanceReader reader,
        NftId poolNftId,
        address to,
        Amount amount
    )
        internal
    {
        IComponents.ComponentInfo memory info = reader.getComponentInfo(poolNftId);
        info.tokenHandler.pushToken(
            to, 
            amount);
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

    // function _getAndVerifyActivePool()
    //     internal
    //     virtual
    //     view
    //     returns (
    //         NftId poolNftId,
    //         IInstance instance
    //     )
    // {
    //     (
    //         IRegistry.ObjectInfo memory info, 
    //         address instanceAddress
    //     ) = ContractLib.getAndVerifyComponent(
    //         getRegistry(), 
    //         msg.sender,
    //         POOL(),
    //         true); // only active pools

    //     poolNftId = info.nftId;
    //     instance = IInstance(instanceAddress);
    // }


    function _getDomain() internal pure override returns(ObjectType) {
        return POOL();
    }
}