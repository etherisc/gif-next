// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../lib/forge-std/src/Test.sol";

import {GifTest} from "./base/GifTest.sol";
import {NftId, NftIdLib} from "../contracts/type/NftId.sol";
import {PRODUCT_OWNER_ROLE} from "../contracts/type/RoleId.sol";
import {SimpleProduct} from "./mock/SimpleProduct.sol";
import {SimplePool} from "./mock/SimplePool.sol";
import {IComponents} from "../contracts/instance/module/IComponents.sol";
import {ILifecycle} from "../contracts/shared/ILifecycle.sol";
import {IPolicy} from "../contracts/instance/module/IPolicy.sol";
import {IBundle} from "../contracts/instance/module/IBundle.sol";
import {Amount, AmountLib} from "../contracts/type/Amount.sol";
import {Fee, FeeLib} from "../contracts/type/Fee.sol";
import {UFixedLib} from "../contracts/type/UFixed.sol";
import {Seconds, SecondsLib} from "../contracts/type/Seconds.sol";
import {Timestamp, TimestampLib, zeroTimestamp} from "../contracts/type/Timestamp.sol";
import {IRisk} from "../contracts/instance/module/IRisk.sol";
import {RiskId, RiskIdLib, eqRiskId} from "../contracts/type/RiskId.sol";
import {ReferralId, ReferralLib} from "../contracts/type/Referral.sol";
import {APPLIED, ACTIVE, COLLATERALIZED, CLOSED} from "../contracts/type/StateId.sol";
import {ReferralId, ReferralLib} from "../contracts/type/Referral.sol";
import {APPLIED, ACTIVE, COLLATERALIZED, CLOSED} from "../contracts/type/StateId.sol";
import {POLICY} from "../contracts/type/ObjectType.sol";
import {DistributorType} from "../contracts/type/DistributorType.sol";
import {SimpleDistribution} from "./mock/SimpleDistribution.sol";
import {IPolicyService} from "../contracts/product/IPolicyService.sol";

