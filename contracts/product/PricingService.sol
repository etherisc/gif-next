// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount, AmountLib} from "../type/Amount.sol";
import {Seconds} from "../type/Seconds.sol";
import {UFixed, UFixedLib} from "../type/UFixed.sol";
import {ObjectType} from "../type/ObjectType.sol";
import {NftId} from "../type/NftId.sol";
import {Fee} from "../type/Fee.sol";
import {ReferralId} from "../type/Referral.sol";
import {RiskId} from "../type/RiskId.sol";
import {PRODUCT, DISTRIBUTION, PRICE} from "../type/ObjectType.sol";
import {IRegistry} from "../registry/IRegistry.sol";

import {IProductComponent} from "./IProductComponent.sol";

import {IInstance} from "../instance/IInstance.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";
import {IComponents} from "../instance/module/IComponents.sol";
import {IPolicy} from "../instance/module/IPolicy.sol";
import {IBundle} from "../instance/module/IBundle.sol";
import {IDistribution} from "../instance/module/IDistribution.sol";

import {ComponentVerifyingService} from "../shared/ComponentVerifyingService.sol";

import {IPricingService} from "./IPricingService.sol";
import {IDistributionService} from "../distribution/IDistributionService.sol";


contract PricingService is 
    ComponentVerifyingService, 
    IPricingService
{
    using UFixedLib for UFixed;

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
            address registryAddress,, 
            //address managerAddress
            address authority
        ) = abi.decode(data, (address, address, address));

        initializeService(registryAddress, authority, owner);
        registerInterface(type(IPricingService).interfaceId);

        _distributionService = IDistributionService(_getServiceAddress(DISTRIBUTION()));
    }


    function getDomain() public pure override returns(ObjectType) {
        return PRICE();
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
            IPolicy.Premium memory premium
        )
    {
        InstanceReader reader;
        Amount netPremiumAmount;

        {
            // verify product
            (
                IRegistry.ObjectInfo memory registryInfo, 
                IInstance instance
            ) = _getAndVerifyComponentInfo(productNftId, PRODUCT(), false);

            reader = instance.getInstanceReader();

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

            IBundle.BundleInfo memory bundleInfo = reader.getBundleInfo(bundleNftId);
            if(bundleInfo.poolNftId != productInfo.poolNftId) {
                revert ErrorIPricingServiceBundlePoolMismatch(bundleNftId, bundleInfo.poolNftId, productInfo.poolNftId);
            }

            // calculate premium, order is important
            premium = _getFixedFeeAmounts(
                netPremiumAmount,
                productInfo,
                bundleInfo
            );

            premium = _calculateVariableFeeAmounts(
                premium,
                productInfo,
                bundleInfo
            );

            premium = _calculateDistributionOwnerFeeAmount(
                premium,
                productInfo,
                referralId,
                reader
            );

            premium = _calculateTargetWalletAmounts(premium);

            // sanity check to validate the fee calculation
            if(AmountLib.toAmount(premium.premiumAmount) != 
                premium.productFeeAmount 
                + premium.distributionFeeAndCommissionAmount 
                + premium.poolPremiumAndFeeAmount)
            {
                revert ErrorPricingServiceTargetWalletAmountsMismatch();
            }

            if (premium.distributionOwnerFeeFixAmount < productInfo.minDistributionOwnerFee.fixedFee) {
                revert ErrorIPricingServiceFeeCalculationMismatch( 
                    premium.distributionFeeFixAmount,
                    premium.distributionFeeVarAmount,
                    premium.distributionOwnerFeeFixAmount,
                    premium.distributionOwnerFeeVarAmount,
                    premium.commissionAmount,
                    premium.discountAmount
                );
            }

            if ((premium.distributionFeeVarAmount) != (premium.discountAmount + premium.distributionOwnerFeeVarAmount + premium.commissionAmount)) {
                revert ErrorIPricingServiceFeeCalculationMismatch(
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
        IComponents.ProductInfo memory productInfo,
        IBundle.BundleInfo memory bundleInfo
    )
        internal
        pure
        returns (
            IPolicy.Premium memory premium
        )
    {
        // initial premium amount is the net premium
        premium.netPremiumAmount = netPremiumAmount.toInt();
        premium.fullPremiumAmount = netPremiumAmount.toInt();

        uint256 t = productInfo.productFee.fixedFee;
        premium.productFeeFixAmount = t;
        premium.fullPremiumAmount += t;

        t = productInfo.poolFee.fixedFee;
        premium.poolFeeFixAmount = t;
        premium.fullPremiumAmount += t;

        t = bundleInfo.fee.fixedFee;
        premium.bundleFeeFixAmount = t;
        premium.fullPremiumAmount += t;

        t = productInfo.distributionFee.fixedFee;
        premium.distributionFeeFixAmount = t;
        premium.fullPremiumAmount += t;
    }

    function _calculateVariableFeeAmounts(
        IPolicy.Premium memory premium,
        IComponents.ProductInfo memory productInfo,
        IBundle.BundleInfo memory bundleInfo
    )
        internal
        pure
        returns (
            IPolicy.Premium memory intermadiatePremium
        )
    {
        UFixed netPremiumAmount = UFixedLib.toUFixed(premium.netPremiumAmount);

        uint256 t = (netPremiumAmount * productInfo.productFee.fractionalFee).toInt();
        premium.productFeeVarAmount = t;
        premium.fullPremiumAmount += t;

        t = (netPremiumAmount * productInfo.poolFee.fractionalFee).toInt();
        premium.poolFeeVarAmount = t;
        premium.fullPremiumAmount += t;

        t = (netPremiumAmount * bundleInfo.fee.fractionalFee).toInt();
        premium.bundleFeeVarAmount = t;
        premium.fullPremiumAmount += t;

        t = (netPremiumAmount * productInfo.distributionFee.fractionalFee).toInt();
        premium.distributionFeeVarAmount = t;
        premium.fullPremiumAmount += t;

        return premium;
    }

    function _calculateDistributionOwnerFeeAmount(
        IPolicy.Premium memory premium,
        IComponents.ProductInfo memory productInfo,
        // ISetup.DistributionSetupInfo memory distInfo,
        ReferralId referralId,
        InstanceReader reader
    )
        internal
        view 
        returns (IPolicy.Premium memory finalPremium)
    {

        // if the referral is not valid, then the distribution owner gets everything
        if (! _distributionService.referralIsValid(productInfo.distributionNftId, referralId)) {
            premium.distributionOwnerFeeFixAmount = premium.distributionFeeFixAmount;
            premium.distributionOwnerFeeVarAmount = premium.distributionFeeVarAmount;
            premium.premiumAmount = premium.fullPremiumAmount;
            return premium;
        }

        Fee memory minDistributionOwnerFee = productInfo.minDistributionOwnerFee;

        // if the referral is valid, the the commission and discount are calculated based in the full premium
        // the remaing amount goes to the distribution owner
        {
            IDistribution.ReferralInfo memory referralInfo = reader.getReferralInfo(referralId);
            IDistribution.DistributorInfo memory distributorInfo = reader.getDistributorInfo(referralInfo.distributorNftId);
            IDistribution.DistributorTypeInfo memory distributorTypeInfo = reader.getDistributorTypeInfo(distributorInfo.distributorType);

            uint256 commissionAmount = UFixedLib.toUFixed(premium.netPremiumAmount).mul(distributorTypeInfo.commissionPercentage).toInt();
            premium.commissionAmount = commissionAmount;
            premium.discountAmount = UFixedLib.toUFixed(premium.fullPremiumAmount).mul(referralInfo.discountPercentage).toInt();
            premium.distributionOwnerFeeFixAmount = minDistributionOwnerFee.fixedFee;
            premium.distributionOwnerFeeVarAmount = premium.distributionFeeVarAmount - commissionAmount - premium.discountAmount;
            premium.premiumAmount = premium.fullPremiumAmount - premium.discountAmount;
        }

        return premium; 
    }


    function _calculateTargetWalletAmounts(
        IPolicy.Premium memory premium
    )
        internal
        virtual
        view
        returns (
            IPolicy.Premium memory premiumWithTargetWalletAmounts
        )
    {
        // fees for product owner
        premium.productFeeAmount = AmountLib.toAmount(
            premium.productFeeFixAmount + premium.productFeeVarAmount);

        // fees for distribution owner + distributor commission
        premium.distributionFeeAndCommissionAmount = AmountLib.toAmount(
            premium.distributionFeeFixAmount + premium.distributionOwnerFeeVarAmount 
            + premium.commissionAmount);

        // net premium + fees for pool owner + bundle owner
        premium.poolPremiumAndFeeAmount = AmountLib.toAmount(
            premium.netPremiumAmount 
            + premium.poolFeeFixAmount + premium.poolFeeVarAmount 
            + premium.bundleFeeFixAmount + premium.bundleFeeVarAmount);

        premiumWithTargetWalletAmounts = premium;
    }

}