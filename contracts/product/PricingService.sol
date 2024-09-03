// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount, AmountLib} from "../type/Amount.sol";
import {ContractLib} from "../shared/ContractLib.sol";
import {Seconds} from "../type/Seconds.sol";
import {UFixed, UFixedLib} from "../type/UFixed.sol";
import {ObjectType} from "../type/ObjectType.sol";
import {NftId} from "../type/NftId.sol";
import {Fee} from "../type/Fee.sol";
import {ReferralId} from "../type/Referral.sol";
import {RiskId} from "../type/RiskId.sol";
import {PRODUCT, BUNDLE, DISTRIBUTION, PRICE} from "../type/ObjectType.sol";
import {IRegistry} from "../registry/IRegistry.sol";

import {IProductComponent} from "./IProductComponent.sol";

import {IInstance} from "../instance/IInstance.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";
import {IComponents} from "../instance/module/IComponents.sol";
import {IPolicy} from "../instance/module/IPolicy.sol";
import {IBundle} from "../instance/module/IBundle.sol";
import {IDistribution} from "../instance/module/IDistribution.sol";

import {Service} from "../shared/Service.sol";

import {IPricingService} from "./IPricingService.sol";
import {IDistributionService} from "../distribution/IDistributionService.sol";


contract PricingService is 
    Service, 
    IPricingService
{
    IDistributionService internal _distributionService;

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

        _distributionService = IDistributionService(_getServiceAddress(DISTRIBUTION()));

        _registerInterface(type(IPricingService).interfaceId);
    }

    /// @dev calculates the premium amount for the specified attributes
    /// also returns the various fee components involved with creating a policy
    function calculatePremium(
        NftId productNftId,
        RiskId riskId,
        Amount sumInsuredAmount,
        Seconds lifetime,
        bytes memory applicationData,
        NftId bundleNftId,
        ReferralId referralId
    )
        external
        view
        virtual override
        returns (
            IPolicy.PremiumInfo memory premium
        )
    {
        _checkNftType(productNftId, PRODUCT());
        _checkNftType(bundleNftId, BUNDLE());

        InstanceReader reader;
        Amount netPremiumAmount;

        {
            // verify product
            (
                IRegistry.ObjectInfo memory registryInfo, 
                address instanceAddress
            ) = ContractLib.getInfoAndInstance(getRegistry(), productNftId, false);

            // get instance reader from local instance variable
            reader = IInstance(instanceAddress).getInstanceReader();

            NftId riskProductNftId = reader.getRiskInfo(riskId).productNftId;
            if (productNftId != riskProductNftId) {
                revert ErrorPricingServiceRiskProductMismatch(riskId, riskProductNftId, productNftId);
            }

            // calculate net premium
            netPremiumAmount = IProductComponent(registryInfo.objectAddress).calculateNetPremium(
                sumInsuredAmount,
                riskId,
                lifetime,
                applicationData
            );
        }

        {
            // get configurations for all involed objects
            IComponents.ProductInfo memory productInfo = reader.getProductInfo(productNftId);
            IComponents.FeeInfo memory feeInfo = reader.getFeeInfo(productNftId);

            IBundle.BundleInfo memory bundleInfo = reader.getBundleInfo(bundleNftId);
            if(bundleInfo.poolNftId != productInfo.poolNftId) {
                revert ErrorPricingServiceBundlePoolMismatch(bundleNftId, bundleInfo.poolNftId, productInfo.poolNftId);
            }

            // calculate fixed fees for product, pool, bundle
            premium = _getFixedFeeAmounts(
                netPremiumAmount,
                feeInfo,
                bundleInfo
            );

            // calculate variable fees for product, pool, bundle
            premium = _calculateVariableFeeAmounts(
                premium,
                feeInfo,
                bundleInfo
            );

            // calculate distribution fee and (if applicable) commission
            premium = _calculateDistributionOwnerFeeAmount(
                premium,
                feeInfo,
                productInfo.distributionNftId,
                referralId,
                reader
            );

            // calculate resulting amounts for product, pool, and distribution wallets
            premium = _calculateTargetWalletAmounts(premium);

            // sanity check to validate the fee calculation
            if(premium.premiumAmount != premium.productFeeAmount 
                + premium.distributionFeeAndCommissionAmount 
                + premium.poolPremiumAndFeeAmount)
            {
                revert ErrorPricingServiceTargetWalletAmountsMismatch();
            }

            if (premium.distributionOwnerFeeFixAmount < feeInfo.minDistributionOwnerFee.fixedFee) {
                revert ErrorPricingServiceFeeCalculationMismatch( 
                    premium.distributionFeeFixAmount,
                    premium.distributionFeeVarAmount,
                    premium.distributionOwnerFeeFixAmount,
                    premium.distributionOwnerFeeVarAmount,
                    premium.commissionAmount,
                    premium.discountAmount
                );
            }

            if ((premium.distributionFeeVarAmount) != (premium.discountAmount + premium.distributionOwnerFeeVarAmount + premium.commissionAmount)) {
                revert ErrorPricingServiceFeeCalculationMismatch(
                    premium.distributionFeeFixAmount,
                    premium.distributionFeeVarAmount,
                    premium.distributionOwnerFeeFixAmount,
                    premium.distributionOwnerFeeVarAmount,
                    premium.commissionAmount,
                    premium.discountAmount
                );
            }
        }
    }

    // internal functions
    function _getFixedFeeAmounts(
        Amount netPremiumAmount,
        IComponents.FeeInfo memory feeInfo,
        IBundle.BundleInfo memory bundleInfo
    )
        internal
        pure
        returns (
            IPolicy.PremiumInfo memory premium
        )
    {
        // initial premium amount is the net premium
        premium.netPremiumAmount = netPremiumAmount;
        premium.fullPremiumAmount = netPremiumAmount;

        Amount t = feeInfo.productFee.fixedFee;
        premium.productFeeFixAmount = t;
        premium.fullPremiumAmount = premium.fullPremiumAmount + t;

        t = feeInfo.poolFee.fixedFee;
        premium.poolFeeFixAmount = t;
        premium.fullPremiumAmount = premium.fullPremiumAmount + t;

        t = bundleInfo.fee.fixedFee;
        premium.bundleFeeFixAmount = t;
        premium.fullPremiumAmount = premium.fullPremiumAmount + t;

        t = feeInfo.distributionFee.fixedFee;
        premium.distributionFeeFixAmount = t;
        premium.fullPremiumAmount = premium.fullPremiumAmount + t;
    }

    function _calculateVariableFeeAmounts(
        IPolicy.PremiumInfo memory premium,
        IComponents.FeeInfo memory feeInfo,
        IBundle.BundleInfo memory bundleInfo
    )
        internal
        pure
        returns (
            IPolicy.PremiumInfo memory intermadiatePremium
        )
    {
        Amount netPremiumAmount = premium.netPremiumAmount;

        Amount t = netPremiumAmount.multiplyWith(feeInfo.productFee.fractionalFee);
        premium.productFeeVarAmount = t;
        premium.fullPremiumAmount = premium.fullPremiumAmount + t;

        t = netPremiumAmount.multiplyWith(feeInfo.poolFee.fractionalFee);
        premium.poolFeeVarAmount = t;
        premium.fullPremiumAmount = premium.fullPremiumAmount + t;

        t = netPremiumAmount.multiplyWith(bundleInfo.fee.fractionalFee);
        premium.bundleFeeVarAmount = t;
        premium.fullPremiumAmount = premium.fullPremiumAmount + t;

        t = netPremiumAmount.multiplyWith(feeInfo.distributionFee.fractionalFee);
        premium.distributionFeeVarAmount = t;
        premium.fullPremiumAmount = premium.fullPremiumAmount + t;

        return premium;
    }

    function _calculateDistributionOwnerFeeAmount(
        IPolicy.PremiumInfo memory premium,
        IComponents.FeeInfo memory feeInfo,
        NftId distributionNftId,
        // ISetup.DistributionSetupInfo memory distInfo,
        ReferralId referralId,
        InstanceReader reader
    )
        internal
        view 
        returns (IPolicy.PremiumInfo memory finalPremium)
    {

        // if the referral is not valid, then the distribution owner gets everything
        if (distributionNftId.eqz() || ! _distributionService.referralIsValid(distributionNftId, referralId)) {
            premium.distributionOwnerFeeFixAmount = premium.distributionFeeFixAmount;
            premium.distributionOwnerFeeVarAmount = premium.distributionFeeVarAmount;
            premium.premiumAmount = premium.fullPremiumAmount;
            return premium;
        }

        Fee memory minDistributionOwnerFee = feeInfo.minDistributionOwnerFee;

        // if the referral is valid, the the commission and discount are calculated based in the full premium
        // the remaing amount goes to the distribution owner
        {
            IDistribution.ReferralInfo memory referralInfo = reader.getReferralInfo(referralId);
            IDistribution.DistributorInfo memory distributorInfo = reader.getDistributorInfo(referralInfo.distributorNftId);
            IDistribution.DistributorTypeInfo memory distributorTypeInfo = reader.getDistributorTypeInfo(distributorInfo.distributorType);

            Amount commissionAmount = premium.netPremiumAmount.multiplyWith(distributorTypeInfo.commissionPercentage);
            premium.commissionAmount = commissionAmount;
            premium.discountAmount = premium.fullPremiumAmount.multiplyWith(referralInfo.discountPercentage);
            premium.distributionOwnerFeeFixAmount = minDistributionOwnerFee.fixedFee;
            premium.distributionOwnerFeeVarAmount = premium.distributionFeeVarAmount - commissionAmount - premium.discountAmount;
            premium.premiumAmount = premium.fullPremiumAmount - premium.discountAmount;
        }

        return premium; 
    }


    function _calculateTargetWalletAmounts(
        IPolicy.PremiumInfo memory premium
    )
        internal
        virtual
        view
        returns (
            IPolicy.PremiumInfo memory premiumWithTargetWalletAmounts
        )
    {
        // fees for product owner
        premium.productFeeAmount = premium.productFeeFixAmount + premium.productFeeVarAmount;

        // fees for distribution owner + distributor commission
        premium.distributionFeeAndCommissionAmount = 
            premium.distributionFeeFixAmount + premium.distributionOwnerFeeVarAmount 
            + premium.commissionAmount;

        // net premium + fees for pool owner + bundle owner
        premium.poolPremiumAndFeeAmount = premium.netPremiumAmount 
            + premium.poolFeeFixAmount + premium.poolFeeVarAmount 
            + premium.bundleFeeFixAmount + premium.bundleFeeVarAmount;

        premiumWithTargetWalletAmounts = premium;
    }


    function _getDomain() internal pure override returns(ObjectType) {
        return PRICE();
    }
}