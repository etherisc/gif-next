// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {console} from "../lib/forge-std/src/Test.sol";

import {TestGifBase} from "./base/TestGifBase.sol";
import {NftId, NftIdLib} from "../contracts/types/NftId.sol";
import {PRODUCT_OWNER_ROLE} from "../contracts/types/RoleId.sol";
import {SimpleProduct} from "./mock/SimpleProduct.sol";
import {SimplePool} from "./mock/SimplePool.sol";
import {IComponents} from "../contracts/instance/module/IComponents.sol";
import {ILifecycle} from "../contracts/instance/base/ILifecycle.sol";
import {ISetup} from "../contracts/instance/module/ISetup.sol";
import {IPolicy} from "../contracts/instance/module/IPolicy.sol";
import {IBundle} from "../contracts/instance/module/IBundle.sol";
import {Fee, FeeLib} from "../contracts/types/Fee.sol";
import {UFixedLib} from "../contracts/types/UFixed.sol";
import {Seconds, SecondsLib} from "../contracts/types/Seconds.sol";
import {Timestamp, TimestampLib, zeroTimestamp} from "../contracts/types/Timestamp.sol";
import {IRisk} from "../contracts/instance/module/IRisk.sol";
import {RiskId, RiskIdLib, eqRiskId} from "../contracts/types/RiskId.sol";
import {ReferralId, ReferralLib} from "../contracts/types/Referral.sol";
import {APPLIED, ACTIVE, COLLATERALIZED, CLOSED} from "../contracts/types/StateId.sol";
import {POLICY} from "../contracts/types/ObjectType.sol";
import {DistributorType} from "../contracts/types/DistributorType.sol";
import {SimpleDistribution} from "./mock/SimpleDistribution.sol";
import {IPolicyService} from "../contracts/instance/service/IPolicyService.sol";

