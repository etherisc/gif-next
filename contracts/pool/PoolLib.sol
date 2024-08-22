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
        external
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
                // TODO calculate and set net payout and processing fees
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

    function checkNftType(
        IRegistry registry, 
        NftId nftId, 
        ObjectType expectedObjectType
    ) internal view {
        if(!registry.isObjectType(nftId, expectedObjectType)) {
            revert INftOwnable.ErrorNftOwnableInvalidType(nftId, expectedObjectType);
        }
    }
}