contract TestProduct is GifTest {
    using NftIdLib for NftId;

    Seconds public sec30;

    mapping(address account => uint previousBalance) public pb;

    function setUp() public override {
        super.setUp();
        sec30 = SecondsLib.toSeconds(30);
    }

    function test_productSetupInfo() public {
        _prepareProductLocal();

        // check nft id (components -> product)
        uint256 productNftIdInt = product.getNftId().toInt();
        assertTrue(productNftIdInt > 0, "product nft zero");
        assertEq(distribution.getProductNftId().toInt(), productNftIdInt, "unexpected product nft (distribution)");
        assertEq(pool.getProductNftId().toInt(), productNftIdInt, "unexpected product nft (pool)");

        // check token handler
        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(productNftId);
        assertTrue(address(componentInfo.tokenHandler) != address(0), "token handler zero");
        assertEq(address(componentInfo.tokenHandler.getToken()), address(token), "unexpected token for token handler");

        // check nft id links (product -> components)
        IComponents.ProductInfo memory productInfo = instanceReader.getProductInfo(productNftId);
        assertEq(productInfo.distributionNftId.toInt(), distribution.getNftId().toInt(), "unexpected distribution nft id");
        assertEq(productInfo.poolNftId.toInt(), pool.getNftId().toInt(), "unexpected pool nft id");

        // check fees
        Fee memory productFee = productInfo.productFee;
        assertEq(productFee.fractionalFee.toInt(), 0, "product fee not 0");
        assertEq(productFee.fixedFee, 0, "product fee not 0");
        Fee memory processingFee = productInfo.processingFee;
        assertEq(processingFee.fractionalFee.toInt(), 0, "processing fee not 0");
        assertEq(processingFee.fixedFee, 0, "processing fee not 0");
    }


    function test_productSetFees() public {
        _prepareProductLocal();
        vm.startPrank(productOwner);

        IComponents.ProductInfo memory productInfo = instanceReader.getProductInfo(productNftId);
        Fee memory productFee = productInfo.productFee;
        assertEq(productFee.fractionalFee.toInt(), 0, "product fee not 0");
        assertEq(productFee.fixedFee, 0, "product fee not 0");
        Fee memory processingFee = productInfo.processingFee;
        assertEq(processingFee.fractionalFee.toInt(), 0, "processing fee not 0");
        assertEq(processingFee.fixedFee, 0, "processing fee not 0");
        
        Fee memory newProductFee = FeeLib.toFee(UFixedLib.toUFixed(123,0), 456);
        Fee memory newProcessingFee = FeeLib.toFee(UFixedLib.toUFixed(789,0), 101112);
        product.setFees(newProductFee, newProcessingFee);

        productInfo = instanceReader.getProductInfo(productNftId);
        productFee = productInfo.productFee;
        assertEq(productFee.fractionalFee.toInt(), 123, "product fee not 123");
        assertEq(productFee.fixedFee, 456, "product fee not 456");

        processingFee = productInfo.processingFee;
        assertEq(processingFee.fractionalFee.toInt(), 789, "processing fee not 789");
        assertEq(processingFee.fixedFee, 101112, "processing fee not 101112");

        vm.stopPrank();
    }

    function test_productCalculatePremium() public {
        _prepareProductLocal();  

        vm.startPrank(productOwner);

        Fee memory productFee = FeeLib.toFee(UFixedLib.zero(), 10);
        product.setFees(productFee, FeeLib.zero());

        RiskId riskId = RiskIdLib.toRiskId("42x4711");
        bytes memory data = "bla di blubb";
        SimpleProduct dproduct = SimpleProduct(address(product));
        dproduct.createRisk(riskId, data);

        Amount sumInsured = AmountLib.toAmount(1000);
        Seconds  lifetime = SecondsLib.toSeconds(30);
        IPolicy.Premium memory premiumExpected = pricingService.calculatePremium(
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

        assertEq(premiumExpected.premiumAmount, 140, "premium not 140 (100 + 10 + 10 + 10 + 10)");
        assertEq(premium.toInt(), premiumExpected.premiumAmount, "unexpected premium amount");
    }

    function test_productCreateApplication() public {
        _prepareProductLocal();

        vm.startPrank(productOwner);

        Fee memory productFee = FeeLib.toFee(UFixedLib.zero(), 10);
        product.setFees(productFee, FeeLib.zero());

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
        assertEq(core.chainNft.ownerOf(policyNftId.toInt()), customer, "customer not owner of policyNftId");

        assertTrue(instance.getInstanceStore().getState(policyNftId.toKey32(POLICY())) == APPLIED(), "state not APPLIED");

        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertTrue(eqRiskId(policyInfo.riskId, riskId), "riskId not set");
        assertEq(policyInfo.sumInsuredAmount.toInt(), 1000, "sumInsuredAmount not set");
        assertEq(policyInfo.lifetime.toInt(), 30, "lifetime not set");
        assertTrue(policyInfo.bundleNftId.eq(bundleNftId), "bundleNftId not set");        
    }

    function test_productCollateralizeWithoutPayment() public {
        // GIVEN
        _prepareProductLocal();  

        vm.startPrank(productOwner);

        // set test specific fees
        Fee memory productFee = FeeLib.toFee(UFixedLib.zero(), 10);
        product.setFees(productFee, FeeLib.zero());

        // create test specific risk
        RiskId riskId = RiskIdLib.toRiskId("42x4711");
        bytes memory data = "bla di blubb";
        product.createRisk(riskId, data);

        // crete application
        uint sumInsuredAmount = 1000;
        Seconds lifetime = SecondsLib.toSeconds(30);
        bytes memory applicationData = "";
        ReferralId referralId = ReferralLib.zero();
        NftId policyNftId = product.createApplication(
            customer,
            riskId,
            sumInsuredAmount,
            lifetime,
            applicationData,
            bundleNftId,
            referralId
        );

        assertTrue(policyNftId.gtz(), "policyNftId was zero");
        assertEq(core.chainNft.ownerOf(policyNftId.toInt()), customer, "customer not owner of policyNftId");
        assertTrue(instance.getInstanceStore().getState(policyNftId.toKey32(POLICY())) == APPLIED(), "state not APPLIED");

        vm.stopPrank();

        // WHEN - collateralize application
        bool requirePremiumPayment = false;
        product.collateralize(policyNftId, requirePremiumPayment, TimestampLib.blockTimestamp()); 

        // THEN
        assertTrue(instanceReader.getPolicyState(policyNftId) == ACTIVE(), "policy state not ACTIVE");

        console.log("checking policy info after underwriting");
        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertEq(policyInfo.sumInsuredAmount.toInt(), 1000, "sumInsuredAmount not 1000");
        assertEq(policyInfo.sumInsuredAmount.toInt(), sumInsuredAmount, "sumInsuredAmount not 1000");
        assertTrue(policyInfo.activatedAt.gtz(), "activatedAt not set");
        assertTrue(policyInfo.expiredAt.gtz(), "expiredAt not set");
        assertTrue(policyInfo.expiredAt.toInt() == policyInfo.activatedAt.addSeconds(sec30).toInt(), "expiredAt not activatedAt + 30");

        console.log("checking bundle amounts after underwriting");
        (Amount amount, Amount lockedAmount, Amount feeAmount) = instanceStore.getAmounts(bundleNftId);
        assertEq(amount.toInt(), DEFAULT_BUNDLE_CAPITALIZATION, "unexpected bundle amount (1)");
        assertEq(lockedAmount.toInt(), sumInsuredAmount, "unexpected locked amount");
        assertEq(feeAmount.toInt(), 0, "unexpected bundle fee amount");

        assertEq(instanceBundleSet.activePolicies(bundleNftId), 1, "expected one active policy");
        assertTrue(instanceBundleSet.getActivePolicy(bundleNftId, 0).eq(policyNftId), "active policy nft id in bundle manager not equal to policy nft id");
    }

    function test_productCollateralizeWithPayment() public {
        // GIVEN
        vm.startPrank(registryOwner);
        token.transfer(customer, 1000);
        vm.stopPrank();

        _prepareProductLocal();  

        vm.startPrank(productOwner);
        Fee memory productFee = FeeLib.toFee(UFixedLib.zero(), 10);
        product.setFees(productFee, FeeLib.zero());

        RiskId riskId = RiskIdLib.toRiskId("42x4711");
        bytes memory data = "bla di blubb";
        product.createRisk(riskId, data);
        vm.stopPrank();

        vm.startPrank(customer);

        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(productNftId);
        token.approve(address(componentInfo.tokenHandler), 1000);
        // revert("checkApprove");

        // crete application
        // solhint-disable-next-line 
        console.log("before application creation");

        uint sumInsuredAmount = 1000;
        Seconds lifetime = SecondsLib.toSeconds(30);
        bytes memory applicationData = "";
        ReferralId referralId = ReferralLib.zero();
        NftId policyNftId = product.createApplication(
            customer,
            riskId,
            sumInsuredAmount,
            lifetime,
            applicationData,
            bundleNftId,
            referralId
        );

        vm.stopPrank();

        assertTrue(policyNftId.gtz(), "policyNftId was zero");
        assertEq(core.chainNft.ownerOf(policyNftId.toInt()), customer, "customer not owner of policyNftId");
        assertTrue(instance.getInstanceStore().getState(policyNftId.toKey32(POLICY())) == APPLIED(), "state not APPLIED");
        
        // calculate expected premium/fee amounts
        IPolicy.Premium memory ep = pricingService.calculatePremium(
            productNftId, 
            riskId, 
            AmountLib.toAmount(sumInsuredAmount), 
            lifetime, 
            applicationData, 
            bundleNftId, 
            referralId);

        // recored token balances before collateralization
        pb[product.getWallet()] = token.balanceOf(product.getWallet());
        pb[distribution.getWallet()] = token.balanceOf(distribution.getWallet());
        pb[customer] = token.balanceOf(customer);
        pb[pool.getWallet()] = token.balanceOf(pool.getWallet());

        // WHEN
        vm.startPrank(productOwner);

        // solhint-disable-next-line 
        console.log("before collateralization of", policyNftId.toInt());
        product.collateralize(policyNftId, true, TimestampLib.blockTimestamp()); 

        // THEN
        assertTrue(instanceReader.getPolicyState(policyNftId) == ACTIVE(), "policy state not COLLATERALIZED");

        // solhint-disable-next-line 
        console.log("checking bundle amounts after underwriting");
        (Amount amount, Amount lockedAmount, Amount feeAmount) = instanceStore.getAmounts(bundleNftId);
        uint bundleFee = ep.bundleFeeFixAmount + ep.bundleFeeVarAmount;
        uint netPremium = ep.netPremiumAmount;

        assertEq(amount.toInt(), DEFAULT_BUNDLE_CAPITALIZATION + netPremium + bundleFee, "unexpected bundle amount (2)");
        assertEq(lockedAmount.toInt(), sumInsuredAmount, "unexpected locked amount");
        assertEq(feeAmount.toInt(), bundleFee, "unexpected bundle fee amount");

        // solhint-disable-next-line 
        console.log("checking pool amounts after underwriting");
        (Amount poolAmount,, Amount poolFeeAmount) = instanceStore.getAmounts(bundleNftId);
        assertEq(poolFeeAmount.toInt(), 10, "unexpected pool fee amount");

        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertTrue(policyInfo.activatedAt.gtz(), "activatedAt not set");
        assertTrue(policyInfo.expiredAt.gtz(), "expiredAt not set");
        assertTrue(policyInfo.expiredAt.toInt() == policyInfo.activatedAt.addSeconds(sec30).toInt(), "expiredAt not activatedAt + 30");

        // solhint-disable-next-line 
        console.log("checking token balances after underwriting");
        assertEq(token.balanceOf(product.getWallet()) - pb[product.getWallet()], 10, "unexpected product balance");
        assertEq(token.balanceOf(distribution.getWallet()) - pb[distribution.getWallet()], 10, "unexpected distibution balance");
        assertEq(token.balanceOf(customer), pb[customer] - ep.premiumAmount, "unexpected customer balance");
        assertEq(token.balanceOf(pool.getWallet()) - pb[pool.getWallet()], 120, "unexpected pool balance"); // 100 (net premium) + 10 (pool fee) + 10 (bundle fee)

        assertEq(instanceBundleSet.activePolicies(bundleNftId), 1, "expected one active policy");
        assertTrue(instanceBundleSet.getActivePolicy(bundleNftId, 0).eq(policyNftId), "active policy nft id in bundle manager not equal to policy nft id");
    }

    function test_productWithReferralCollateralizeWithPayment() public {
        // GIVEN
        vm.startPrank(registryOwner);
        token.transfer(customer, 1000);
        vm.stopPrank();

        _prepareProductLocal();  

        // set product fees and create risk
        Fee memory productFee = FeeLib.toFee(UFixedLib.zero(), 10);
        RiskId riskId = RiskIdLib.toRiskId("42x4711");
        bytes memory data = "bla di blubb";

        vm.startPrank(productOwner);
        product.setFees(productFee, FeeLib.zero());
        product.createRisk(riskId, data);
        vm.stopPrank();

        // configure distribution fee and referral
        Fee memory distributionFee = FeeLib.toFee(UFixedLib.toUFixed(1, -1), 0);
        Fee memory minDistributionOwnerFee = FeeLib.toFee(UFixedLib.toUFixed(1, -2), 0);

        vm.startPrank(distributionOwner);
        distribution.setFees(distributionFee, minDistributionOwnerFee);
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
        vm.stopPrank();

        vm.startPrank(customer2);
        ReferralId referralId = distribution.createReferral(
            "GET_A_DISCOUNT",
            UFixedLib.toUFixed(2, -2),
            5,
            TimestampLib.blockTimestamp().addSeconds(SecondsLib.toSeconds(604800)),
            "");

        vm.stopPrank();

        vm.startPrank(customer);

        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(productNftId);
        token.approve(address(componentInfo.tokenHandler), 1000);
        // revert("checkApprove");

        uint sumInsured = 1000;
        Seconds lifetime = SecondsLib.toSeconds(30);
        NftId policyNftId = product.createApplication(
            customer,
            riskId,
            sumInsured,
            lifetime,
            "",
            bundleNftId,
            referralId
        );

        assertTrue(policyNftId.gtz(), "policyNftId was zero");
        assertEq(core.chainNft.ownerOf(policyNftId.toInt()), customer, "customer not owner of policyNftId");

        assertTrue(instance.getInstanceStore().getState(policyNftId.toKey32(POLICY())) == APPLIED(), "state not APPLIED");
        
        vm.stopPrank();

        // remember customer balance before collateralizaion and premium payment
        // solhint-disable
        console.log("product fee (before)", instanceReader.getFeeAmount(productNftId).toInt());
        console.log("distribution fee (before)", instanceReader.getFeeAmount(distributionNftId).toInt());
        console.log("pool fee (before)", instanceReader.getFeeAmount(poolNftId).toInt());
        console.log("bundle fee (before)", instanceReader.getFeeAmount(bundleNftId).toInt());
        // solhint-enable

        pb[customer] = token.balanceOf(customer);

        // calculate premium
        IPolicy.Premium memory premiumExpected = pricingService.calculatePremium(
            productNftId,
            riskId,
            AmountLib.toAmount(sumInsured),
            lifetime,
            "",
            bundleNftId,
            referralId);

        assertEq(premiumExpected.premiumAmount, 137, "unexpected premium amount");
    
        // WHEN
        vm.startPrank(productOwner);
        bool collectPremiumAmount = true;
        Timestamp activateAt = TimestampLib.blockTimestamp();
        product.collateralize(policyNftId, collectPremiumAmount, activateAt);

        // THEN
        assertTrue(instanceReader.getPolicyState(policyNftId) == ACTIVE(), "policy state not UNDERWRITTEN");

        assertEq(token.balanceOf(product.getWallet()), 10, "product balance not 10");
        assertEq(token.balanceOf(distribution.getWallet()), 7, "distibution balance not 7");
        assertEq(pb[customer] - token.balanceOf(customer), premiumExpected.premiumAmount, "customer balance not 863");

        // solhint-disable
        console.log("product fee (after)", instanceReader.getFeeAmount(productNftId).toInt());
        console.log("distribution fee (after)", instanceReader.getFeeAmount(distributionNftId).toInt());
        console.log("pool fee (after)", instanceReader.getFeeAmount(poolNftId).toInt());
        console.log("bundle fee (after)", instanceReader.getFeeAmount(bundleNftId).toInt());
        // solhint-enable

        IComponents.ComponentInfo memory poolComponentInfo = instanceReader.getComponentInfo(poolNftId);
        assertEq(instanceReader.getFeeAmount(poolNftId).toInt(), 10, "pool fee amount not 10");
    }

    function test_productCollateralizeWithReferralExpired() public {
        // GIVEN
        vm.startPrank(registryOwner);
        token.transfer(customer, 1000);
        vm.stopPrank();

        _prepareProductLocal();  

        // set product fees and create risk
        vm.startPrank(productOwner);

        Fee memory productFee = FeeLib.toFee(UFixedLib.zero(), 10);
        product.setFees(productFee, FeeLib.zero());

        RiskId riskId = RiskIdLib.toRiskId("42x4711");
        bytes memory data = "bla di blubb";
        product.createRisk(riskId, data);

        vm.stopPrank();

        // configure distribution fee and referral
        vm.startPrank(distributionOwner);
        Fee memory distributionFee = FeeLib.toFee(UFixedLib.toUFixed(1, -1), 0);
        Fee memory minDistributionOwnerFee = FeeLib.toFee(UFixedLib.toUFixed(1, -2), 0);
        distribution.setFees(distributionFee, minDistributionOwnerFee);

        vm.startPrank(distributionOwner);
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
        vm.stopPrank();
        
        // create short lived referral
        vm.startPrank(customer2);
        ReferralId referralId = distribution.createReferral(
            "GET_A_DISCOUNT",
            UFixedLib.toUFixed(2, -2),
            5,
            TimestampLib.blockTimestamp().addSeconds(SecondsLib.toSeconds(10)),
            "");

        vm.stopPrank();

        vm.startPrank(customer);

        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(productNftId);
        token.approve(address(componentInfo.tokenHandler), 1000);

        NftId policyNftId = product.createApplication(
            customer,
            riskId,
            1000,
            SecondsLib.toSeconds(60), // policy lifetime
            "",
            bundleNftId,
            referralId
        );
        assertTrue(policyNftId.gtz(), "policyNftId was zero");
        assertEq(core.chainNft.ownerOf(policyNftId.toInt()), customer, "customer not owner of policyNftId");

        assertTrue(instance.getInstanceStore().getState(policyNftId.toKey32(POLICY())) == APPLIED(), "state not APPLIED");
        
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
                IPolicyService.ErrorPolicyServicePremiumHigherThanExpected.selector, 
                AmountLib.toAmount(137), 
                AmountLib.toAmount(140)));

        product.collateralize(
            policyNftId, 
            collectPremiumAmount, 
            activationAt);
    }


    function test_productCollateralizeRevertsOnLockedBundle() public {
        // GIVEN
        _prepareProductLocal();  

        vm.startPrank(productOwner);

        Fee memory productFee = FeeLib.toFee(UFixedLib.zero(), 10);
        product.setFees(productFee, FeeLib.zero());

        RiskId riskId = RiskIdLib.toRiskId("42x4711");
        bytes memory data = "bla di blubb";
        product.createRisk(riskId, data);

        vm.stopPrank();

        vm.startPrank(customer);
        NftId policyNftId = product.createApplication(
            customer,
            riskId,
            1000,
            SecondsLib.toSeconds(30),
            "",
            bundleNftId,
            ReferralLib.zero()
        );
        assertTrue(policyNftId.gtz(), "policyNftId was zero");
        assertEq(core.chainNft.ownerOf(policyNftId.toInt()), customer, "customer not owner of policyNftId");

        vm.stopPrank();

        assertEq(instanceReader.getPolicyState(policyNftId).toInt(), APPLIED().toInt(), "unexpected policy state (not APPLIED)");

        vm.startPrank(investor);
        pool.lockBundle(bundleNftId);

        Timestamp timeNow = TimestampLib.blockTimestamp();

        // THEN - WHEN - try collateralize on locked bundle
        vm.expectRevert();
        product.collateralize(policyNftId, false, timeNow); 

        // WHEN - unlock bundle and try collateralize again
        pool.unlockBundle(bundleNftId);
        product.collateralize(policyNftId, false, timeNow);

        // THEN
        assertEq(instanceReader.getPolicyState(policyNftId).toInt(), ACTIVE().toInt(), "unexpected policy state (not ACTIVE)");
    }


    function test_productPolicyActivate() public {
        // GIVEN
        _prepareProductLocal();  

        vm.startPrank(productOwner);

        Fee memory productFee = FeeLib.toFee(UFixedLib.zero(), 10);
        product.setFees(productFee, FeeLib.zero());

        RiskId riskId = RiskIdLib.toRiskId("42x4711");
        bytes memory data = "bla di blubb";
        product.createRisk(riskId, data);

        uint sumInsuredAmount = 1000;
        NftId policyNftId = product.createApplication(
            customer,
            riskId,
            sumInsuredAmount,
            SecondsLib.toSeconds(30),
            "",
            bundleNftId,
            ReferralLib.zero()
        );
        assertTrue(policyNftId.gtz(), "policyNftId was zero");
        assertEq(core.chainNft.ownerOf(policyNftId.toInt()), customer, "customer not owner of policyNftId");

        assertTrue(instance.getInstanceStore().getState(policyNftId.toKey32(POLICY())) == APPLIED(), "state not APPLIED");

        // WHEN
        product.collateralize(policyNftId, false, zeroTimestamp()); 

        // THEN 
        assertTrue(instanceReader.getPolicyState(policyNftId) == COLLATERALIZED(), "policy state not COLLATERALIZED");

        console.log("checking bundle amounts after collateralizaion");
        (Amount amount, Amount lockedAmount, Amount feeAmount) = instanceStore.getAmounts(bundleNftId);
        assertEq(amount.toInt(), DEFAULT_BUNDLE_CAPITALIZATION, "unexpected bundle amount (3)");
        assertEq(lockedAmount.toInt(), sumInsuredAmount, "unexpected locked amount");
        assertEq(feeAmount.toInt(), 0, "unexpected bundle fee amount");

        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertTrue(policyInfo.activatedAt.eqz(), "activatedAt set");
        assertTrue(policyInfo.expiredAt.eqz(), "expiredAt set");
        
        // another WHEN
        product.activate(policyNftId, TimestampLib.blockTimestamp());
        assertTrue(instanceReader.getPolicyState(policyNftId) == ACTIVE(), "policy state not ACTIVE");

        // and THEN
        policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertTrue(policyInfo.activatedAt.gtz(), "activatedAt not set");
        assertTrue(policyInfo.expiredAt.gtz(), "expiredAt not set");
        assertTrue(policyInfo.expiredAt.toInt() == policyInfo.activatedAt.addSeconds(sec30).toInt(), "expiredAt not activatedAt + 30");
    }

    function test_productPolicyCollectPremium() public {
        // GIVEN
        vm.startPrank(registryOwner);
        token.transfer(customer, 1000);
        vm.stopPrank();

        _prepareProductLocal();  

        vm.startPrank(productOwner);

        Fee memory productFee = FeeLib.toFee(UFixedLib.zero(), 10);
        product.setFees(productFee, FeeLib.zero());

        RiskId riskId = RiskIdLib.toRiskId("42x4711");
        bytes memory data = "bla di blubb";
        product.createRisk(riskId, data);

        vm.stopPrank();
        vm.startPrank(customer);
        
        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(productNftId);
        token.approve(address(componentInfo.tokenHandler), 1000);

        // solhint-disable-next-line 
        console.log("before application creation");

        uint sumInsuredAmount = 1000;
        Seconds lifetime = SecondsLib.toSeconds(30);
        bytes memory applicationData = "";
        ReferralId referralId = ReferralLib.zero();
        NftId policyNftId = product.createApplication(
            customer,
            riskId,
            sumInsuredAmount,
            lifetime,
            applicationData,
            bundleNftId,
            referralId
        );

        vm.stopPrank();

        // calculate expected premium/fee amounts
        IPolicy.Premium memory ep = pricingService.calculatePremium(
            productNftId, 
            riskId, 
            AmountLib.toAmount(sumInsuredAmount), 
            lifetime, 
            applicationData, 
            bundleNftId, 
            referralId);

        // recored token balances before collateralization
        pb[product.getWallet()] = token.balanceOf(product.getWallet());
        pb[distribution.getWallet()] = token.balanceOf(distribution.getWallet());
        pb[customer] = token.balanceOf(customer);
        pb[pool.getWallet()] = token.balanceOf(pool.getWallet());

        vm.startPrank(productOwner);

        product.collateralize(policyNftId, false, zeroTimestamp()); 
        
        assertTrue(policyNftId.gtz(), "policyNftId was zero");
        assertEq(core.chainNft.ownerOf(policyNftId.toInt()), customer, "customer not owner of policyNftId");

        assertTrue(instance.getInstanceStore().getState(policyNftId.toKey32(POLICY())) == COLLATERALIZED(), "state not COLLATERALIZED");
        
        // solhint-disable-next-line 
        console.log("checking bundle amounts after underwriting (before premium collection)");
        (Amount amount, Amount lockedAmount, Amount feeAmount) = instanceStore.getAmounts(bundleNftId);
        assertEq(amount.toInt(), DEFAULT_BUNDLE_CAPITALIZATION, "unexpected bundle amount (before)");
        assertEq(lockedAmount.toInt(), sumInsuredAmount, "unexpected locked amount (before)");
        assertEq(feeAmount.toInt(), 0, "unexpected bundle fee amount (before)");

        assertEq(token.balanceOf(product.getWallet()) - pb[product.getWallet()], 0, "unexpected product balance (before)");
        assertEq(token.balanceOf(customer), pb[customer], "unexpected customer balance (before)");
        assertEq(token.balanceOf(pool.getWallet()) - pb[pool.getWallet()], 0, "unexpecte pool balance (before)");

        pb[product.getWallet()] = token.balanceOf(product.getWallet());
        pb[distribution.getWallet()] = token.balanceOf(distribution.getWallet());
        pb[customer] = token.balanceOf(customer);
        pb[pool.getWallet()] = token.balanceOf(pool.getWallet());

        // WHEN
        product.collectPremium(policyNftId, TimestampLib.blockTimestamp());
        
        // THEN
        assertTrue(instanceReader.getPolicyState(policyNftId) == ACTIVE(), "policy state not ACTIVE");

        // solhint-disable-next-line 
        console.log("checking bundle amounts after underwriting (after premium collection)");
        (amount, lockedAmount, feeAmount) = instanceStore.getAmounts(bundleNftId);
        uint bundleFee = ep.bundleFeeFixAmount + ep.bundleFeeVarAmount;
        uint netPremium = ep.netPremiumAmount;
        assertEq(amount.toInt(), DEFAULT_BUNDLE_CAPITALIZATION + netPremium + bundleFee, "unexpected bundle amount (after)");
        assertEq(lockedAmount.toInt(), sumInsuredAmount, "unexpected locked amount (after)");
        assertEq(feeAmount.toInt(), bundleFee, "unexpected bundle fee amount (after)");

        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertTrue(policyInfo.activatedAt.gtz(), "activatedAt not set");
        assertTrue(policyInfo.expiredAt.gtz(), "expiredAt not set");
        assertTrue(policyInfo.expiredAt.toInt() == policyInfo.activatedAt.addSeconds(sec30).toInt(), "expiredAt not activatedAt + 30");

        assertEq(token.balanceOf(product.getWallet()) - pb[product.getWallet()], ep.productFeeAmount.toInt(), "unexpected product balance (after)");
        assertEq(token.balanceOf(distribution.getWallet()) - pb[distribution.getWallet()], ep.distributionFeeAndCommissionAmount.toInt(), "unexpected distribution balance (after)");
        assertEq(pb[customer] - token.balanceOf(customer), ep.premiumAmount, "unexpected customer balance (after)");
        assertEq(token.balanceOf(pool.getWallet()) - pb[pool.getWallet()], ep.poolPremiumAndFeeAmount.toInt(), "unexpecte pool balance (after)");
    }

    function test_productPolicyClose() public {
        // GIVEN
        vm.startPrank(registryOwner);
        token.transfer(customer, 1000);
        vm.stopPrank();

        _prepareProductLocal();  

        vm.startPrank(productOwner);

        Fee memory productFee = FeeLib.toFee(UFixedLib.zero(), 10);
        product.setFees(productFee, FeeLib.zero());

        RiskId riskId = RiskIdLib.toRiskId("42x4711");
        bytes memory data = "bla di blubb";
        product.createRisk(riskId, data);

        vm.stopPrank();

        vm.startPrank(customer);

        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(productNftId);
        token.approve(address(componentInfo.tokenHandler), 1000);

        // solhint-disable-next-line 
        console.log("before application creation");

        uint sumInsuredAmount = 1000;
        Seconds lifetime = SecondsLib.toSeconds(30);
        bytes memory applicationData = "";
        ReferralId referralId = ReferralLib.zero();
        NftId policyNftId = product.createApplication(
            customer,
            riskId,
            sumInsuredAmount,
            lifetime,
            applicationData,
            bundleNftId,
            referralId
        );

        vm.stopPrank();

        // calculate expected premium/fee amounts
        IPolicy.Premium memory ep = pricingService.calculatePremium(
            productNftId, 
            riskId, 
            AmountLib.toAmount(sumInsuredAmount), 
            lifetime, 
            applicationData, 
            bundleNftId, 
            referralId);

        // recored token balances before collateralization
        pb[product.getWallet()] = token.balanceOf(product.getWallet());
        pb[distribution.getWallet()] = token.balanceOf(distribution.getWallet());
        pb[customer] = token.balanceOf(customer);
        pb[pool.getWallet()] = token.balanceOf(pool.getWallet());

        vm.startPrank(productOwner);

        // solhint-disable-next-line 
        console.log("before collateralization of", policyNftId.toInt());
        product.collateralize(policyNftId, true, TimestampLib.blockTimestamp()); 

        assertTrue(instanceReader.getPolicyState(policyNftId) == ACTIVE(), "policy state not COLLATERALIZED");

        // WHEN
        vm.warp(100); // warp 100 seconds
        // solhint-disable-next-line 
        console.log("before close");
        product.close(policyNftId);

        // THEN
        assertTrue(instanceReader.getPolicyState(policyNftId) == CLOSED(), "policy state not CLOSE");

        console.log("checking bundle amounts after collateralizaion");
        (Amount amount, Amount lockedAmount, Amount feeAmount) = instanceStore.getAmounts(bundleNftId);
        uint bundleFee = ep.bundleFeeFixAmount + ep.bundleFeeVarAmount;
        uint netPremium = ep.netPremiumAmount;

        assertEq(amount.toInt(), DEFAULT_BUNDLE_CAPITALIZATION + netPremium + bundleFee, "unexpected bundle amount (4)");
        assertEq(lockedAmount.toInt(), 0, "unexpected locked amount");
        assertEq(feeAmount.toInt(), bundleFee, "unexpected bundle fee amount");

        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertTrue(policyInfo.closedAt.gtz(), "expiredAt not set");
        
        assertEq(token.balanceOf(address(pool)) - pb[address(pool)], 120, "pool balance not 10120"); // 100 (netPremium) + 10 (poolFee) + 10 (bundleFee)

        assertEq(instanceBundleSet.activePolicies(bundleNftId), 0, "expected no active policy");
    }

    function test_productCreateRisk() public {
        _prepareProductLocal();
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

    function test_productUpdateRisk() public {
        _prepareProductLocal();
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

    function _prepareProductLocal() internal {
        _prepareProductLocal(DEFAULT_BUNDLE_CAPITALIZATION);
    }

    function _prepareProductLocal(uint bundleCapital) internal {
        _prepareProduct();

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
        bundleNftId = pool.createBundle(
            bundleFee, 
            bundleCapital, 
            SecondsLib.toSeconds(604800), 
            ""
        );
        vm.stopPrank();
    }

}