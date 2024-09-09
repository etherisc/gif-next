// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../../../lib/forge-std/src/Test.sol";

import {IBundleService} from "../../../contracts/pool/IBundleService.sol";
import {BundleSet} from "../../../contracts/instance/BundleSet.sol";
import {GifTest} from "../../base/GifTest.sol";
import {NftId, NftIdLib} from "../../../contracts/type/NftId.sol";
import {SimpleProduct} from "../../../contracts/examples/unpermissioned/SimpleProduct.sol";
import {IComponents} from "../../../contracts/instance/module/IComponents.sol";
import {IDistribution} from "../../../contracts/instance/module/IDistribution.sol";
import {IPolicy} from "../../../contracts/instance/module/IPolicy.sol";
import {Amount, AmountLib} from "../../../contracts/type/Amount.sol";
import {Fee, FeeLib} from "../../../contracts/type/Fee.sol";
import {UFixedLib} from "../../../contracts/type/UFixed.sol";
import {Seconds, SecondsLib} from "../../../contracts/type/Seconds.sol";
import {Timestamp, TimestampLib, zeroTimestamp} from "../../../contracts/type/Timestamp.sol";
import {IRisk} from "../../../contracts/instance/module/IRisk.sol";
import {RiskId, RiskIdLib, eqRiskId} from "../../../contracts/type/RiskId.sol";
import {ReferralId, ReferralLib} from "../../../contracts/type/Referral.sol";
import {ReferralId, ReferralLib} from "../../../contracts/type/Referral.sol";
import {APPLIED, COLLATERALIZED, CLOSED, DECLINED, PAID, EXPECTED} from "../../../contracts/type/StateId.sol";
import {POLICY} from "../../../contracts/type/ObjectType.sol";
import {DistributorType} from "../../../contracts/type/DistributorType.sol";
import {IPolicyService} from "../../../contracts/product/IPolicyService.sol";

