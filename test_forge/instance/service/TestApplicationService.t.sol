// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {console} from "../../../lib/forge-std/src/Script.sol";
import {TestGifBase} from "../../base/TestGifBase.sol";
import {NftId, toNftId, NftIdLib} from "../../../contracts/types/NftId.sol";
import {PRODUCT_OWNER_ROLE, POOL_OWNER_ROLE, DISTRIBUTION_OWNER_ROLE} from "../../../contracts/types/RoleId.sol";
import {Pool} from "../../../contracts/components/Pool.sol";
import {IPolicy} from "../../../contracts/instance/module/IPolicy.sol";
import {IRegistry} from "../../../contracts/registry/IRegistry.sol";
import {ISetup} from "../../../contracts/instance/module/ISetup.sol";
import {Fee, FeeLib} from "../../../contracts/types/Fee.sol";
import {UFixedLib} from "../../../contracts/types/UFixed.sol";
import {ComponentService} from "../../../contracts/instance/base/ComponentService.sol";
import {DistributorType} from "../../../contracts/types/DistributorType.sol";
import {ReferralId, ReferralLib} from "../../../contracts/types/Referral.sol";
import {RiskId, RiskIdLib} from "../../../contracts/types/RiskId.sol";
import {SecondsLib} from "../../../contracts/types/Seconds.sol";
import {SimpleProduct} from "../../mock/SimpleProduct.sol";
import {SimpleDistribution} from "../../mock/SimpleDistribution.sol";
import {SimplePool} from "../../mock/SimplePool.sol";
import {TimestampLib} from "../../../contracts/types/Timestamp.sol";

