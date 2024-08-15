// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccountingService} from "../accounting/IAccountingService.sol";
import {IBundle} from "../instance/module/IBundle.sol";
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
import {Fee, FeeLib} from "../type/Fee.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType, ACCOUNTING, POOL, BUNDLE, PRODUCT, POLICY, COMPONENT} from "../type/ObjectType.sol";
import {Fee, FeeLib} from "../type/Fee.sol";
import {KEEP_STATE} from "../type/StateId.sol";
import {UFixed} from "../type/UFixed.sol";
import {Service} from "../shared/Service.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";
import {InstanceStore} from "../instance/InstanceStore.sol";

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
            address registryAddress,
            address authority
        ) = abi.decode(data, (address, address));

        _initializeService(registryAddress, authority, owner);

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
            poolComponentInfo.tokenHandler.distributeTokens(
                poolComponentInfo.tokenHandler.getWallet(), 
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
        virtual
    {
        _checkNftType(policyNftId, POLICY());

        (NftId poolNftId, IInstance instance) = _getAndVerifyActivePool();
        InstanceReader instanceReader = instance.getInstanceReader();
        NftId productNftId = getRegistry().getObjectInfo(poolNftId).parentNftId;

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


    /// @inheritdoc IPoolService
    function stake(NftId bundleNftId, Amount amount) 
        external 
        virtual
        // TODO: restricted() (once #462 is done)
        returns(Amount netAmount) 
    {
        _checkNftType(bundleNftId, BUNDLE());

        (NftId poolNftId, IInstance instance) = _getAndVerifyActivePool();
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
        IRegistry registry = getRegistry();
        Amount feeAmount;

        {
            NftId productNftId = registry.getObjectInfo(poolNftId).parentNftId;
            Fee memory stakingFee = instanceReader.getProductInfo(productNftId).stakingFee;
            (
                feeAmount,
                netAmount
            ) = FeeLib.calculateFee(
                stakingFee, 
                amount);
        }

        // do all the book keeping
        _accountingService.increasePoolBalance(
            instance.getInstanceStore(), 
            poolNftId, 
            netAmount, 
            feeAmount);

        _bundleService.stake(instance, bundleNftId, netAmount);

        emit LogPoolServiceBundleStaked(instance.getNftId(), poolNftId, bundleNftId, amount, netAmount);

        // only collect staking amount when pool is not externally managed
        if (!poolInfo.isExternallyManaged) {

            // collect tokens from bundle owner
            address bundleOwner = getRegistry().ownerOf(bundleNftId);
            _collectStakingAmount(
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
        // TODO: restricted() (once #462 is done)
        returns(Amount netAmount) 
    {
        _checkNftType(bundleNftId, BUNDLE());

        (NftId poolNftId, IInstance instance) = _getAndVerifyActivePool();
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
        netAmount = unstakedAmount;

        // update pool bookkeeping - performance fees stay in the pool, but as fees 
        _accountingService.decreasePoolBalance(
            instanceStore, 
            poolNftId, 
            unstakedAmount, 
            AmountLib.zero());


        emit LogPoolServiceBundleUnstaked(instance.getNftId(), poolNftId, bundleNftId, unstakedAmount, netAmount);

        // only distribute staking amount when pool is not externally managed
        if (!instanceReader.getPoolInfo(poolNftId).isExternallyManaged) {

            // transfer amount to bundle owner
            address bundleOwner = getRegistry().ownerOf(bundleNftId);
            _distributeUnstakingAmount(
                instanceReader,
                poolNftId, 
                bundleOwner, 
                netAmount);
        }
    }


    function fundPoolWallet(Amount amount)
        external
        virtual
        // restricted()
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

        _collectStakingAmount(
            reader,
            poolNftId, 
            poolOwner, 
            amount);
    }


    function defundPoolWallet(Amount amount)
        external
        virtual
        // restricted()
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

        _distributeUnstakingAmount(
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
        NftId poolNftId = registry.getObjectInfo(bundleNftId).parentNftId;
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

        _accountingService.increaseBundleBalance(
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
        _checkNftType(policyNftId, POLICY());

        NftId bundleNftId = policyInfo.bundleNftId;
        NftId poolNftId = getRegistry().getObjectInfo(bundleNftId).parentNftId;
        InstanceStore instanceStore = instance.getInstanceStore();
        
        _accountingService.decreasePoolBalance(
            instanceStore,
            poolNftId,
            payoutAmount, 
            AmountLib.zero());

        _accountingService.decreaseBundleBalance(
            instanceStore,
            bundleNftId,
            payoutAmount, 
            AmountLib.zero());

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
        _checkNftType(policyNftId, POLICY());

        Amount remainingCollateralAmount = policyInfo.sumInsuredAmount - policyInfo.claimAmount;

        _bundleService.releaseCollateral(
            instance, 
            policyNftId, 
            policyInfo.bundleNftId, 
            remainingCollateralAmount);

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
            NftId poolNftId,
            Amount totalCollateralAmount,
            Amount localCollateralAmount,
            bool poolIsVerifyingApplications
        )
    {
        _checkNftType(productNftId, PRODUCT());

        poolNftId = instanceReader.getProductInfo(productNftId).poolNftId;
        IComponents.PoolInfo memory poolInfo = instanceReader.getPoolInfo(poolNftId);
        poolIsVerifyingApplications = poolInfo.isVerifyingApplications;

        (
            totalCollateralAmount,
            localCollateralAmount
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
            Amount totalCollateralAmount,
            Amount localCollateralAmount
        )
    {
        // collateralization is applied to sum insured
        UFixed totalUFixed = collateralizationLevel * sumInsuredAmount.toUFixed();
        totalCollateralAmount = AmountLib.toAmount(totalUFixed.toInt());

        // retention level defines how much capital is required locally
        localCollateralAmount = AmountLib.toAmount(
            (retentionLevel * totalUFixed).toInt());
    }


    function _processStakingFees(
        Fee memory stakingFee, 
        Amount stakingAmount
    )
        internal
        pure
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


    /// @dev transfers the specified amount from the "from account" to the pool's wallet
    function _collectStakingAmount(
        InstanceReader reader,
        NftId poolNftId,
        address from,
        Amount amount
    )
        internal
    {
        IComponents.ComponentInfo memory info = reader.getComponentInfo(poolNftId);
        info.tokenHandler.collectTokens(
            from,
            amount);
    }

    /// @dev distributes the specified amount from the pool's wallet to the "to account"
    function _distributeUnstakingAmount(
        InstanceReader reader,
        NftId poolNftId,
        address to,
        Amount amount
    )
        internal
    {
        IComponents.ComponentInfo memory info = reader.getComponentInfo(poolNftId);
        info.tokenHandler.distributeTokens(
            info.tokenHandler.getWallet(), 
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
        (
            IRegistry.ObjectInfo memory info, 
            address instanceAddress
        ) = ContractLib.getAndVerifyComponent(
            getRegistry(), 
            msg.sender,
            POOL(),
            true); // only active pools

        poolNftId = info.nftId;
        instance = IInstance(instanceAddress);
    }


    function _getDomain() internal pure override returns(ObjectType) {
        return POOL();
    }
}