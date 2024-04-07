// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Seconds} from "../../types/Seconds.sol";
import {UFixed, UFixedLib} from "../../types/UFixed.sol";
import {ObjectType} from "../../types/ObjectType.sol";
import {NftId} from "../../types/NftId.sol";
import {Fee} from "../../types/Fee.sol";
import {ReferralId} from "../../types/Referral.sol";
import {RiskId} from "../../types/RiskId.sol";
import {PRODUCT, DISTRIBUTION, PRICE} from "../../types/ObjectType.sol";

import {IRegistry} from "../../registry/IRegistry.sol";

import {IProductComponent} from "../../components/IProductComponent.sol";

import {IInstance} from "../IInstance.sol";
import {InstanceReader} from "../InstanceReader.sol";
import {IComponents} from "../module/IComponents.sol";
import {IPolicy} from "../module/IPolicy.sol";
import {IBundle} from "../module/IBundle.sol";
import {ISetup} from "../module/ISetup.sol";
import {IDistribution} from "../module/IDistribution.sol";

import {ComponentService} from "../base/ComponentService.sol";

import {IPricingService} from "./IPricingService.sol";
import {IDistributionService} from "./IDistributionService.sol";


contract PricingService is 
    ComponentService, 
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
        // TODO check this, might no longer be the way, refactor if necessary
        address registryAddress;
        address initialOwner;
        (registryAddress, initialOwner) = abi.decode(data, (address, address));

        initializeService(registryAddress, address(0), owner);
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
        uint256 sumInsuredAmount,
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
        uint256 netPremiumAmount;

        {
            // verify product
            (
                IRegistry.ObjectInfo memory productInfo, 
                IInstance instance
            ) = _getAndVerifyComponentInfoAndInstance(productNftId, PRODUCT());

            reader = instance.getInstanceReader();

            // calculate net premium
            netPremiumAmount = IProductComponent(productInfo.objectAddress).calculateNetPremium(
                sumInsuredAmount,
                riskId,
                lifetime,
                applicationData
            );
        }

        {
            // get configurations for all involed objects
            ISetup.ProductSetupInfo memory productSetup = reader.getProductSetupInfo(productNftId);

            bytes memory componentData = reader.getComponentInfo(productSetup.poolNftId).data;
            IComponents.PoolInfo memory poolInfo = abi.decode(componentData, (IComponents.PoolInfo));

            IBundle.BundleInfo memory bundleInfo = reader.getBundleInfo(bundleNftId);
            if(bundleInfo.poolNftId != productSetup.poolNftId) {
                revert ErrorIPricingServiceBundlePoolMismatch(bundleNftId, bundleInfo.poolNftId, productSetup.poolNftId);
            }

            NftId distributionNftId = productSetup.distributionNftId;
            ISetup.DistributionSetupInfo memory distSetup = reader.getDistributionSetupInfo(distributionNftId);

            // calculate premium, order is important
            premium = _getFixedFeeAmounts(
                netPremiumAmount,
                productSetup,
                poolInfo,
                distSetup,
                bundleInfo
            );

            premium = _calculateVariableFeeAmounts(
                premium,
                productSetup,
                poolInfo,
                distSetup,
                bundleInfo
            );

            premium = _calculateDistributionOwnerFeeAmount(
                premium,
                distSetup,
                referralId,
                distributionNftId,
                reader
            );

            // sanity check to validate the fee calculation
            if (premium.distributionOwnerFeeFixAmount < distSetup.minDistributionOwnerFee.fixedFee) {
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
        uint256 netPremiumAmount,
        ISetup.ProductSetupInfo memory productInfo,
        IComponents.PoolInfo memory poolInfo,
        ISetup.DistributionSetupInfo memory distInfo,
        IBundle.BundleInfo memory bundleInfo
    )
        internal
        view
        returns (
            IPolicy.Premium memory premium
        )
    {
        // initial premium amount is the net premium
        premium.netPremiumAmount = netPremiumAmount;
        premium.fullPremiumAmount = netPremiumAmount;

        uint256 t = productInfo.productFee.fixedFee;
        premium.productFeeFixAmount = t;
        premium.fullPremiumAmount += t;

        t = poolInfo.poolFee.fixedFee;
        premium.poolFeeFixAmount = t;
        premium.fullPremiumAmount += t;

        t = bundleInfo.fee.fixedFee;
        premium.bundleFeeFixAmount = t;
        premium.fullPremiumAmount += t;

        t = distInfo.distributionFee.fixedFee;
        premium.distributionFeeFixAmount = t;
        premium.fullPremiumAmount += t;
    }

    function _calculateVariableFeeAmounts(
        IPolicy.Premium memory premium,
        ISetup.ProductSetupInfo memory productInfo,
        IComponents.PoolInfo memory poolInfo,
        ISetup.DistributionSetupInfo memory distInfo,
        IBundle.BundleInfo memory bundleInfo
    )
        internal
        view
        returns (
            IPolicy.Premium memory intermadiatePremium
        )
    {
        UFixed netPremiumAmount = UFixedLib.toUFixed(premium.netPremiumAmount);

        uint256 t = (netPremiumAmount * productInfo.productFee.fractionalFee).toInt();
        premium.productFeeVarAmount = t;
        premium.fullPremiumAmount += t;

        t = (netPremiumAmount * poolInfo.poolFee.fractionalFee).toInt();
        premium.poolFeeVarAmount = t;
        premium.fullPremiumAmount += t;

        t = (netPremiumAmount * bundleInfo.fee.fractionalFee).toInt();
        premium.bundleFeeVarAmount = t;
        premium.fullPremiumAmount += t;

        t = (netPremiumAmount * distInfo.distributionFee.fractionalFee).toInt();
        premium.distributionFeeVarAmount = t;
        premium.fullPremiumAmount += t;

        return premium;
    }

    function _calculateDistributionOwnerFeeAmount(
        IPolicy.Premium memory premium,
        ISetup.DistributionSetupInfo memory distInfo,
        ReferralId referralId,
        NftId distributionNftId,
        InstanceReader reader
    )
        internal
        view 
        returns (IPolicy.Premium memory finalPremium)
    {
        // if the referral is not valid, then the distribution owner gets everything
        if (! _distributionService.referralIsValid(distributionNftId, referralId)) {
            premium.distributionOwnerFeeFixAmount = premium.distributionFeeFixAmount;
            premium.distributionOwnerFeeVarAmount = premium.distributionFeeVarAmount;
            premium.premiumAmount = premium.fullPremiumAmount;
            return premium;
        }

        Fee memory minDistributionOwnerFee = distInfo.minDistributionOwnerFee;

        // if the referral is valid, the the commission and discount are calculated based in the full premium
        // the remaing amount goes to the distribution owner
        {
            IDistribution.ReferralInfo memory referralInfo = reader.getReferralInfo(referralId);
            IDistribution.DistributorInfo memory distributorInfo = reader.getDistributorInfo(referralInfo.distributorNftId);
            IDistribution.DistributorTypeInfo memory distributorTypeInfo = reader.getDistributorTypeInfo(distributorInfo.distributorType);

            uint256 commissionAmount = UFixedLib.toUFixed(premium.netPremiumAmount).mul(distributorTypeInfo.commissionPercentage).toInt();
            premium.commissionAmount = commissionAmount;
            premium.discountAmount = UFixedLib.toUFixed(premium.fullPremiumAmount).mul(referralInfo.discountPercentage).toInt();
            premium.distributionOwnerFeeFixAmount = distInfo.minDistributionOwnerFee.fixedFee;
            premium.distributionOwnerFeeVarAmount = premium.distributionFeeVarAmount - commissionAmount - premium.discountAmount;
            premium.premiumAmount = premium.fullPremiumAmount - premium.discountAmount;
        }

        return premium; 
    }
}