contract TestProduct is TestGifBase {
    using NftIdLib for NftId;

    Seconds public sec30;

    function setUp() public override {
        super.setUp();
        sec30 = SecondsLib.toSeconds(30);
    }

    function test_Product_setupInfo() public {
        _prepareProduct();

        ISetup.ProductSetupInfo memory productSetupInfo = instanceReader.getProductSetupInfo(productNftId);

        // check nft id (components -> product)
        uint256 productNftIdInt = product.getNftId().toInt();
        assertTrue(productNftIdInt > 0, "product nft zero");
        assertEq(product.getProductNftId().toInt(), productNftIdInt, "unexpected product nft (product)");
        assertEq(distribution.getProductNftId().toInt(), productNftIdInt, "unexpected product nft (distribution)");
        assertEq(pool.getProductNftId().toInt(), productNftIdInt, "unexpected product nft (pool)");
        
        // check nft id links (product -> components)
        assertEq(productSetupInfo.distributionNftId.toInt(), distribution.getNftId().toInt(), "unexpected distribution nft id");
        assertEq(productSetupInfo.poolNftId.toInt(), pool.getNftId().toInt(), "unexpected distribution nft id");

        // check token handler
        assertTrue(address(productSetupInfo.tokenHandler) != address(0), "token handler zero");
        assertEq(address(productSetupInfo.tokenHandler.getToken()), address(distribution.getToken()), "unexpected token for token handler");

        // check fees
        Fee memory productFee = productSetupInfo.productFee;
        assertEq(productFee.fractionalFee.toInt(), 0, "product fee not 0");
        assertEq(productFee.fixedFee, 0, "product fee not 0");
        Fee memory processingFee = productSetupInfo.processingFee;
        assertEq(processingFee.fractionalFee.toInt(), 0, "processing fee not 0");
        assertEq(processingFee.fixedFee, 0, "processing fee not 0");
    }


    function test_Product_SetFees() public {
        _prepareProduct();
        vm.startPrank(productOwner);

        ISetup.ProductSetupInfo memory productSetupInfo = instanceReader.getProductSetupInfo(productNftId);
        Fee memory productFee = productSetupInfo.productFee;
        assertEq(productFee.fractionalFee.toInt(), 0, "product fee not 0");
        assertEq(productFee.fixedFee, 0, "product fee not 0");
        Fee memory processingFee = productSetupInfo.processingFee;
        assertEq(processingFee.fractionalFee.toInt(), 0, "processing fee not 0");
        assertEq(processingFee.fixedFee, 0, "processing fee not 0");
        
        Fee memory newProductFee = FeeLib.toFee(UFixedLib.toUFixed(123,0), 456);
        Fee memory newProcessingFee = FeeLib.toFee(UFixedLib.toUFixed(789,0), 101112);
        product.setFees(newProductFee, newProcessingFee);

        productSetupInfo = instanceReader.getProductSetupInfo(productNftId);
        productFee = productSetupInfo.productFee;
        assertEq(productFee.fractionalFee.toInt(), 123, "product fee not 123");
        assertEq(productFee.fixedFee, 456, "product fee not 456");

        processingFee = productSetupInfo.processingFee;
        assertEq(processingFee.fractionalFee.toInt(), 789, "processing fee not 789");
        assertEq(processingFee.fixedFee, 101112, "processing fee not 101112");

        vm.stopPrank();
    }

    function test_Product_calculatePremium() public {
        _prepareProduct();  

        vm.startPrank(productOwner);

        Fee memory productFee = FeeLib.toFee(UFixedLib.zero(), 10);
        product.setFees(productFee, FeeLib.zeroFee());

        RiskId riskId = RiskIdLib.toRiskId("42x4711");
        bytes memory data = "bla di blubb";
        SimpleProduct dproduct = SimpleProduct(address(product));
        dproduct.createRisk(riskId, data);

        uint256 premium = product.calculatePremium(
            1000,
            riskId,
            SecondsLib.toSeconds(30),
            "",
            bundleNftId,
            ReferralLib.zero()
        );
        assertEq(premium, 140, "premium not 140 (100 + 10 + 10 + 10 + 10)");
    }

    function test_Product_createApplication() public {
        _prepareProduct();

        vm.startPrank(productOwner);

        Fee memory productFee = FeeLib.toFee(UFixedLib.zero(), 10);
        product.setFees(productFee, FeeLib.zeroFee());

        RiskId riskId = RiskIdLib.toRiskId("42x4711");
        bytes memory data = "bla di blubb";
        SimpleProduct dproduct = SimpleProduct(address(product));
        dproduct.createRisk(riskId, data);

        NftId policyNftId = dproduct.createApplication(
            customer,
            riskId,
            1000,
            SecondsLib.toSeconds(30),
            "",
            bundleNftId,
            ReferralLib.zero()
        );
        assertTrue(policyNftId.gtz(), "policyNftId was zero");
        assertEq(chainNft.ownerOf(policyNftId.toInt()), customer, "customer not owner of policyNftId");

        assertTrue(instance.getState(policyNftId.toKey32(POLICY())) == APPLIED(), "state not APPLIED");

        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertTrue(eqRiskId(policyInfo.riskId, riskId), "riskId not set");
        assertEq(policyInfo.sumInsuredAmount, 1000, "sumInsuredAmount not set");
        assertEq(policyInfo.lifetime.toInt(), 30, "lifetime not set");
        assertTrue(policyInfo.bundleNftId.eq(bundleNftId), "bundleNftId not set");        
    }

    function test_Product_collateralizeWithoutPayment() public {
        // GIVEN
        _prepareProduct();  

        vm.startPrank(productOwner);

        Fee memory productFee = FeeLib.toFee(UFixedLib.zero(), 10);
        product.setFees(productFee, FeeLib.zeroFee());

        RiskId riskId = RiskIdLib.toRiskId("42x4711");
        bytes memory data = "bla di blubb";
        SimpleProduct dproduct = SimpleProduct(address(product));
        dproduct.createRisk(riskId, data);

        uint sumInsuredAmount = 1000;
        NftId policyNftId = dproduct.createApplication(
            customer,
            riskId,
            sumInsuredAmount,
            SecondsLib.toSeconds(30),
            "",
            bundleNftId,
            ReferralLib.zero()
        );
        assertTrue(policyNftId.gtz(), "policyNftId was zero");
        assertEq(chainNft.ownerOf(policyNftId.toInt()), customer, "customer not owner of policyNftId");

        assertTrue(instance.getState(policyNftId.toKey32(POLICY())) == APPLIED(), "state not APPLIED");

        // WHEN
        bool requirePremiumPayment = false;
        dproduct.collateralize(policyNftId, requirePremiumPayment, TimestampLib.blockTimestamp()); 

        // THEN
        assertTrue(instanceReader.getPolicyState(policyNftId) == ACTIVE(), "policy state not ACTIVE");

        console.log("checking policy info after underwriting");
        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertEq(policyInfo.sumInsuredAmount, 1000, "sumInsuredAmount not 1000");
        assertEq(policyInfo.sumInsuredAmount, sumInsuredAmount, "sumInsuredAmount not 1000");
        assertTrue(policyInfo.activatedAt.gtz(), "activatedAt not set");
        assertTrue(policyInfo.expiredAt.gtz(), "expiredAt not set");
        assertTrue(policyInfo.expiredAt.toInt() == policyInfo.activatedAt.addSeconds(sec30).toInt(), "expiredAt not activatedAt + 30");

        console.log("checking bundle info after underwriting");
        IBundle.BundleInfo memory bundleInfo = instanceReader.getBundleInfo(bundleNftId);
        assertEq(bundleInfo.lockedAmount.toInt(), 1000, "lockedAmount not 1000");
        assertEq(bundleInfo.capitalAmount.toInt(), 10000, "capitalAmount not 10000");

        assertEq(instanceBundleManager.activePolicies(bundleNftId), 1, "expected one active policy");
        assertTrue(instanceBundleManager.getActivePolicy(bundleNftId, 0).eq(policyNftId), "active policy nft id in bundle manager not equal to policy nft id");
    }

    function test_Product_collateralizeWithPayment() public {
        // GIVEN
        vm.startPrank(registryOwner);
        token.transfer(customer, 1000);
        vm.stopPrank();

        _prepareProduct();  

        vm.startPrank(productOwner);

        Fee memory productFee = FeeLib.toFee(UFixedLib.zero(), 10);
        product.setFees(productFee, FeeLib.zeroFee());

        RiskId riskId = RiskIdLib.toRiskId("42x4711");
        bytes memory data = "bla di blubb";
        SimpleProduct dproduct = SimpleProduct(address(product));
        dproduct.createRisk(riskId, data);

        vm.stopPrank();

        vm.startPrank(customer);

        ISetup.ProductSetupInfo memory productSetupInfo = instanceReader.getProductSetupInfo(productNftId);
        token.approve(address(productSetupInfo.tokenHandler), 1000);
        // revert("checkApprove");

        NftId policyNftId = dproduct.createApplication(
            customer,
            riskId,
            1000,
            SecondsLib.toSeconds(30),
            "",
            bundleNftId,
            ReferralLib.zero()
        );
        assertTrue(policyNftId.gtz(), "policyNftId was zero");
        assertEq(chainNft.ownerOf(policyNftId.toInt()), customer, "customer not owner of policyNftId");

        assertTrue(instance.getState(policyNftId.toKey32(POLICY())) == APPLIED(), "state not APPLIED");
        
        vm.stopPrank();

        // WHEN
        vm.startPrank(productOwner);
        bool collectPremiumAmount = true;
        dproduct.collateralize(policyNftId, collectPremiumAmount, TimestampLib.blockTimestamp()); 

        // THEN
        assertTrue(instanceReader.getPolicyState(policyNftId) == ACTIVE(), "policy state not COLLATERALIZED");

        IBundle.BundleInfo memory bundleInfo = instanceReader.getBundleInfo(bundleNftId);
        assertEq(bundleInfo.lockedAmount.toInt(), 1000, "lockedAmount not 1000");
        assertEq(bundleInfo.feeAmount.toInt(), 10, "feeAmount not 10");
        assertEq(bundleInfo.capitalAmount.toInt(), 10000 + 100 - 10, "capitalAmount not 1100");
        
        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertTrue(policyInfo.activatedAt.gtz(), "activatedAt not set");
        assertTrue(policyInfo.expiredAt.gtz(), "expiredAt not set");
        assertTrue(policyInfo.expiredAt.toInt() == policyInfo.activatedAt.addSeconds(sec30).toInt(), "expiredAt not activatedAt + 30");

        assertEq(token.balanceOf(product.getWallet()), 10, "product balance not 10");
        assertEq(token.balanceOf(distribution.getWallet()), 10, "distibution balance not 10");
        assertEq(token.balanceOf(address(customer)), 860, "customer balance not 860");
        assertEq(token.balanceOf(pool.getWallet()), 10120, "pool balance not 10120"); // 10000 + 100 (net premium) + 10 (pool fee) + 10 (bundle fee)

        assertEq(instanceBundleManager.activePolicies(bundleNftId), 1, "expected one active policy");
        assertTrue(instanceBundleManager.getActivePolicy(bundleNftId, 0).eq(policyNftId), "active policy nft id in bundle manager not equal to policy nft id");
    }

    function test_Product_withReferralCollateralizeWithPayment() public {
        // GIVEN
        vm.startPrank(registryOwner);
        token.transfer(customer, 1000);
        vm.stopPrank();

        _prepareProduct();  

        // set product fees and create risk
        vm.startPrank(productOwner);

        Fee memory productFee = FeeLib.toFee(UFixedLib.zero(), 10);
        product.setFees(productFee, FeeLib.zeroFee());

        RiskId riskId = RiskIdLib.toRiskId("42x4711");
        bytes memory data = "bla di blubb";
        SimpleProduct dproduct = SimpleProduct(address(product));
        dproduct.createRisk(riskId, data);

        vm.stopPrank();

        // configure distribution fee and referral
        vm.startPrank(distributionOwner);
        Fee memory minDistributionOwnerFee = FeeLib.toFee(UFixedLib.toUFixed(1, -2), 0);
        Fee memory distributionFee = FeeLib.toFee(UFixedLib.toUFixed(1, -1), 0);
        distribution.setFees(minDistributionOwnerFee, distributionFee);

        DistributorType distributorType = distribution.createDistributorType(
            "Gold",
            UFixedLib.zero(),
            UFixedLib.toUFixed(5, -2),
            UFixedLib.toUFixed(3, -2),
            10,
            14 * 24 * 3600,
            false,
            false,
            "");

        NftId distributorNftId = distribution.createDistributor(
            customer2,
            distributorType,
            "");
        
        SimpleDistribution sdistribution = SimpleDistribution(address(distribution));
        ReferralId referralId = sdistribution.createReferral(
            distributorNftId,
            "GET_A_DISCOUNT",
            UFixedLib.toUFixed(2, -2),
            5,
            TimestampLib.blockTimestamp().addSeconds(SecondsLib.toSeconds(604800)),
            "");

        vm.stopPrank();

        vm.startPrank(customer);

        ISetup.ProductSetupInfo memory productSetupInfo = instanceReader.getProductSetupInfo(productNftId);
        token.approve(address(productSetupInfo.tokenHandler), 1000);
        // revert("checkApprove");

        NftId policyNftId = dproduct.createApplication(
            customer,
            riskId,
            1000,
            SecondsLib.toSeconds(30),
            "",
            bundleNftId,
            referralId
        );
        assertTrue(policyNftId.gtz(), "policyNftId was zero");
        assertEq(chainNft.ownerOf(policyNftId.toInt()), customer, "customer not owner of policyNftId");

        assertTrue(instance.getState(policyNftId.toKey32(POLICY())) == APPLIED(), "state not APPLIED");
        
        vm.stopPrank();

        // WHEN
        vm.startPrank(productOwner);
        bool collectPremiumAmount = true;
        Timestamp activateAt = TimestampLib.blockTimestamp();
        dproduct.collateralize(policyNftId, collectPremiumAmount, activateAt);(policyNftId, collectPremiumAmount, TimestampLib.blockTimestamp()); 

        // THEN
        assertTrue(instanceReader.getPolicyState(policyNftId) == ACTIVE(), "policy state not UNDERWRITTEN");

        assertEq(token.balanceOf(product.getWallet()), 10, "product balance not 10");
        assertEq(token.balanceOf(distribution.getWallet()), 7, "distibution balance not 7");
        assertEq(token.balanceOf(address(customer)), 863, "customer balance not 863");
    }

    function test_Product_collateralizeWithReferralExpired() public {
        // GIVEN
        vm.startPrank(registryOwner);
        token.transfer(customer, 1000);
        vm.stopPrank();

        _prepareProduct();  

        // set product fees and create risk
        vm.startPrank(productOwner);

        Fee memory productFee = FeeLib.toFee(UFixedLib.zero(), 10);
        product.setFees(productFee, FeeLib.zeroFee());

        RiskId riskId = RiskIdLib.toRiskId("42x4711");
        bytes memory data = "bla di blubb";
        SimpleProduct dproduct = SimpleProduct(address(product));
        dproduct.createRisk(riskId, data);

        vm.stopPrank();

        // configure distribution fee and referral
        vm.startPrank(distributionOwner);
        Fee memory minDistributionOwnerFee = FeeLib.toFee(UFixedLib.toUFixed(1, -2), 0);
        Fee memory distributionFee = FeeLib.toFee(UFixedLib.toUFixed(1, -1), 0);
        distribution.setFees(minDistributionOwnerFee, distributionFee);

        DistributorType distributorType = distribution.createDistributorType(
            "Gold",
            UFixedLib.zero(),
            UFixedLib.toUFixed(5, -2),
            UFixedLib.toUFixed(3, -2),
            10,
            14 * 24 * 3600,
            false,
            false,
            "");

        NftId distributorNftId = distribution.createDistributor(
            customer2,
            distributorType,
            "");
        
        SimpleDistribution sdistribution = SimpleDistribution(address(distribution));
        // create short lived referral
        ReferralId referralId = sdistribution.createReferral(
            distributorNftId,
            "GET_A_DISCOUNT",
            UFixedLib.toUFixed(2, -2),
            5,
            TimestampLib.blockTimestamp().addSeconds(SecondsLib.toSeconds(10)),
            "");

        vm.stopPrank();

        vm.startPrank(customer);

        ISetup.ProductSetupInfo memory productSetupInfo = instanceReader.getProductSetupInfo(productNftId);
        token.approve(address(productSetupInfo.tokenHandler), 1000);

        NftId policyNftId = dproduct.createApplication(
            customer,
            riskId,
            1000,
            SecondsLib.toSeconds(60), // policy lifetime
            "",
            bundleNftId,
            referralId
        );
        assertTrue(policyNftId.gtz(), "policyNftId was zero");
        assertEq(chainNft.ownerOf(policyNftId.toInt()), customer, "customer not owner of policyNftId");

        assertTrue(instance.getState(policyNftId.toKey32(POLICY())) == APPLIED(), "state not APPLIED");
        
        vm.stopPrank();

        vm.startPrank(productOwner);
        bool collectPremiumAmount = true;
        
        // WHEN
        // wait 20 seconds to expire referral
        vm.warp(20); 

        // THEN
        Timestamp activationAt = TimestampLib.blockTimestamp();
        vm.expectRevert(
            abi.encodeWithSelector(
                IPolicyService.ErrorIPolicyServicePremiumMismatch.selector, 
                policyNftId, 
                137, 
                140));

        dproduct.collateralize(
            policyNftId, 
            collectPremiumAmount, 
            activationAt);
    }

/*  FIX ME
    function test_collateralize_reverts_on_locked_bundle() public {
        // GIVEN
        _prepareProduct();  

        vm.startPrank(productOwner);

        Fee memory productFee = FeeLib.toFee(UFixedLib.zero(), 10);
        product.setFees(productFee, FeeLib.zeroFee());

        RiskId riskId = RiskIdLib.toRiskId("42x4711");
        bytes memory data = "bla di blubb";
        SimpleProduct dproduct = SimpleProduct(address(product));
        dproduct.createRisk(riskId, data);

        vm.stopPrank();

        vm.startPrank(customer);
        NftId policyNftId = dproduct.createApplication(
            customer,
            riskId,
            1000,
            SecondsLib.toSeconds(30),
            "",
            bundleNftId,
            ReferralLib.zero()
        );
        assertTrue(policyNftId.gtz(), "policyNftId was zero");
        assertEq(chainNft.ownerOf(policyNftId.toInt()), customer, "customer not owner of policyNftId");

        vm.stopPrank();

        assertTrue(instance.getState(policyNftId.toKey32(POLICY())) == APPLIED(), "state not APPLIED");
        vm.startPrank(investor);
        SimplePool spool = SimplePool(address(pool));
        spool.lockBundle(bundleNftId);

        Timestamp timeNow = TimestampLib.blockTimestamp();

        // THEN - WHEN - try collateralize on locked bundle
        vm.expectRevert();
        dproduct.collateralize(policyNftId, false, timeNow); 

        // WHEN - unlock bundle and try collateralize again
        pool.unlockBundle(bundleNftId);
        dproduct.collateralize(policyNftId, false, timeNow);

        // THEN
        assertTrue(instanceReader.getPolicyState(policyNftId) == ACTIVE(), "policy state not COLLATERALIZED");
    }
*/

    function test_activate() public {
        // GIVEN
        _prepareProduct();  

        vm.startPrank(productOwner);

        Fee memory productFee = FeeLib.toFee(UFixedLib.zero(), 10);
        product.setFees(productFee, FeeLib.zeroFee());

        RiskId riskId = RiskIdLib.toRiskId("42x4711");
        bytes memory data = "bla di blubb";
        SimpleProduct dproduct = SimpleProduct(address(product));
        dproduct.createRisk(riskId, data);

        NftId policyNftId = dproduct.createApplication(
            customer,
            riskId,
            1000,
            SecondsLib.toSeconds(30),
            "",
            bundleNftId,
            ReferralLib.zero()
        );
        assertTrue(policyNftId.gtz(), "policyNftId was zero");
        assertEq(chainNft.ownerOf(policyNftId.toInt()), customer, "customer not owner of policyNftId");

        assertTrue(instance.getState(policyNftId.toKey32(POLICY())) == APPLIED(), "state not APPLIED");

        // WHEN
        dproduct.collateralize(policyNftId, false, zeroTimestamp()); 

        // THEN 
        assertTrue(instanceReader.getPolicyState(policyNftId) == COLLATERALIZED(), "policy state not COLLATERALIZED");

        IBundle.BundleInfo memory bundleInfo = instanceReader.getBundleInfo(bundleNftId);
        assertEq(bundleInfo.lockedAmount.toInt(), 1000, "lockedAmount not 1000");

        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertTrue(policyInfo.activatedAt.eqz(), "activatedAt set");
        assertTrue(policyInfo.expiredAt.eqz(), "expiredAt set");
        
        // another WHEN
        dproduct.activate(policyNftId, TimestampLib.blockTimestamp());
        assertTrue(instanceReader.getPolicyState(policyNftId) == ACTIVE(), "policy state not ACTIVE");

        // and THEN
        policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertTrue(policyInfo.activatedAt.gtz(), "activatedAt not set");
        assertTrue(policyInfo.expiredAt.gtz(), "expiredAt not set");
        assertTrue(policyInfo.expiredAt.toInt() == policyInfo.activatedAt.addSeconds(sec30).toInt(), "expiredAt not activatedAt + 30");
    }

    function test_Product_collectPremium() public {
        // GIVEN
        vm.startPrank(registryOwner);
        token.transfer(customer, 1000);
        vm.stopPrank();

        _prepareProduct();  

        vm.startPrank(productOwner);

        Fee memory productFee = FeeLib.toFee(UFixedLib.zero(), 10);
        product.setFees(productFee, FeeLib.zeroFee());

        RiskId riskId = RiskIdLib.toRiskId("42x4711");
        bytes memory data = "bla di blubb";
        SimpleProduct dproduct = SimpleProduct(address(product));
        dproduct.createRisk(riskId, data);

        vm.stopPrank();
        vm.startPrank(customer);
        
        ISetup.ProductSetupInfo memory productSetupInfo = instanceReader.getProductSetupInfo(productNftId);
        token.approve(address(productSetupInfo.tokenHandler), 1000);

        NftId policyNftId = dproduct.createApplication(
            customer,
            riskId,
            1000,
            SecondsLib.toSeconds(30),
            "",
            bundleNftId,
            ReferralLib.zero()
        );

        vm.stopPrank();
        vm.startPrank(productOwner);

        dproduct.collateralize(policyNftId, false, zeroTimestamp()); 
        
        assertTrue(policyNftId.gtz(), "policyNftId was zero");
        assertEq(chainNft.ownerOf(policyNftId.toInt()), customer, "customer not owner of policyNftId");

        assertTrue(instance.getState(policyNftId.toKey32(POLICY())) == COLLATERALIZED(), "state not COLLATERALIZED");
        
        IBundle.BundleInfo memory bundleInfoBefore = instanceReader.getBundleInfo(bundleNftId);
        assertEq(bundleInfoBefore.lockedAmount.toInt(), 1000, "lockedAmount not 1000 (before)");
        assertEq(bundleInfoBefore.capitalAmount.toInt(), 10000, "capitalAmount not 10000 (before)");

        assertEq(token.balanceOf(product.getWallet()), 0, "product balance not 0 (before)");
        assertEq(token.balanceOf(address(customer)), 1000, "customer balance not 1000 (before)");
        assertEq(token.balanceOf(pool.getWallet()), 10000, "pool balance not 10000 (before)");

        // WHEN
        dproduct.collectPremium(policyNftId, TimestampLib.blockTimestamp());
        
        // THEN
        assertTrue(instanceReader.getPolicyState(policyNftId) == ACTIVE(), "policy state not ACTIVE");

        IBundle.BundleInfo memory bundleInfo = instanceReader.getBundleInfo(bundleNftId);
        assertEq(bundleInfo.lockedAmount.toInt(), 1000, "lockedAmount not 1000");
        assertEq(bundleInfo.feeAmount.toInt(), 10, "feeAmount not 10");
        assertEq(bundleInfo.capitalAmount.toInt(), 10000 + 100 - 10, "capitalAmount not 1100");

        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertTrue(policyInfo.activatedAt.gtz(), "activatedAt not set");
        assertTrue(policyInfo.expiredAt.gtz(), "expiredAt not set");
        assertTrue(policyInfo.expiredAt.toInt() == policyInfo.activatedAt.addSeconds(sec30).toInt(), "expiredAt not activatedAt + 30");

        assertEq(token.balanceOf(product.getWallet()), 10, "product balance not 10");
        assertEq(token.balanceOf(distribution.getWallet()), 10, "distibution balance not 10");
        assertEq(token.balanceOf(address(customer)), 860, "customer balance not 860");
        assertEq(token.balanceOf(pool.getWallet()), 10120, "pool balance not 10120");
    }

    function test_Product_close() public {
        // GIVEN
        vm.startPrank(registryOwner);
        token.transfer(customer, 1000);
        vm.stopPrank();

        _prepareProduct();  

        vm.startPrank(productOwner);

        Fee memory productFee = FeeLib.toFee(UFixedLib.zero(), 10);
        product.setFees(productFee, FeeLib.zeroFee());

        RiskId riskId = RiskIdLib.toRiskId("42x4711");
        bytes memory data = "bla di blubb";
        SimpleProduct dproduct = SimpleProduct(address(product));
        dproduct.createRisk(riskId, data);

        vm.stopPrank();

        vm.startPrank(customer);

        ISetup.ProductSetupInfo memory productSetupInfo = instanceReader.getProductSetupInfo(productNftId);
        token.approve(address(productSetupInfo.tokenHandler), 1000);
        // revert("checkApprove");

        NftId policyNftId = dproduct.createApplication(
            customer,
            riskId,
            1000,
            SecondsLib.toSeconds(30),
            "",
            bundleNftId,
            ReferralLib.zero()
        );
        vm.stopPrank();

        vm.startPrank(productOwner);
        dproduct.collateralize(policyNftId, true, TimestampLib.blockTimestamp()); 

        assertTrue(instanceReader.getPolicyState(policyNftId) == ACTIVE(), "policy state not COLLATERALIZED");

        // WHEN
        vm.warp(100); // warp 100 seconds
        dproduct.close(policyNftId);

        // THEN
        assertTrue(instanceReader.getPolicyState(policyNftId) == CLOSED(), "policy state not CLOSE");

        IBundle.BundleInfo memory bundleInfo = instanceReader.getBundleInfo(bundleNftId);
        assertEq(bundleInfo.lockedAmount.toInt(), 0, "lockedAmount not 1000");
        assertEq(bundleInfo.feeAmount.toInt(), 10, "feeAmount not 10");
        assertEq(bundleInfo.capitalAmount.toInt(), 10000 + 100 - 10, "capitalAmount not 1100");
        
        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertTrue(policyInfo.closedAt.gtz(), "expiredAt not set");
        
        assertEq(token.balanceOf(address(pool)), 10120, "pool balance not 10120"); // 100 (netPremium) + 10 (poolFee) + 10 (bundleFee)

        assertEq(instanceBundleManager.activePolicies(bundleNftId), 0, "expected no active policy");
    }

    function test_createRisk() public {
        _prepareProduct();
        vm.startPrank(productOwner);

        RiskId riskId = RiskIdLib.toRiskId("42x4711");
        bytes memory data = "bla di blubb";

        SimpleProduct dproduct = SimpleProduct(address(product));
        dproduct.createRisk(riskId, data);
        IRisk.RiskInfo memory riskInfo = instanceReader.getRiskInfo(riskId);

        assertTrue(riskInfo.productNftId.eq(productNftId), "productNftId not set");
        assertEq(riskInfo.data, data, "data not set");

        vm.stopPrank();
    }

    function test_updateRisk() public {
        _prepareProduct();
        vm.startPrank(productOwner);

        RiskId riskId = RiskIdLib.toRiskId("42x4711");
        bytes memory data = "bla di blubb";

        SimpleProduct dproduct = SimpleProduct(address(product));
        dproduct.createRisk(riskId, data);
        IRisk.RiskInfo memory riskInfo = instanceReader.getRiskInfo(riskId);

        assertTrue(riskInfo.productNftId.eq(productNftId), "productNftId not set");
        assertEq(riskInfo.data, data, "data not set");

        bytes memory newData = "new data";
        dproduct.updateRisk(riskId, newData);

        riskInfo = instanceReader.getRiskInfo(riskId);

        assertTrue(riskInfo.productNftId.eq(productNftId), "productNftId not set");
        assertEq(riskInfo.data, newData, "data not updated to new data");
    }

    function _prepareProduct() internal {
        vm.startPrank(instanceOwner);
        instanceAccessManager.grantRole(PRODUCT_OWNER_ROLE(), productOwner);
        vm.stopPrank();

        _prepareDistributionAndPool();

        vm.startPrank(productOwner);
        product = new SimpleProduct(
            address(registry),
            instanceNftId,
            address(token),
            false,
            address(pool), 
            address(distribution),
            FeeLib.zeroFee(),
            FeeLib.zeroFee(),
            productOwner
        );
        
        productNftId = productService.register(address(product));
        vm.stopPrank();

        vm.startPrank(distributionOwner);
        Fee memory distributionFee = FeeLib.toFee(UFixedLib.zero(), 10);
        Fee memory minDistributionOwnerFee = FeeLib.toFee(UFixedLib.zero(), 10);
        distribution.setFees(minDistributionOwnerFee, distributionFee);
        vm.stopPrank();

        vm.startPrank(poolOwner);
        Fee memory poolFee = FeeLib.toFee(UFixedLib.zero(), 10);
        pool.setFees(poolFee, FeeLib.zeroFee(), FeeLib.zeroFee());
        vm.stopPrank();

        vm.startPrank(registryOwner);
        token.transfer(investor, 10000);
        vm.stopPrank();

        vm.startPrank(investor);
        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(poolNftId);
        token.approve(address(componentInfo.tokenHandler), 10000);

        Fee memory bundleFee = FeeLib.toFee(UFixedLib.zero(), 10);
        SimplePool spool = SimplePool(address(pool));
        bundleNftId = spool.createBundle(
            bundleFee, 
            10000, 
            SecondsLib.toSeconds(604800), 
            ""
        );
        vm.stopPrank();
    }

}