contract TestProductService is TestGifBase {
    using NftIdLib for NftId;

    function test_ApplicationService_calculatePremium_noFees() public {
        _createAndRegisterDistributionPoolProductWithFees(
            FeeLib.zeroFee(),
            FeeLib.zeroFee(),
            FeeLib.zeroFee(),
            FeeLib.zeroFee(),
            FeeLib.zeroFee()
        );

        RiskId riskId = RiskIdLib.toRiskId("42x4711");
        IPolicy.Premium memory premium = applicationService.calculatePremium(
            productNftId, 
            riskId, 
            1000, 
            SecondsLib.toSeconds(300), 
            "", 
            bundleNftId, 
            ReferralLib.zero());

        assertEq(premium.netPremiumAmount, 100);
        assertEq(premium.fullPremiumAmount, 100);
        assertEq(premium.premiumAmount, 100);
    }

    function test_ApplicationService_calculatePremium_onlyFixedFees() public {
        _createAndRegisterDistributionPoolProductWithFees(
            FeeLib.toFee(UFixedLib.zero(), 2),
            FeeLib.toFee(UFixedLib.zero(), 10),
            FeeLib.toFee(UFixedLib.zero(), 10),
            FeeLib.toFee(UFixedLib.zero(), 10),
            FeeLib.toFee(UFixedLib.zero(), 10)
        );

        RiskId riskId = RiskIdLib.toRiskId("42x4711");
        IPolicy.Premium memory premium = applicationService.calculatePremium(
            productNftId, 
            riskId, 
            1000, 
            SecondsLib.toSeconds(300), 
            "", 
            bundleNftId, 
            ReferralLib.zero());

        assertEq(premium.netPremiumAmount, 100, "netPremiumAmount invalid");
        assertEq(premium.fullPremiumAmount, 140, "fullPremiumAmount invalid");
        assertEq(premium.premiumAmount, 140, "premiumAmount invalid");
        assertEq(premium.distributionFeeFixAmount, 10, "distributionFeeFixAmount invalid");
        assertEq(premium.distributionFeeVarAmount, 0, "distributionFeeVarAmount invalid");
        assertEq(premium.poolFeeFixAmount, 10, "poolFeeFixAmount invalid");
        assertEq(premium.poolFeeVarAmount, 0, "poolFeeVarAmount invalid");
        assertEq(premium.bundleFeeFixAmount, 10, "bundleFeeFixAmount invalid");
        assertEq(premium.bundleFeeVarAmount, 0, "bundleFeeVarAmount invalid");
        assertEq(premium.productFeeFixAmount, 10, "productFeeFixAmount invalid");
        assertEq(premium.productFeeVarAmount, 0, "productFeeVarAmount invalid");
        assertEq(premium.distributionOwnerFeeFixAmount, 10, "distributionOwnerFeeFixAmount invalid");
        assertEq(premium.distributionOwnerFeeVarAmount, 0, "distributionOwnerFeeVarAmount invalid");
    }

    function test_ApplicationService_calculatePremium_onlyVariableFees() public {
        _createAndRegisterDistributionPoolProductWithFees(
            FeeLib.toFee(UFixedLib.toUFixed(5, -2), 0),
            FeeLib.toFee(UFixedLib.toUFixed(5, -2), 0),
            FeeLib.toFee(UFixedLib.toUFixed(5, -2), 0),
            FeeLib.toFee(UFixedLib.toUFixed(5, -2), 0),
            FeeLib.toFee(UFixedLib.toUFixed(5, -2), 0)
        );

        RiskId riskId = RiskIdLib.toRiskId("42x4711");
        IPolicy.Premium memory premium = applicationService.calculatePremium(
            productNftId, 
            riskId, 
            1000, 
            SecondsLib.toSeconds(300), 
            "", 
            bundleNftId, 
            ReferralLib.zero());

        assertEq(premium.netPremiumAmount, 100, "netPremiumAmount invalid");
        assertEq(premium.fullPremiumAmount, 120, "fullPremiumAmount invalid");
        assertEq(premium.premiumAmount, 120, "premiumAmount invalid");
        assertEq(premium.distributionFeeFixAmount, 0, "distributionFeeFixAmount invalid");
        assertEq(premium.distributionFeeVarAmount, 5, "distributionFeeVarAmount invalid");
        assertEq(premium.poolFeeFixAmount, 0, "poolFeeFixAmount invalid");
        assertEq(premium.poolFeeVarAmount, 5, "poolFeeVarAmount invalid");
        assertEq(premium.bundleFeeFixAmount, 0, "bundleFeeFixAmount invalid");
        assertEq(premium.bundleFeeVarAmount, 5, "bundleFeeVarAmount invalid");
        assertEq(premium.productFeeFixAmount, 0, "productFeeFixAmount invalid");
        assertEq(premium.productFeeVarAmount, 5, "productFeeVarAmount invalid");
        assertEq(premium.distributionOwnerFeeFixAmount, 0, "distributionOwnerFeeFixAmount invalid");
        assertEq(premium.distributionOwnerFeeVarAmount, 5, "distributionOwnerFeeVarAmount invalid");
    }

    function test_ApplicationService_calculatePremium_FixedAndVariableFees() public {
        _createAndRegisterDistributionPoolProductWithFees(
            FeeLib.toFee(UFixedLib.toUFixed(5, -2), 2),
            FeeLib.toFee(UFixedLib.toUFixed(5, -2), 3),
            FeeLib.toFee(UFixedLib.toUFixed(5, -2), 4),
            FeeLib.toFee(UFixedLib.toUFixed(5, -2), 5),
            FeeLib.toFee(UFixedLib.toUFixed(5, -2), 6)
        );

        RiskId riskId = RiskIdLib.toRiskId("42x4711");
        IPolicy.Premium memory premium = applicationService.calculatePremium(
            productNftId, 
            riskId, 
            1000, 
            SecondsLib.toSeconds(300), 
            "", 
            bundleNftId, 
            ReferralLib.zero());

        assertEq(premium.netPremiumAmount, 100, "netPremiumAmount invalid");
        assertEq(premium.fullPremiumAmount, 100 + 5 * 4 + 3 + 4 + 5 + 6, "fullPremiumAmount invalid");
        assertEq(premium.premiumAmount, 100 + 5 * 4 + 3 + 4 + 5 + 6, "premiumAmount invalid");
        assertEq(premium.distributionFeeFixAmount, 3, "distributionFeeFixAmount invalid");
        assertEq(premium.distributionFeeVarAmount, 5, "distributionFeeVarAmount invalid");
        assertEq(premium.poolFeeFixAmount, 4, "poolFeeFixAmount invalid");
        assertEq(premium.poolFeeVarAmount, 5, "poolFeeVarAmount invalid");
        assertEq(premium.bundleFeeFixAmount, 5, "bundleFeeFixAmount invalid");
        assertEq(premium.bundleFeeVarAmount, 5, "bundleFeeVarAmount invalid");
        assertEq(premium.productFeeFixAmount, 6, "productFeeFixAmount invalid");
        assertEq(premium.productFeeVarAmount, 5, "productFeeVarAmount invalid");
        assertEq(premium.distributionOwnerFeeFixAmount, 3, "distributionOwnerFeeFixAmount invalid");
        assertEq(premium.distributionOwnerFeeVarAmount, 5, "distributionOwnerFeeVarAmount invalid");
    }

    function test_ApplicationService_calculatePremium_onlyVariableFeesWithReferral() public {
        _createAndRegisterDistributionPoolProductWithFees(
            FeeLib.toFee(UFixedLib.toUFixed(2, -2), 0),
            FeeLib.toFee(UFixedLib.toUFixed(30, -2), 0),
            FeeLib.toFee(UFixedLib.toUFixed(10, -2), 0),
            FeeLib.toFee(UFixedLib.toUFixed(10, -2), 0),
            FeeLib.toFee(UFixedLib.toUFixed(10, -2), 0)
        );

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
        
        SimpleDistribution sdistribution = SimpleDistribution(address(distribution));
        ReferralId referralId = sdistribution.createReferral(
            distributorNftId,
            "GET_A_DISCOUNT",
            UFixedLib.toUFixed(10, -2),
            5,
            TimestampLib.blockTimestamp().addSeconds(SecondsLib.toSeconds(604800)),
            "");

        RiskId riskId = RiskIdLib.toRiskId("42x4711");
        IPolicy.Premium memory premium = applicationService.calculatePremium(
            productNftId, 
            riskId, 
            1000, 
            SecondsLib.toSeconds(300), 
            "", 
            bundleNftId, 
            referralId);

        assertEq(premium.netPremiumAmount, 100, "netPremiumAmount invalid");
        assertEq(premium.fullPremiumAmount, 160, "fullPremiumAmount invalid");
        assertEq(premium.premiumAmount, 144, "premiumAmount invalid");
        assertEq(premium.distributionFeeFixAmount, 0, "distributionFeeFixAmount invalid");
        assertEq(premium.distributionFeeVarAmount, 30, "distributionFeeVarAmount invalid");
        assertEq(premium.poolFeeFixAmount, 0, "poolFeeFixAmount invalid");
        assertEq(premium.poolFeeVarAmount, 10, "poolFeeVarAmount invalid");
        assertEq(premium.bundleFeeFixAmount, 0, "bundleFeeFixAmount invalid");
        assertEq(premium.bundleFeeVarAmount, 10, "bundleFeeVarAmount invalid");
        assertEq(premium.productFeeFixAmount, 0, "productFeeFixAmount invalid");
        assertEq(premium.productFeeVarAmount, 10, "productFeeVarAmount invalid");
        assertEq(premium.discountAmount, 16, "discountAmount invalid");
        assertEq(premium.commissionAmount, 5, "commissionAmount invalid");
        assertEq(premium.distributionOwnerFeeFixAmount, 0, "distributionOwnerFeeFixAmount invalid");
        assertEq(premium.distributionOwnerFeeVarAmount, 9, "distributionOwnerFeeVarAmount invalid");
    }

    function test_ApplicationService_calculatePremium_onlyVariableFeesWithReferralNoDiscount() public {
        _createAndRegisterDistributionPoolProductWithFees(
            FeeLib.toFee(UFixedLib.toUFixed(2, -2), 0),
            FeeLib.toFee(UFixedLib.toUFixed(30, -2), 0),
            FeeLib.toFee(UFixedLib.toUFixed(10, -2), 0),
            FeeLib.toFee(UFixedLib.toUFixed(10, -2), 0),
            FeeLib.toFee(UFixedLib.toUFixed(10, -2), 0)
        );

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
        
        SimpleDistribution sdistribution = SimpleDistribution(address(distribution));
        ReferralId referralId = sdistribution.createReferral(
            distributorNftId,
            "GET_A_DISCOUNT",
            UFixedLib.toUFixed(0, -2),
            5,
            TimestampLib.blockTimestamp().addSeconds(SecondsLib.toSeconds(604800)),
            "");

        RiskId riskId = RiskIdLib.toRiskId("42x4711");
        IPolicy.Premium memory premium = applicationService.calculatePremium(
            productNftId, 
            riskId, 
            1000, 
            SecondsLib.toSeconds(300), 
            "", 
            bundleNftId, 
            referralId);

        assertEq(premium.netPremiumAmount, 100, "netPremiumAmount invalid");
        assertEq(premium.fullPremiumAmount, 160, "fullPremiumAmount invalid");
        assertEq(premium.premiumAmount, 160, "premiumAmount invalid");
        assertEq(premium.distributionFeeFixAmount, 0, "distributionFeeFixAmount invalid");
        assertEq(premium.distributionFeeVarAmount, 30, "distributionFeeVarAmount invalid");
        assertEq(premium.poolFeeFixAmount, 0, "poolFeeFixAmount invalid");
        assertEq(premium.poolFeeVarAmount, 10, "poolFeeVarAmount invalid");
        assertEq(premium.bundleFeeFixAmount, 0, "bundleFeeFixAmount invalid");
        assertEq(premium.bundleFeeVarAmount, 10, "bundleFeeVarAmount invalid");
        assertEq(premium.productFeeFixAmount, 0, "productFeeFixAmount invalid");
        assertEq(premium.productFeeVarAmount, 10, "productFeeVarAmount invalid");
        assertEq(premium.discountAmount, 0, "discountAmount invalid");
        assertEq(premium.commissionAmount, 5, "commissionAmount invalid");
        assertEq(premium.distributionOwnerFeeFixAmount, 0, "distributionOwnerFeeFixAmount invalid");
        assertEq(premium.distributionOwnerFeeVarAmount, 25, "distributionOwnerFeeVarAmount invalid");
    }

    function test_ApplicationService_calculatePremium_variableAndFixedFeesWithReferral() public {
        _createAndRegisterDistributionPoolProductWithFees(
            FeeLib.toFee(UFixedLib.toUFixed(2, -2), 5),
            FeeLib.toFee(UFixedLib.toUFixed(30, -2), 10),
            FeeLib.toFee(UFixedLib.toUFixed(10, -2), 10),
            FeeLib.toFee(UFixedLib.toUFixed(10, -2), 10),
            FeeLib.toFee(UFixedLib.toUFixed(10, -2), 10)
        );

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
        
        SimpleDistribution sdistribution = SimpleDistribution(address(distribution));
        ReferralId referralId = sdistribution.createReferral(
            distributorNftId,
            "GET_A_DISCOUNT",
            UFixedLib.toUFixed(10, -2),
            5,
            TimestampLib.blockTimestamp().addSeconds(SecondsLib.toSeconds(604800)),
            "");

        RiskId riskId = RiskIdLib.toRiskId("42x4711");
        IPolicy.Premium memory premium = applicationService.calculatePremium(
            productNftId, 
            riskId, 
            1000, 
            SecondsLib.toSeconds(300), 
            "", 
            bundleNftId, 
            referralId);

        assertEq(premium.netPremiumAmount, 100, "netPremiumAmount invalid");
        assertEq(premium.fullPremiumAmount, 200, "fullPremiumAmount invalid");
        assertEq(premium.premiumAmount, 180, "premiumAmount invalid");
        assertEq(premium.distributionFeeFixAmount, 10, "distributionFeeFixAmount invalid");
        assertEq(premium.distributionFeeVarAmount, 30, "distributionFeeVarAmount invalid");
        assertEq(premium.poolFeeFixAmount, 10, "poolFeeFixAmount invalid");
        assertEq(premium.poolFeeVarAmount, 10, "poolFeeVarAmount invalid");
        assertEq(premium.bundleFeeFixAmount, 10, "bundleFeeFixAmount invalid");
        assertEq(premium.bundleFeeVarAmount, 10, "bundleFeeVarAmount invalid");
        assertEq(premium.productFeeFixAmount, 10, "productFeeFixAmount invalid");
        assertEq(premium.productFeeVarAmount, 10, "productFeeVarAmount invalid");
        assertEq(premium.discountAmount, 20, "discountAmount invalid");
        assertEq(premium.commissionAmount, 5, "commissionAmount invalid");
        assertEq(premium.distributionOwnerFeeFixAmount, 5, "distributionOwnerFeeFixAmount invalid");
        assertEq(premium.distributionOwnerFeeVarAmount, 5, "distributionOwnerFeeVarAmount invalid");
    }

    function _createAndRegisterDistributionPoolProductWithFees(
        Fee memory minDistributionOwnerFee,
        Fee memory distributionFee,
        Fee memory poolFee,
        Fee memory bundleFee,
        Fee memory productFee
    ) internal {
        vm.startPrank(instanceOwner);
        instanceAccessManager.grantRole(DISTRIBUTION_OWNER_ROLE(), distributionOwner);
        instanceAccessManager.grantRole(POOL_OWNER_ROLE(), poolOwner);
        instanceAccessManager.grantRole(PRODUCT_OWNER_ROLE(), productOwner);
        vm.stopPrank();

        // -- setup distribution
        vm.startPrank(distributionOwner);
        distribution = new SimpleDistribution(
            address(registry),
            instanceNftId,
            address(token),
            minDistributionOwnerFee,
            distributionFee,
            distributionOwner
        );
        distributionNftId = distributionService.register(address(distribution));
        vm.stopPrank();

        // -- setup pool
        vm.startPrank(poolOwner);
        pool = new SimplePool(
            address(registry),
            instanceNftId,
            address(token),
            false,
            false,
            UFixedLib.toUFixed(1),
            UFixedLib.toUFixed(1),
            poolOwner
        );
        poolNftId = poolService.register(address(pool));
        pool.setFees(
            poolFee, 
            FeeLib.zeroFee(), 
            FeeLib.zeroFee());
        vm.stopPrank();

        // -- create bundle on pool
        vm.startPrank(registryOwner);
        token.transfer(investor, 10000);
        vm.stopPrank();

        vm.startPrank(investor);
        token.approve(
            address(instanceReader.getComponentInfo(poolNftId).tokenHandler), 
            10000);

        SimplePool spool = SimplePool(address(pool));
        bundleNftId = spool.createBundle(
            bundleFee, 
            10000, 
            SecondsLib.toSeconds(604800), 
            ""
        );
        vm.stopPrank();

        // -- setup product
        vm.startPrank(productOwner);
        product = new SimpleProduct(
            address(registry),
            instanceNftId,
            address(token),
            false,
            address(pool), 
            address(distribution), 
            productFee,
            FeeLib.zeroFee(),
            productOwner
        );

        productNftId = productService.register(address(product));
        vm.stopPrank();
    }
}