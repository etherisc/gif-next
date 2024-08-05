// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../../../lib/forge-std/src/Script.sol";
import {GifTest} from "../../base/GifTest.sol";
import {NftId, NftIdLib} from "../../../contracts/type/NftId.sol";
import {AmountLib} from "../../../contracts/type/Amount.sol";
import {Pool} from "../../../contracts/pool/Pool.sol";
import {IPolicy} from "../../../contracts/instance/module/IPolicy.sol";
import {IRegistry} from "../../../contracts/registry/IRegistry.sol";
import {Fee, FeeLib} from "../../../contracts/type/Fee.sol";
import {UFixedLib} from "../../../contracts/type/UFixed.sol";
import {ComponentService} from "../../../contracts/shared/ComponentService.sol";
import {DistributorType} from "../../../contracts/type/DistributorType.sol";
import {ReferralId, ReferralLib} from "../../../contracts/type/Referral.sol";
import {RiskId, RiskIdLib} from "../../../contracts/type/RiskId.sol";
import {SecondsLib} from "../../../contracts/type/Seconds.sol";
import {SimpleDistribution} from "../../../contracts/examples/unpermissioned/SimpleDistribution.sol";
import {TimestampLib} from "../../../contracts/type/Timestamp.sol";

contract TestPricingService is GifTest {

    function test_pricingServiceCalculatePremiumNoFees() public {
        _createAndRegisterDistributionPoolProductWithFees(
            FeeLib.zero(),
            FeeLib.zero(),
            FeeLib.zero(),
            FeeLib.zero(),
            FeeLib.zero()
        );

        RiskId riskId = RiskIdLib.toRiskId("42x4711");
        IPolicy.PremiumInfo memory premium = pricingService.calculatePremium(
            productNftId, 
            riskId, 
            AmountLib.toAmount(1000), 
            SecondsLib.toSeconds(300), 
            "",
            bundleNftId,
            ReferralLib.zero());

        assertEq(premium.netPremiumAmount.toInt(), 100);
        assertEq(premium.fullPremiumAmount.toInt(), 100);
        assertEq(premium.premiumAmount.toInt(), 100);
    }


    function test_pricingServiceCalculatePremiumOnlyFixedFees() public {
        _createAndRegisterDistributionPoolProductWithFees(
            FeeLib.toFee(UFixedLib.zero(), 10),
            FeeLib.toFee(UFixedLib.zero(), 2),
            FeeLib.toFee(UFixedLib.zero(), 10),
            FeeLib.toFee(UFixedLib.zero(), 10),
            FeeLib.toFee(UFixedLib.zero(), 10)
        );

        RiskId riskId = RiskIdLib.toRiskId("42x4711");
        IPolicy.PremiumInfo memory premium = pricingService.calculatePremium(
            productNftId, 
            riskId, 
            AmountLib.toAmount(1000), 
            SecondsLib.toSeconds(300), 
            "",
            bundleNftId,
            ReferralLib.zero());

        assertEq(premium.netPremiumAmount.toInt(), 100, "netPremiumAmount invalid");
        assertEq(premium.fullPremiumAmount.toInt(), 140, "fullPremiumAmount invalid");
        assertEq(premium.premiumAmount.toInt(), 140, "premiumAmount invalid");
        assertEq(premium.distributionFeeFixAmount.toInt(), 10, "distributionFeeFixAmount invalid");
        assertEq(premium.distributionFeeVarAmount.toInt(), 0, "distributionFeeVarAmount invalid");
        assertEq(premium.poolFeeFixAmount.toInt(), 10, "poolFeeFixAmount invalid");
        assertEq(premium.poolFeeVarAmount.toInt(), 0, "poolFeeVarAmount invalid");
        assertEq(premium.bundleFeeFixAmount.toInt(), 10, "bundleFeeFixAmount invalid");
        assertEq(premium.bundleFeeVarAmount.toInt(), 0, "bundleFeeVarAmount invalid");
        assertEq(premium.productFeeFixAmount.toInt(), 10, "productFeeFixAmount invalid");
        assertEq(premium.productFeeVarAmount.toInt(), 0, "productFeeVarAmount invalid");
        assertEq(premium.distributionOwnerFeeFixAmount.toInt(), 10, "distributionOwnerFeeFixAmount invalid");
        assertEq(premium.distributionOwnerFeeVarAmount.toInt(), 0, "distributionOwnerFeeVarAmount invalid");
    }

    function test_pricingServiceCalculatePremiumOnlyVariableFees() public {
        _createAndRegisterDistributionPoolProductWithFees(
            FeeLib.toFee(UFixedLib.toUFixed(5, -2), 0),
            FeeLib.toFee(UFixedLib.toUFixed(5, -2), 0),
            FeeLib.toFee(UFixedLib.toUFixed(5, -2), 0),
            FeeLib.toFee(UFixedLib.toUFixed(5, -2), 0),
            FeeLib.toFee(UFixedLib.toUFixed(5, -2), 0)
        );

        RiskId riskId = RiskIdLib.toRiskId("42x4711");
        IPolicy.PremiumInfo memory premium = pricingService.calculatePremium(
            productNftId, 
            riskId, 
            AmountLib.toAmount(1000), 
            SecondsLib.toSeconds(300), 
            "",
            bundleNftId,
            ReferralLib.zero());

        assertEq(premium.netPremiumAmount.toInt(), 100, "netPremiumAmount invalid");
        assertEq(premium.fullPremiumAmount.toInt(), 120, "fullPremiumAmount invalid");
        assertEq(premium.premiumAmount.toInt(), 120, "premiumAmount invalid");
        assertEq(premium.distributionFeeFixAmount.toInt(), 0, "distributionFeeFixAmount invalid");
        assertEq(premium.distributionFeeVarAmount.toInt(), 5, "distributionFeeVarAmount invalid");
        assertEq(premium.poolFeeFixAmount.toInt(), 0, "poolFeeFixAmount invalid");
        assertEq(premium.poolFeeVarAmount.toInt(), 5, "poolFeeVarAmount invalid");
        assertEq(premium.bundleFeeFixAmount.toInt(), 0, "bundleFeeFixAmount invalid");
        assertEq(premium.bundleFeeVarAmount.toInt(), 5, "bundleFeeVarAmount invalid");
        assertEq(premium.productFeeFixAmount.toInt(), 0, "productFeeFixAmount invalid");
        assertEq(premium.productFeeVarAmount.toInt(), 5, "productFeeVarAmount invalid");
        assertEq(premium.distributionOwnerFeeFixAmount.toInt(), 0, "distributionOwnerFeeFixAmount invalid");
        assertEq(premium.distributionOwnerFeeVarAmount.toInt(), 5, "distributionOwnerFeeVarAmount invalid");
    }

    function test_pricingServiceCalculatePremiumFixedAndVariableFees() public {
        _createAndRegisterDistributionPoolProductWithFees(
            FeeLib.toFee(UFixedLib.toUFixed(5, -2), 3),
            FeeLib.toFee(UFixedLib.toUFixed(5, -2), 2),
            FeeLib.toFee(UFixedLib.toUFixed(5, -2), 4),
            FeeLib.toFee(UFixedLib.toUFixed(5, -2), 5),
            FeeLib.toFee(UFixedLib.toUFixed(5, -2), 6)
        );

        RiskId riskId = RiskIdLib.toRiskId("42x4711");
        IPolicy.PremiumInfo memory premium = pricingService.calculatePremium(
            productNftId, 
            riskId, 
            AmountLib.toAmount(1000), 
            SecondsLib.toSeconds(300), 
            "",
            bundleNftId,
            ReferralLib.zero());

        assertEq(premium.netPremiumAmount.toInt(), 100, "netPremiumAmount invalid");
        assertEq(premium.fullPremiumAmount.toInt(), 100 + 5 * 4 + 3 + 4 + 5 + 6, "fullPremiumAmount invalid");
        assertEq(premium.premiumAmount.toInt(), 100 + 5 * 4 + 3 + 4 + 5 + 6, "premiumAmount invalid");
        assertEq(premium.distributionFeeFixAmount.toInt(), 3, "distributionFeeFixAmount invalid");
        assertEq(premium.distributionFeeVarAmount.toInt(), 5, "distributionFeeVarAmount invalid");
        assertEq(premium.poolFeeFixAmount.toInt(), 4, "poolFeeFixAmount invalid");
        assertEq(premium.poolFeeVarAmount.toInt(), 5, "poolFeeVarAmount invalid");
        assertEq(premium.bundleFeeFixAmount.toInt(), 5, "bundleFeeFixAmount invalid");
        assertEq(premium.bundleFeeVarAmount.toInt(), 5, "bundleFeeVarAmount invalid");
        assertEq(premium.productFeeFixAmount.toInt(), 6, "productFeeFixAmount invalid");
        assertEq(premium.productFeeVarAmount.toInt(), 5, "productFeeVarAmount invalid");
        assertEq(premium.distributionOwnerFeeFixAmount.toInt(), 3, "distributionOwnerFeeFixAmount invalid");
        assertEq(premium.distributionOwnerFeeVarAmount.toInt(), 5, "distributionOwnerFeeVarAmount invalid");
    }

    function test_pricingServiceCalculatePremiumOnlyVariableFeesWithReferral() public {

        _createAndRegisterDistributionPoolProductWithFees(
            FeeLib.toFee(UFixedLib.toUFixed(30, -2), 0),
            FeeLib.toFee(UFixedLib.toUFixed(2, -2), 0),
            FeeLib.toFee(UFixedLib.toUFixed(10, -2), 0),
            FeeLib.toFee(UFixedLib.toUFixed(10, -2), 0),
            FeeLib.toFee(UFixedLib.toUFixed(10, -2), 0)
        );

        vm.startPrank(distributionOwner);
        DistributorType distributorType = distribution.createDistributorType(
            "Gold",
            UFixedLib.zero(),
            UFixedLib.toUFixed(10, -2),
            UFixedLib.toUFixed(5, -2),
            10,
            14 * 24 * 3600,
            false,
            false,
            "");

        NftId distributorNftId = distribution.createDistributor(
            customer,
            distributorType,
            "");
        vm.stopPrank();

        vm.startPrank(customer);
        ReferralId referralId = distribution.createReferral(
            "GET_A_DISCOUNT",
            UFixedLib.toUFixed(10, -2),
            5,
            TimestampLib.blockTimestamp().addSeconds(SecondsLib.toSeconds(604800)),
            "");
        vm.stopPrank();

        RiskId riskId = RiskIdLib.toRiskId("42x4711");
        IPolicy.PremiumInfo memory premium = pricingService.calculatePremium(
            productNftId, 
            riskId, 
            AmountLib.toAmount(1000), 
            SecondsLib.toSeconds(300), 
            "",
            bundleNftId,
            referralId);

        assertEq(premium.netPremiumAmount.toInt(), 100, "netPremiumAmount invalid");
        assertEq(premium.fullPremiumAmount.toInt(), 160, "fullPremiumAmount invalid");
        assertEq(premium.premiumAmount.toInt(), 144, "premiumAmount invalid");
        assertEq(premium.distributionFeeFixAmount.toInt(), 0, "distributionFeeFixAmount invalid");
        assertEq(premium.distributionFeeVarAmount.toInt(), 30, "distributionFeeVarAmount invalid");
        assertEq(premium.poolFeeFixAmount.toInt(), 0, "poolFeeFixAmount invalid");
        assertEq(premium.poolFeeVarAmount.toInt(), 10, "poolFeeVarAmount invalid");
        assertEq(premium.bundleFeeFixAmount.toInt(), 0, "bundleFeeFixAmount invalid");
        assertEq(premium.bundleFeeVarAmount.toInt(), 10, "bundleFeeVarAmount invalid");
        assertEq(premium.productFeeFixAmount.toInt(), 0, "productFeeFixAmount invalid");
        assertEq(premium.productFeeVarAmount.toInt(), 10, "productFeeVarAmount invalid");
        assertEq(premium.discountAmount.toInt(), 16, "discountAmount invalid");
        assertEq(premium.commissionAmount.toInt(), 5, "commissionAmount invalid");
        assertEq(premium.distributionOwnerFeeFixAmount.toInt(), 0, "distributionOwnerFeeFixAmount invalid");
        assertEq(premium.distributionOwnerFeeVarAmount.toInt(), 9, "distributionOwnerFeeVarAmount invalid");
    }

    function test_pricingServiceCalculatePremiumOnlyVariableFeesWithReferralNoDiscount() public {
        _createAndRegisterDistributionPoolProductWithFees(
            FeeLib.toFee(UFixedLib.toUFixed(30, -2), 0),
            FeeLib.toFee(UFixedLib.toUFixed(2, -2), 0),
            FeeLib.toFee(UFixedLib.toUFixed(10, -2), 0),
            FeeLib.toFee(UFixedLib.toUFixed(10, -2), 0),
            FeeLib.toFee(UFixedLib.toUFixed(10, -2), 0)
        );

        vm.startPrank(distributionOwner);
        DistributorType distributorType = distribution.createDistributorType(
            "Gold",
            UFixedLib.zero(),
            UFixedLib.toUFixed(10, -2),
            UFixedLib.toUFixed(5, -2),
            10,
            14 * 24 * 3600,
            false,
            false,
            "");

        NftId distributorNftId = distribution.createDistributor(
            customer,
            distributorType,
            "");
        vm.stopPrank();
        

        vm.startPrank(customer);
        ReferralId referralId = distribution.createReferral(
            "GET_A_DISCOUNT",
            UFixedLib.toUFixed(0, -2),
            5,
            TimestampLib.blockTimestamp().addSeconds(SecondsLib.toSeconds(604800)),
            "");
        vm.stopPrank();

        RiskId riskId = RiskIdLib.toRiskId("42x4711");
        IPolicy.PremiumInfo memory premium = pricingService.calculatePremium(
            productNftId, 
            riskId, 
            AmountLib.toAmount(1000), 
            SecondsLib.toSeconds(300), 
            "",
            bundleNftId,
            referralId);

        assertEq(premium.netPremiumAmount.toInt(), 100, "netPremiumAmount invalid");
        assertEq(premium.fullPremiumAmount.toInt(), 160, "fullPremiumAmount invalid");
        assertEq(premium.premiumAmount.toInt(), 160, "premiumAmount invalid");
        assertEq(premium.distributionFeeFixAmount.toInt(), 0, "distributionFeeFixAmount invalid");
        assertEq(premium.distributionFeeVarAmount.toInt(), 30, "distributionFeeVarAmount invalid");
        assertEq(premium.poolFeeFixAmount.toInt(), 0, "poolFeeFixAmount invalid");
        assertEq(premium.poolFeeVarAmount.toInt(), 10, "poolFeeVarAmount invalid");
        assertEq(premium.bundleFeeFixAmount.toInt(), 0, "bundleFeeFixAmount invalid");
        assertEq(premium.bundleFeeVarAmount.toInt(), 10, "bundleFeeVarAmount invalid");
        assertEq(premium.productFeeFixAmount.toInt(), 0, "productFeeFixAmount invalid");
        assertEq(premium.productFeeVarAmount.toInt(), 10, "productFeeVarAmount invalid");
        assertEq(premium.discountAmount.toInt(), 0, "discountAmount invalid");
        assertEq(premium.commissionAmount.toInt(), 5, "commissionAmount invalid");
        assertEq(premium.distributionOwnerFeeFixAmount.toInt(), 0, "distributionOwnerFeeFixAmount invalid");
        assertEq(premium.distributionOwnerFeeVarAmount.toInt(), 25, "distributionOwnerFeeVarAmount invalid");
    }

    function test_pricingServiceCalculatePremiumVariableAndFixedFeesWithReferral() public {
        _createAndRegisterDistributionPoolProductWithFees(
            FeeLib.toFee(UFixedLib.toUFixed(30, -2), 10),
            FeeLib.toFee(UFixedLib.toUFixed(2, -2), 5),
            FeeLib.toFee(UFixedLib.toUFixed(10, -2), 10),
            FeeLib.toFee(UFixedLib.toUFixed(10, -2), 10),
            FeeLib.toFee(UFixedLib.toUFixed(10, -2), 10)
        );

        SimpleDistribution sdistribution = SimpleDistribution(address(distribution));

        vm.startPrank(distributionOwner);
        DistributorType distributorType = distribution.createDistributorType(
            "Gold",
            UFixedLib.zero(),
            UFixedLib.toUFixed(10, -2),
            UFixedLib.toUFixed(5, -2),
            10,
            14 * 24 * 3600,
            false,
            false,
            "");

        // create distributor
        NftId distributorNftId = distribution.createDistributor(customer, distributorType, "");
        vm.stopPrank();
        
        // distributor creates referral
        vm.startPrank(customer);
        ReferralId referralId = sdistribution.createReferral(
            "GET_A_DISCOUNT",
            UFixedLib.toUFixed(10, -2),
            5,
            TimestampLib.blockTimestamp().addSeconds(SecondsLib.toSeconds(604800)),
            "");
        vm.stopPrank();

        RiskId riskId = RiskIdLib.toRiskId("42x4711");
        IPolicy.PremiumInfo memory premium = pricingService.calculatePremium(
            productNftId, 
            riskId, 
            AmountLib.toAmount(1000), 
            SecondsLib.toSeconds(300), 
            "",
            bundleNftId,
            referralId);

        assertEq(premium.netPremiumAmount.toInt(), 100, "netPremiumAmount invalid");
        assertEq(premium.fullPremiumAmount.toInt(), 200, "fullPremiumAmount invalid");
        assertEq(premium.premiumAmount.toInt(), 180, "premiumAmount invalid");
        assertEq(premium.distributionFeeFixAmount.toInt(), 10, "distributionFeeFixAmount invalid");
        assertEq(premium.distributionFeeVarAmount.toInt(), 30, "distributionFeeVarAmount invalid");
        assertEq(premium.poolFeeFixAmount.toInt(), 10, "poolFeeFixAmount invalid");
        assertEq(premium.poolFeeVarAmount.toInt(), 10, "poolFeeVarAmount invalid");
        assertEq(premium.bundleFeeFixAmount.toInt(), 10, "bundleFeeFixAmount invalid");
        assertEq(premium.bundleFeeVarAmount.toInt(), 10, "bundleFeeVarAmount invalid");
        assertEq(premium.productFeeFixAmount.toInt(), 10, "productFeeFixAmount invalid");
        assertEq(premium.productFeeVarAmount.toInt(), 10, "productFeeVarAmount invalid");
        assertEq(premium.discountAmount.toInt(), 20, "discountAmount invalid");
        assertEq(premium.commissionAmount.toInt(), 5, "commissionAmount invalid");
        assertEq(premium.distributionOwnerFeeFixAmount.toInt(), 5, "distributionOwnerFeeFixAmount invalid");
        assertEq(premium.distributionOwnerFeeVarAmount.toInt(), 5, "distributionOwnerFeeVarAmount invalid");
    }

    function _createAndRegisterDistributionPoolProductWithFees(
        Fee memory distributionFee,
        Fee memory minDistributionOwnerFee,
        Fee memory poolFee,
        Fee memory bundleFee,
        Fee memory productFee
    ) internal {
        _prepareProduct();

        // -- set various fees
        vm.startPrank(distributionOwner);
        distribution.setFees(
            distributionFee, 
            minDistributionOwnerFee); // staking fee
        vm.stopPrank();

        vm.startPrank(poolOwner);
        pool.setFees(
            poolFee, 
            FeeLib.zero(), // staking fee
            FeeLib.zero()); // performance fee
        vm.stopPrank();

        vm.startPrank(productOwner);
        product.setFees(
            productFee, 
            FeeLib.zero()); // processing fee
        vm.stopPrank();

        // -- create bundle on pool
        vm.startPrank(registryOwner);
        token.transfer(investor, 10000);
        vm.stopPrank();

        vm.startPrank(investor);
        token.approve(
            address(instanceReader.getComponentInfo(poolNftId).tokenHandler), 
            10000);

        (bundleNftId, ) = pool.createBundle(
            bundleFee, 
            10000, 
            SecondsLib.toSeconds(604800), 
            ""
        );
        vm.stopPrank();
    }
}