// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IComponents} from "../instance/module/IComponents.sol";
import {IInstance} from "../instance/IInstance.sol";
import {INftOwnable} from "../shared/INftOwnable.sol";
import {IPolicyHolder} from "../shared/IPolicyHolder.sol";
import {IPoolService} from "./IPoolService.sol";
import {IRegistry} from "../registry/IRegistry.sol";

import {Amount, AmountLib} from "../type/Amount.sol";
import {ContractLib} from "../shared/ContractLib.sol";
import {Fee, FeeLib} from "../type/Fee.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";
import {InstanceStore} from "../instance/InstanceStore.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType, BUNDLE, POOL} from "../type/ObjectType.sol";
import {PayoutId} from "../type/PayoutId.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";
import {UFixed} from "../type/UFixed.sol";

library PoolLib {

    /// @dev Calulate required collateral for the provided parameters.
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


    /// @dev calulate required collateral for the provided parameters.
    /// Collateralization is applied to sum insured.
    /// Retention level defines the fraction of the collateral that is required locally.
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


    function calculateStakingAmounts(
        IRegistry registry,
        InstanceReader instanceReader,
        NftId poolNftId,
        Amount stakingAmount
    )
        public
        view
        returns (
            Amount feeAmount,
            Amount netStakingAmount
        )
    {
        NftId productNftId = registry.getParentNftId(poolNftId);
        Fee memory stakingFee = instanceReader.getFeeInfo(productNftId).stakingFee;
        (
            feeAmount,
            netStakingAmount
        ) = FeeLib.calculateFee(
            stakingFee, 
            stakingAmount);
    }


    function calculatePayoutAmounts(
        IRegistry registry,
        InstanceReader instanceReader,
        NftId productNftId,
        NftId policyNftId,
        Amount payoutAmount,
        address payoutBeneficiary
    )
        public
        view
        returns (
            Amount netPayoutAmount,
            Amount processingFeeAmount,
            address beneficiary
        )
    {
        // Amount payoutAmount = payoutInfo.amount;

        if(payoutAmount.gtz()) {
            netPayoutAmount = payoutAmount;

            if (payoutBeneficiary == address(0)) {
                beneficiary = registry.ownerOf(policyNftId);
            } else { 
                beneficiary = payoutBeneficiary;
            }

            // calculate processing fees if applicable
            IComponents.FeeInfo memory feeInfo = instanceReader.getFeeInfo(productNftId);
            if(FeeLib.gtz(feeInfo.processingFee)) {
                (processingFeeAmount, netPayoutAmount) = FeeLib.calculateFee(feeInfo.processingFee, payoutAmount);
            }
        }
    }


    function getPolicyHolder(
        IRegistry registry, 
        NftId policyNftId
    )
        internal 
        view 
        returns (IPolicyHolder policyHolder)
    {
        address policyHolderAddress = registry.ownerOf(policyNftId);
        policyHolder = IPolicyHolder(policyHolderAddress);

        if (!ContractLib.isPolicyHolder(policyHolderAddress)) {
            policyHolder = IPolicyHolder(address(0));
        }
    }


    function checkAndGetPoolInfo(
        IRegistry registry,
        address sender,
        NftId bundleNftId
    )
        public
        view
        returns (
            InstanceReader instanceReader,
            InstanceStore instanceStore,
            NftId instanceNftId,
            NftId poolNftId,
            IComponents.PoolInfo memory poolInfo
        )
    {
        checkNftType(registry, bundleNftId, BUNDLE());

        IInstance instance;
        (poolNftId, instance) = getAndVerifyActivePool(registry, sender);
        instanceReader = instance.getInstanceReader();
        instanceStore = instance.getInstanceStore();
        instanceNftId = instance.getNftId();
        poolInfo = instanceReader.getPoolInfo(poolNftId);

        if (registry.getParentNftId(bundleNftId) != poolNftId) {
            revert IPoolService.ErrorPoolServiceBundlePoolMismatch(bundleNftId, poolNftId);
        }
    }


    function getAndVerifyActivePool(
        IRegistry registry,
        address sender
    )
        public
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
            registry, 
            sender,
            POOL(),
            true); // only active pools

        poolNftId = info.nftId;
        instance = IInstance(instanceAddress);
    }


    function getAndVerifyActiveComponent(
        IRegistry registry,
        address sender,
        ObjectType expectedComponentType
    )
        public
        view
        returns (
            NftId componentNftId,
            IInstance instance
        )
    {
        (
            IRegistry.ObjectInfo memory info, 
            address instanceAddress
        ) = ContractLib.getAndVerifyComponent(
            registry, 
            sender,
            expectedComponentType,
            true); // only active components

        componentNftId = info.nftId;
        instance = IInstance(instanceAddress);
    }


    function getInstanceForComponent(
        IRegistry registry,
        NftId componentNftId
    )
        public
        view
        returns (
            IInstance instance
        )
    {
        NftId productNftId = registry.getParentNftId(componentNftId);
        NftId instanceNftId = registry.getParentNftId(productNftId);
        address instanceAddress = registry.getObjectAddress(instanceNftId);
        return IInstance(instanceAddress);
    }


    function checkNftType(
        IRegistry registry, 
        NftId nftId, 
        ObjectType expectedObjectType
    ) internal view {
        if(!registry.isObjectType(nftId, expectedObjectType)) {
            revert INftOwnable.ErrorNftOwnableInvalidType(nftId, expectedObjectType);
        }
    }

    function transferTokenAndNotifyPolicyHolder(
        IRegistry registry,
        InstanceReader instanceReader,
        TokenHandler poolTokenHandler,
        NftId productNftId,
        NftId policyNftId,
        PayoutId payoutId,
        Amount payoutAmount,
        address payoutBeneficiary
    )
        external
        returns (
            Amount netPayoutAmount,
            Amount processingFeeAmount
        )
    {
        address beneficiary;

        (
            netPayoutAmount,
            processingFeeAmount,
            beneficiary
        ) = calculatePayoutAmounts(
            registry,
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
        policyHolderPayoutExecuted(
            registry,
            policyNftId, 
            payoutId, 
            beneficiary, 
            netPayoutAmount);
    }

    function policyHolderPayoutExecuted(
        IRegistry registry,
        NftId policyNftId, 
        PayoutId payoutId,
        address beneficiary,
        Amount payoutAmount
    )
        private
    {
        IPolicyHolder policyHolder = getPolicyHolder(registry, policyNftId);
        if(address(policyHolder) != address(0)) {
            policyHolder.payoutExecuted(policyNftId, payoutId, payoutAmount, beneficiary);
        }
    }

    /// @dev Transfers the specified amount from the "from account" to the pool's wallet
    function pullStakingAmount(
        InstanceReader reader,
        NftId poolNftId,
        address from,
        Amount amount
    )
        external
    {
        IComponents.ComponentInfo memory info = reader.getComponentInfo(poolNftId);
        info.tokenHandler.pullToken(
            from,
            amount);
    }

    /// @dev Transfers the specified amount from the pool's wallet to the "to account"
    function pushUnstakingAmount(
        InstanceReader reader,
        NftId poolNftId,
        address to,
        Amount amount
    )
        external
    {
        IComponents.ComponentInfo memory info = reader.getComponentInfo(poolNftId);
        info.tokenHandler.pushToken(
            to, 
            amount);
    }
}