contract TestProduct is GifTest {

    Seconds public sec30;

    mapping(address account => uint previousBalance) public pb;

    function setUp() public override {
        super.setUp();

        _prepareProduct();
        _configureProduct(DEFAULT_BUNDLE_CAPITALIZATION);
        
        sec30 = SecondsLib.toSeconds(30);
    }

    function test_productSetupInfo() public view {

        // check nft id (components -> product)
        uint256 productNftIdInt = product.getNftId().toInt();
        assertTrue(productNftIdInt > 0, "product nft zero");
        assertEq(registry.getObjectInfo(address(distribution)).parentNftId.toInt(), productNftIdInt, "unexpected product nft (distribution)");
        assertEq(registry.getObjectInfo(address(pool)).parentNftId.toInt(), productNftIdInt, "unexpected product nft (pool)");

        // check token handler
        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(productNftId);
        assertTrue(address(componentInfo.tokenHandler) != address(0), "token handler zero");
        assertEq(address(componentInfo.tokenHandler.TOKEN()), address(token), "unexpected token for token handler");

        // check nft id links (product -> components)
        IComponents.ProductInfo memory productInfo = instanceReader.getProductInfo(productNftId);
        assertEq(productInfo.distributionNftId.toInt(), distribution.getNftId().toInt(), "unexpected distribution nft id");
        assertEq(productInfo.poolNftId.toInt(), pool.getNftId().toInt(), "unexpected pool nft id");

        // check fees
        IComponents.FeeInfo memory feeInfo = instanceReader.getFeeInfo(productNftId);
        Fee memory productFee = feeInfo.productFee;
        assertEq(productFee.fractionalFee.toInt(), 0, "product fee not 0");
        assertEq(productFee.fixedFee.toInt(), 0, "product fee not 0");
        Fee memory processingFee = feeInfo.processingFee;
        assertEq(processingFee.fractionalFee.toInt(), 0, "processing fee not 0");
        assertEq(processingFee.fixedFee.toInt(), 0, "processing fee not 0");
    }


    function test_productSetFees() public {

        IComponents.FeeInfo memory feeInfo = instanceReader.getFeeInfo(productNftId);
        Fee memory productFee = feeInfo.productFee;
        assertEq(productFee.fractionalFee.toInt(), 0, "product fee not 0");
        assertEq(productFee.fixedFee.toInt(), 0, "product fee not 0");
        Fee memory processingFee = feeInfo.processingFee;
        assertEq(processingFee.fractionalFee.toInt(), 0, "processing fee not 0");
        assertEq(processingFee.fixedFee.toInt(), 0, "processing fee not 0");
        
        Fee memory newProductFee = FeeLib.toFee(UFixedLib.toUFixed(123,0), 456);
        Fee memory newProcessingFee = FeeLib.toFee(UFixedLib.toUFixed(789,0), 101112);

        vm.startPrank(productOwner);
        product.setFees(newProductFee, newProcessingFee);
        vm.stopPrank();

        feeInfo = instanceReader.getFeeInfo(productNftId);
        productFee = feeInfo.productFee;
        assertEq(productFee.fractionalFee.toInt(), 123, "product fee not 123");
        assertEq(productFee.fixedFee.toInt(), 456, "product fee not 456");

        processingFee = feeInfo.processingFee;
        assertEq(processingFee.fractionalFee.toInt(), 789, "processing fee not 789");
        assertEq(processingFee.fixedFee.toInt(), 101112, "processing fee not 101112");
    }

    function test_productCalculatePremium() public {

        Fee memory productFee = FeeLib.toFee(UFixedLib.zero(), 10);

        vm.startPrank(productOwner);
        product.setFees(productFee, FeeLib.zero());

        bytes memory data = "bla di blubb";
        SimpleProduct dproduct = SimpleProduct(address(product));
        RiskId riskId = dproduct.createRisk("42x4711", data);

        Amount sumInsured = AmountLib.toAmount(1000);
        Seconds  lifetime = SecondsLib.toSeconds(30);
        IPolicy.PremiumInfo memory premiumExpected = pricingService.calculatePremium(
            productNftId,
            riskId,
            sumInsured,
            lifetime,
            "",
            bundleNftId,
            ReferralLib.zero());

        Amount premium = product.calculatePremium(
            sumInsured, 
            riskId, 
            lifetime, 
            "", 
            bundleNftId, 
            ReferralLib.zero());

        assertEq(premiumExpected.premiumAmount.toInt(), 140, "premium not 140 (100 + 10 + 10 + 10 + 10)");
        assertEq(premium.toInt(), premiumExpected.premiumAmount.toInt(), "unexpected premium amount");
    }


    function test_productRiskCreate() public {
        bytes memory data = "bla di blubb";

        // SimpleProduct dproduct = SimpleProduct(address(product));
        vm.startPrank(productOwner);
        RiskId riskId = product.createRisk("42x4711", data);
        vm.stopPrank();

        IRisk.RiskInfo memory riskInfo = instanceReader.getRiskInfo(riskId);
        assertTrue(riskInfo.productNftId.eq(productNftId), "productNftId not set");
        assertEq(riskInfo.data, data, "data not set");
    }


    function test_productRiskUpdate() public {

        bytes memory data = "bla di blubb";

        vm.startPrank(productOwner);
        RiskId riskId = product.createRisk("42x4711", data);
        IRisk.RiskInfo memory riskInfo = instanceReader.getRiskInfo(riskId);

        assertTrue(riskInfo.productNftId.eq(productNftId), "productNftId not set");
        assertEq(riskInfo.data, data, "data not set");

        bytes memory newData = "new data";
        product.updateRisk(riskId, newData);
        vm.stopPrank();

        riskInfo = instanceReader.getRiskInfo(riskId);

        assertTrue(riskInfo.productNftId.eq(productNftId), "productNftId not set");
        assertEq(riskInfo.data, newData, "data not updated to new data");
    }

    function _configureProduct(uint bundleCapital) internal {
        vm.startPrank(distributionOwner);
        Fee memory distributionFee = FeeLib.toFee(UFixedLib.zero(), 10);
        Fee memory minDistributionOwnerFee = FeeLib.toFee(UFixedLib.zero(), 10);
        distribution.setFees(
            distributionFee, 
            minDistributionOwnerFee);
        vm.stopPrank();

        vm.startPrank(poolOwner);
        Fee memory poolFee = FeeLib.toFee(UFixedLib.zero(), 10);
        pool.setFees(
            poolFee, 
            FeeLib.zero(), // staking fees
            FeeLib.zero()); // performance fees
        vm.stopPrank();

        vm.startPrank(registryOwner);
        token.transfer(investor, bundleCapital);
        vm.stopPrank();

        vm.startPrank(investor);
        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(poolNftId);
        token.approve(address(componentInfo.tokenHandler), bundleCapital);

        Fee memory bundleFee = FeeLib.toFee(UFixedLib.zero(), 10);
        (bundleNftId,) = pool.createBundle(
            bundleFee, 
            bundleCapital, 
            SecondsLib.toSeconds(604800), 
            ""
        );
        vm.stopPrank();
    }
}