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

// solhint-disable func-name-mixedcase
contract ProductPolicyTest is GifTest {

    Seconds public sec30;

    mapping(address account => uint previousBalance) public pb;

    function setUp() public override {
        super.setUp();

        _prepareProduct();
        _configureProduct(DEFAULT_BUNDLE_CAPITALIZATION);
        
        sec30 = SecondsLib.toSeconds(30);
    }

    

    function test_productCollateralizeWithoutPayment() public {
        // GIVEN

        vm.startPrank(productOwner);

        // set test specific fees
        Fee memory productFee = FeeLib.toFee(UFixedLib.zero(), 10);
        product.setFees(productFee, FeeLib.zero());

        // create test specific risk
        bytes memory data = "bla di blubb";
        RiskId riskId = product.createRisk("42x4711", data);

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
        assertEq(chainNft.ownerOf(policyNftId.toInt()), customer, "customer not owner of policyNftId");
        assertTrue(instance.getInstanceStore().getState(policyNftId.toKey32(POLICY())) == APPLIED(), "state not APPLIED");

        vm.stopPrank();

        // WHEN - collateralize application
        bool requirePremiumPayment = false;
        Timestamp activateAt = TimestampLib.blockTimestamp();
        product.createPolicy(policyNftId, requirePremiumPayment, activateAt); 

        // THEN
        assertTrue(instanceReader.getPolicyState(policyNftId) == COLLATERALIZED(), "policy state not COLLATERALIZED");
        assertEq(instanceReader.getPolicyInfo(policyNftId).activatedAt.toInt(), activateAt.toInt(), "unexpected activatedAt");

        // solhint-disable-next-line
        console.log("checking policy info after underwriting");
        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertEq(policyInfo.sumInsuredAmount.toInt(), 1000, "sumInsuredAmount not 1000");
        assertEq(policyInfo.sumInsuredAmount.toInt(), sumInsuredAmount, "sumInsuredAmount not 1000");
        assertTrue(policyInfo.activatedAt.gtz(), "activatedAt not set");
        assertTrue(policyInfo.expiredAt.gtz(), "expiredAt not set");
        assertTrue(policyInfo.expiredAt.toInt() == policyInfo.activatedAt.addSeconds(sec30).toInt(), "expiredAt not activatedAt + 30");

        assertEq(instanceReader.getPremiumState(policyNftId).toInt(), EXPECTED().toInt(), "premium info state not CALCULATED");

        // solhint-disable-next-line
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

        vm.startPrank(productOwner);
        Fee memory productFee = FeeLib.toFee(UFixedLib.zero(), 10);
        product.setFees(productFee, FeeLib.zero());

        bytes memory data = "bla di blubb";
        RiskId riskId = product.createRisk("42x4711", data);
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
        assertEq(chainNft.ownerOf(policyNftId.toInt()), customer, "customer not owner of policyNftId");
        assertTrue(instance.getInstanceStore().getState(policyNftId.toKey32(POLICY())) == APPLIED(), "state not APPLIED");
        
        // calculate expected premium/fee amounts
        IPolicy.PremiumInfo memory ep = pricingService.calculatePremium(
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
        Timestamp activateAt = TimestampLib.blockTimestamp();
        product.createPolicy(policyNftId, true, activateAt); 

        // THEN
        assertTrue(instanceReader.getPolicyState(policyNftId) == COLLATERALIZED(), "policy state not COLLATERALIZED");
        assertEq(instanceReader.getPolicyInfo(policyNftId).activatedAt.toInt(), activateAt.toInt(), "unexpected activatedAt");

        // solhint-disable-next-line 
        console.log("checking bundle amounts after underwriting");
        (Amount amount, Amount lockedAmount, Amount feeAmount) = instanceStore.getAmounts(bundleNftId);
        Amount bundleFee = ep.bundleFeeFixAmount + ep.bundleFeeVarAmount;
        Amount netPremium = ep.netPremiumAmount;

        assertEq(amount.toInt(), DEFAULT_BUNDLE_CAPITALIZATION + netPremium.toInt() + bundleFee.toInt(), "unexpected bundle amount (2)");
        assertEq(lockedAmount.toInt(), sumInsuredAmount, "unexpected locked amount");
        assertEq(feeAmount.toInt(), bundleFee.toInt(), "unexpected bundle fee amount");

        // solhint-disable-next-line 
        console.log("checking pool amounts after underwriting");
        (Amount poolAmount,, Amount poolFeeAmount) = instanceStore.getAmounts(bundleNftId);
        assertEq(poolFeeAmount.toInt(), 10, "unexpected pool fee amount");

        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertTrue(policyInfo.activatedAt.gtz(), "activatedAt not set");
        assertTrue(policyInfo.expiredAt.gtz(), "expiredAt not set");
        assertTrue(policyInfo.expiredAt.toInt() == policyInfo.activatedAt.addSeconds(sec30).toInt(), "expiredAt not activatedAt + 30");

        assertEq(instanceReader.getPremiumState(policyNftId).toInt(), PAID().toInt(), "premium info state not CALCULATED");

        // solhint-disable-next-line 
        console.log("checking token balances after underwriting");
        assertEq(token.balanceOf(product.getWallet()) - pb[product.getWallet()], 10, "unexpected product balance");
        assertEq(token.balanceOf(distribution.getWallet()) - pb[distribution.getWallet()], 10, "unexpected distibution balance");
        assertEq(token.balanceOf(customer), pb[customer] - ep.premiumAmount.toInt(), "unexpected customer balance");
        assertEq(token.balanceOf(pool.getWallet()) - pb[pool.getWallet()], 120, "unexpected pool balance"); // 100 (net premium) + 10 (pool fee) + 10 (bundle fee)

        assertEq(instanceBundleSet.activePolicies(bundleNftId), 1, "expected one active policy");
        assertTrue(instanceBundleSet.getActivePolicy(bundleNftId, 0).eq(policyNftId), "active policy nft id in bundle manager not equal to policy nft id");
    }

    function test_productWithReferralCollateralizeWithPayment() public {
        // GIVEN
        vm.startPrank(registryOwner);
        token.transfer(customer, 1000);
        vm.stopPrank();

        // set product fees and create risk
        Fee memory productFee = FeeLib.toFee(UFixedLib.zero(), 10);
        bytes memory data = "bla di blubb";

        vm.startPrank(productOwner);
        product.setFees(productFee, FeeLib.zero());
        RiskId riskId = product.createRisk("42x4711", data);
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
            SecondsLib.toSeconds(14 * 24 * 3600),
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
            distributorNftId,
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
        assertEq(chainNft.ownerOf(policyNftId.toInt()), customer, "customer not owner of policyNftId");

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
        IPolicy.PremiumInfo memory premiumExpected = pricingService.calculatePremium(
            productNftId,
            riskId,
            AmountLib.toAmount(sumInsured),
            lifetime,
            "",
            bundleNftId,
            referralId);

        assertEq(premiumExpected.premiumAmount.toInt(), 137, "unexpected premium amount");
    
        // WHEN
        vm.startPrank(productOwner);
        bool collectPremiumAmount = true;
        Timestamp activateAt = TimestampLib.blockTimestamp();
        product.createPolicy(policyNftId, collectPremiumAmount, activateAt);

        // THEN
        assertTrue(instanceReader.getPolicyState(policyNftId) == COLLATERALIZED(), "policy state not COLLATERALIZED");

        assertEq(token.balanceOf(product.getWallet()), 10, "product balance not 10");
        assertEq(token.balanceOf(distribution.getWallet()), 7, "distibution balance not 7");
        assertEq(pb[customer] - token.balanceOf(customer), premiumExpected.premiumAmount.toInt(), "customer balance not 863");

        // solhint-disable
        console.log("product fee (after)", instanceReader.getFeeAmount(productNftId).toInt());
        console.log("distribution fee (after)", instanceReader.getFeeAmount(distributionNftId).toInt());
        console.log("pool fee (after)", instanceReader.getFeeAmount(poolNftId).toInt());
        console.log("bundle fee (after)", instanceReader.getFeeAmount(bundleNftId).toInt());
        // solhint-enable

        assertEq(instanceReader.getFeeAmount(poolNftId).toInt(), 10, "pool fee amount not 10");

        IDistribution.ReferralInfo memory referralInfo = instanceReader.getReferralInfo(referralId);
        assertEq(1, referralInfo.usedReferrals, "unexpected referral count");
    }

    function test_productPolicy_maxPremiumAmountExceeded() public {
        // GIVEN

        vm.startPrank(productOwner);

        Fee memory productFee = FeeLib.toFee(UFixedLib.zero(), 10);
        product.setFees(productFee, FeeLib.zero());

        bytes memory data = "bla di blubb";
        RiskId riskId = product.createRisk("42x4711", data);

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
        assertEq(chainNft.ownerOf(policyNftId.toInt()), customer, "customer not owner of policyNftId");

        assertTrue(instance.getInstanceStore().getState(policyNftId.toKey32(POLICY())) == APPLIED(), "state not APPLIED");

        Amount maxPremiumAmount = AmountLib.toAmount(100);

        // THEN
        vm.expectRevert(abi.encodeWithSelector(
            IPolicyService.LogPolicyServiceMaxPremiumAmountExceeded.selector,
            policyNftId,
            maxPremiumAmount,
            AmountLib.toAmount(140)
        ));

        // WHEN
        product.createPolicy2(policyNftId, false, zeroTimestamp(), maxPremiumAmount); 

        
    }

    function test_productCreatePolicy_notApplied() public {
        // GIVEN

        vm.startPrank(productOwner);

        Fee memory productFee = FeeLib.toFee(UFixedLib.zero(), 10);
        product.setFees(productFee, FeeLib.zero());

        bytes memory data = "bla di blubb";
        RiskId riskId = product.createRisk("42x4711", data);

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
        assertEq(chainNft.ownerOf(policyNftId.toInt()), customer, "customer not owner of policyNftId");

        assertTrue(instance.getInstanceStore().getState(policyNftId.toKey32(POLICY())) == APPLIED(), "state not APPLIED");

        Amount maxPremiumAmount = AmountLib.toAmount(1000);
        product.decline(policyNftId);

        // THEN
        vm.expectRevert(abi.encodeWithSelector(
            IPolicyService.ErrorPolicyServicePolicyStateNotApplied.selector,
            policyNftId));

        // WHEN - state not applied
        product.createPolicy2(policyNftId, false, zeroTimestamp(), maxPremiumAmount); 
    }


    function test_productWithReferralCollateralizeWithSplitPayment() public {
        // GIVEN
        vm.startPrank(registryOwner);
        token.transfer(customer, 1000);
        vm.stopPrank();

        // set product fees and create risk
        Fee memory productFee = FeeLib.toFee(UFixedLib.zero(), 10);
        bytes memory data = "bla di blubb";

        vm.startPrank(productOwner);
        product.setFees(productFee, FeeLib.zero());
        RiskId riskId = product.createRisk("42x4711", data);
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
            SecondsLib.toSeconds(14 * 24 * 3600),
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
            distributorNftId,
            "GET_A_DISCOUNT",
            UFixedLib.toUFixed(2, -2),
            5,
            TimestampLib.blockTimestamp().addSeconds(SecondsLib.toSeconds(604800)),
            "");

        vm.stopPrank();

        vm.startPrank(customer);

        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(productNftId);
        token.approve(address(componentInfo.tokenHandler), 1000);

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
        
        vm.stopPrank();

        // calculate premium
        IPolicy.PremiumInfo memory premiumExpected = pricingService.calculatePremium(
            productNftId,
            riskId,
            AmountLib.toAmount(sumInsured),
            lifetime,
            "",
            bundleNftId,
            referralId);

        assertEq(premiumExpected.premiumAmount.toInt(), 137, "unexpected premium amount");
    
        // WHEN
        vm.startPrank(productOwner);
        Timestamp activateAt = TimestampLib.blockTimestamp();
        product.createPolicy(policyNftId, false, activateAt);

        // THEN
        assertTrue(instanceReader.getPolicyState(policyNftId) == COLLATERALIZED(), "policy state not COLLATERALIZED");

        IDistribution.ReferralInfo memory referralInfo = instanceReader.getReferralInfo(referralId);
        assertEq(1, referralInfo.usedReferrals, "unexpected referral count (1)");

        assertEq(0, instanceReader.getBalanceAmount(distributorNftId).toInt(), "unexpected distributor balance (1)");

        // WHEN - collectTokens
        product.collectPremium(policyNftId, activateAt);

        // THEN - check balances incremented
        referralInfo = instanceReader.getReferralInfo(referralId);
        assertEq(1, referralInfo.usedReferrals, "unexpected referral count (2)");

        assertEq(3, instanceReader.getBalanceAmount(distributorNftId).toInt(), "unexpected distributor balance (2)");
    }

    function test_productCollateralizeWithReferralExpired() public {
        // GIVEN
        vm.startPrank(registryOwner);
        token.transfer(customer, 1000);
        vm.stopPrank();

        // set product fees and create risk
        vm.startPrank(productOwner);

        Fee memory productFee = FeeLib.toFee(UFixedLib.zero(), 10);
        product.setFees(productFee, FeeLib.zero());

        bytes memory data = "bla di blubb";
        RiskId riskId = product.createRisk("42x4711", data);

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
            SecondsLib.toSeconds(14 * 24 * 3600),
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
            distributorNftId,
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
        assertEq(chainNft.ownerOf(policyNftId.toInt()), customer, "customer not owner of policyNftId");

        assertTrue(instance.getInstanceStore().getState(policyNftId.toKey32(POLICY())) == APPLIED(), "state not APPLIED");
        
        vm.stopPrank();

        vm.startPrank(productOwner);
        bool collectPremiumAmount = true;
        
        // WHEN
        // wait 20 seconds to expire referral
        vm.warp(20); 

        // THEN
        Timestamp activationAt = TimestampLib.blockTimestamp();
        // vm.expectRevert(
        //     abi.encodeWithSelector(
        //         IPolicyService.ErrorPolicyServicePremiumHigherThanExpected.selector, 
        //         AmountLib.toAmount(137), 
        //         AmountLib.toAmount(140)));

        product.createPolicy(
            policyNftId, 
            collectPremiumAmount, 
            activationAt);

        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertEq(policyInfo.premiumAmount.toInt(), 137, "unexpected premium amount from application");
        assertEq(instanceReader.getPremiumState(policyNftId).toInt(), PAID().toInt(), "unexpected premium info state");
    }


    function test_productCollateralizeRevertsOnLockedBundle() public {
        // GIVEN
        vm.startPrank(productOwner);

        Fee memory productFee = FeeLib.toFee(UFixedLib.zero(), 10);
        product.setFees(productFee, FeeLib.zero());

        bytes memory data = "bla di blubb";
        RiskId riskId = product.createRisk("42x4711", data);

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
        assertEq(chainNft.ownerOf(policyNftId.toInt()), customer, "customer not owner of policyNftId");

        vm.stopPrank();

        assertEq(instanceReader.getPolicyState(policyNftId).toInt(), APPLIED().toInt(), "unexpected policy state (not APPLIED)");

        vm.startPrank(investor);
        pool.setBundleLocked(bundleNftId, true);

        Timestamp timeNow = TimestampLib.blockTimestamp();

        // THEN - WHEN - try collateralize on locked bundle
        vm.expectRevert(abi.encodeWithSelector(
            BundleSet.ErrorBundleSetBundleLocked.selector,
            bundleNftId,
            policyNftId));
        product.createPolicy(policyNftId, false, timeNow); 

        // WHEN - unlock bundle and try collateralize again
        pool.setBundleLocked(bundleNftId, false);
        product.createPolicy(policyNftId, false, timeNow);

        // THEN
        assertEq(instanceReader.getPolicyState(policyNftId).toInt(), COLLATERALIZED().toInt(), "unexpected policy state (not COLLATERALIZED)");
        assertEq(instanceReader.getPolicyInfo(policyNftId).activatedAt.toInt(), timeNow.toInt(), "unexpected activatedAt");
    }

    function test_productCollateralizeRevertsOnCapacityInsufficient() public {
        // GIVEN
        vm.startPrank(productOwner);

        bytes memory data = "bla di blubb";
        RiskId riskId = product.createRisk("42x4711", data);

        vm.stopPrank();

        vm.startPrank(customer);
        NftId policyNftId = product.createApplication(
            customer,
            riskId,
            DEFAULT_BUNDLE_CAPITALIZATION + 1,
            SecondsLib.toSeconds(30),
            "",
            bundleNftId,
            ReferralLib.zero()
        );
        assertTrue(policyNftId.gtz(), "policyNftId was zero");

        vm.stopPrank();

        assertEq(instanceReader.getPolicyState(policyNftId).toInt(), APPLIED().toInt(), "unexpected policy state (not APPLIED)");

        Timestamp activateAt = TimestampLib.blockTimestamp();

        vm.startPrank(investor);

        // THEN
        vm.expectRevert(abi.encodeWithSelector(
            IBundleService.ErrorBundleServiceCapacityInsufficient.selector,
            bundleNftId,
            DEFAULT_BUNDLE_CAPITALIZATION,
            DEFAULT_BUNDLE_CAPITALIZATION + 1));

        // WHEN
        product.createPolicy(policyNftId, false, activateAt);
    }


    function test_productPolicyActivate() public {
        // GIVEN

        vm.startPrank(productOwner);

        Fee memory productFee = FeeLib.toFee(UFixedLib.zero(), 10);
        product.setFees(productFee, FeeLib.zero());

        bytes memory data = "bla di blubb";
        RiskId riskId = product.createRisk("42x4711", data);

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
        assertEq(chainNft.ownerOf(policyNftId.toInt()), customer, "customer not owner of policyNftId");

        assertTrue(instance.getInstanceStore().getState(policyNftId.toKey32(POLICY())) == APPLIED(), "state not APPLIED");

        // WHEN
        product.createPolicy(policyNftId, false, zeroTimestamp()); 

        // THEN 
        assertTrue(instanceReader.getPolicyState(policyNftId) == COLLATERALIZED(), "policy state not COLLATERALIZED");

        // solhint-disable-next-line
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
        assertTrue(instanceReader.getPolicyState(policyNftId) == COLLATERALIZED(), "policy state not COLLATERALIZED");

        // and THEN
        policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertTrue(policyInfo.activatedAt.gtz(), "activatedAt not set");
        assertTrue(policyInfo.expiredAt.gtz(), "expiredAt not set");
        assertTrue(policyInfo.expiredAt.toInt() == policyInfo.activatedAt.addSeconds(sec30).toInt(), "expiredAt not activatedAt + 30");
    }

    function test_adjustActivation() public {
        // GIVEN
        vm.startPrank(registryOwner);
        token.transfer(customer, 1000);
        vm.stopPrank();

        bytes memory data = "bla di blubb";
        RiskId riskId = product.createRisk("42x4711", data);
        vm.stopPrank();

        vm.startPrank(customer);

        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(productNftId);
        token.approve(address(componentInfo.tokenHandler), 1000);

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

        assertTrue(instance.getInstanceStore().getState(policyNftId.toKey32(POLICY())) == APPLIED(), "state not APPLIED");
        
        vm.startPrank(productOwner);

        Timestamp activateAt = TimestampLib.blockTimestamp().addSeconds(SecondsLib.toSeconds(1000));
        product.createPolicy(policyNftId, true, activateAt); 

        // THEN
        assertTrue(instanceReader.getPolicyState(policyNftId) == COLLATERALIZED(), "policy state not COLLATERALIZED");
        assertEq(instanceReader.getPolicyInfo(policyNftId).activatedAt.toInt(), activateAt.toInt(), "unexpected activatedAt");

        // WHEN
        Timestamp newActivateAt = TimestampLib.blockTimestamp();
        product.adjustActivation(policyNftId, newActivateAt);

        // THEN
        assertTrue(instanceReader.getPolicyState(policyNftId) == COLLATERALIZED(), "policy state not COLLATERALIZED");
        assertEq(instanceReader.getPolicyInfo(policyNftId).activatedAt.toInt(), newActivateAt.toInt(), "unexpected activatedAt");
    }

    function test_adjustActivation_tooEarly() public {
        vm.warp(100000);

        // GIVEN
        vm.startPrank(registryOwner);
        token.transfer(customer, 1000);
        vm.stopPrank();

        bytes memory data = "bla di blubb";
        RiskId riskId = product.createRisk("42x4711", data);
        vm.stopPrank();

        vm.startPrank(customer);

        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(productNftId);
        token.approve(address(componentInfo.tokenHandler), 1000);

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

        assertTrue(instance.getInstanceStore().getState(policyNftId.toKey32(POLICY())) == APPLIED(), "state not APPLIED");
        
        vm.startPrank(productOwner);

        Timestamp now =  TimestampLib.blockTimestamp();
        Timestamp activateAt = TimestampLib.blockTimestamp().addSeconds(SecondsLib.toSeconds(1000));
        product.createPolicy(policyNftId, true, activateAt); 

        // THEN
        assertTrue(instanceReader.getPolicyState(policyNftId) == COLLATERALIZED(), "policy state not COLLATERALIZED");
        assertEq(instanceReader.getPolicyInfo(policyNftId).activatedAt.toInt(), activateAt.toInt(), "unexpected activatedAt");

        Timestamp newActivateAt = TimestampLib.toTimestamp(TimestampLib.blockTimestamp().toInt() - 100);

        // THEN
        vm.expectRevert(abi.encodeWithSelector(
            IPolicyService.ErrorPolicyServicePolicyActivationTooEarly.selector,
            policyNftId,
            now,
            newActivateAt));
        
        // WHEN
        product.adjustActivation(policyNftId, newActivateAt);
    }

    function test_adjustActivation_tooLate() public {
        vm.warp(100000);

        // GIVEN
        vm.startPrank(registryOwner);
        token.transfer(customer, 1000);
        vm.stopPrank();

        bytes memory data = "bla di blubb";
        RiskId riskId = product.createRisk("42x4711", data);
        vm.stopPrank();

        vm.startPrank(customer);

        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(productNftId);
        token.approve(address(componentInfo.tokenHandler), 1000);

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

        assertTrue(instance.getInstanceStore().getState(policyNftId.toKey32(POLICY())) == APPLIED(), "state not APPLIED");
        
        vm.startPrank(productOwner);

        Timestamp activateAt = TimestampLib.blockTimestamp();
        product.createPolicy(policyNftId, true, activateAt); 

        // THEN
        assertTrue(instanceReader.getPolicyState(policyNftId) == COLLATERALIZED(), "policy state not COLLATERALIZED");
        assertEq(instanceReader.getPolicyInfo(policyNftId).activatedAt.toInt(), activateAt.toInt(), "unexpected activatedAt");

        Timestamp newActivateAt = activateAt.addSeconds(lifetime).addSeconds(SecondsLib.toSeconds(1000));

        // THEN
        vm.expectRevert(abi.encodeWithSelector(
            IPolicyService.ErrorPolicyServicePolicyActivationTooLate.selector,
            policyNftId,
            activateAt.addSeconds(lifetime),
            newActivateAt));

        // WHEN
        product.adjustActivation(policyNftId, newActivateAt);
    }

    function test_adjustActivation_notActive() public {
        vm.warp(100000);

        // GIVEN
        vm.startPrank(registryOwner);
        token.transfer(customer, 1000);
        vm.stopPrank();

        bytes memory data = "bla di blubb";
        RiskId riskId = product.createRisk("42x4711", data);
        vm.stopPrank();

        vm.startPrank(customer);

        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(productNftId);
        token.approve(address(componentInfo.tokenHandler), 1000);

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

        assertTrue(instance.getInstanceStore().getState(policyNftId.toKey32(POLICY())) == APPLIED(), "state not APPLIED");
        
        vm.startPrank(productOwner);

        product.createPolicy(policyNftId, true, TimestampLib.zero()); 

        // THEN
        assertTrue(instanceReader.getPolicyState(policyNftId) == COLLATERALIZED(), "policy state not COLLATERALIZED");
        assertEq(instanceReader.getPolicyInfo(policyNftId).activatedAt.toInt(), 0, "unexpected activatedAt");

        Timestamp newActivateAt = TimestampLib.blockTimestamp();

        // THEN
        vm.expectRevert(abi.encodeWithSelector(
            IPolicyService.ErrorPolicyServicePolicyNotActivated.selector,
            policyNftId));

        // WHEN
        product.adjustActivation(policyNftId, newActivateAt);
    }

    function test_productPolicyCollectPremium() public {
        // GIVEN
        vm.startPrank(registryOwner);
        token.transfer(customer, 1000);
        vm.stopPrank();

        vm.startPrank(productOwner);

        Fee memory productFee = FeeLib.toFee(UFixedLib.zero(), 10);
        product.setFees(productFee, FeeLib.zero());

        bytes memory data = "bla di blubb";
        RiskId riskId = product.createRisk("42x4711", data);

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
        IPolicy.PremiumInfo memory ep = pricingService.calculatePremium(
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

        product.createPolicy(policyNftId, false, zeroTimestamp()); 
        
        assertTrue(policyNftId.gtz(), "policyNftId was zero");
        assertEq(chainNft.ownerOf(policyNftId.toInt()), customer, "customer not owner of policyNftId");

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
        assertTrue(instanceReader.getPolicyState(policyNftId) == COLLATERALIZED(), "policy state not COLLATERALIZED");

        // solhint-disable-next-line 
        console.log("checking bundle amounts after underwriting (after premium collection)");
        (amount, lockedAmount, feeAmount) = instanceStore.getAmounts(bundleNftId);
        Amount bundleFee = ep.bundleFeeFixAmount + ep.bundleFeeVarAmount;
        Amount netPremium = ep.netPremiumAmount;
        assertEq(amount.toInt(), DEFAULT_BUNDLE_CAPITALIZATION + netPremium.toInt() + bundleFee.toInt(), "unexpected bundle amount (after)");
        assertEq(lockedAmount.toInt(), sumInsuredAmount, "unexpected locked amount (after)");
        assertEq(feeAmount.toInt(), bundleFee.toInt(), "unexpected bundle fee amount (after)");

        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertTrue(policyInfo.activatedAt.gtz(), "activatedAt not set");
        assertTrue(policyInfo.expiredAt.gtz(), "expiredAt not set");
        assertTrue(policyInfo.expiredAt.toInt() == policyInfo.activatedAt.addSeconds(sec30).toInt(), "expiredAt not activatedAt + 30");

        assertEq(token.balanceOf(product.getWallet()) - pb[product.getWallet()], ep.productFeeAmount.toInt(), "unexpected product balance (after)");
        assertEq(token.balanceOf(distribution.getWallet()) - pb[distribution.getWallet()], ep.distributionFeeAndCommissionAmount.toInt(), "unexpected distribution balance (after)");
        assertEq(pb[customer] - token.balanceOf(customer), ep.premiumAmount.toInt(), "unexpected customer balance (after)");
        assertEq(token.balanceOf(pool.getWallet()) - pb[pool.getWallet()], ep.poolPremiumAndFeeAmount.toInt(), "unexpecte pool balance (after)");
    }

    function test_productPolicyClose() public {
        // GIVEN
        vm.startPrank(registryOwner);
        token.transfer(customer, 1000);
        vm.stopPrank();

        vm.startPrank(productOwner);

        Fee memory productFee = FeeLib.toFee(UFixedLib.zero(), 10);
        product.setFees(productFee, FeeLib.zero());

        bytes memory data = "bla di blubb";
        RiskId riskId = product.createRisk("42x4711", data);

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
        IPolicy.PremiumInfo memory ep = pricingService.calculatePremium(
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
        product.createPolicy(
            policyNftId, 
            true, 
            TimestampLib.blockTimestamp()); 

        assertTrue(instanceReader.getPolicyState(policyNftId) == COLLATERALIZED(), "policy state not COLLATERALIZED");

        // WHEN
        vm.warp(100); // warp 100 seconds
        // solhint-disable-next-line 
        console.log("before close");
        product.close(policyNftId);

        // THEN
        assertTrue(instanceReader.getPolicyState(policyNftId) == CLOSED(), "policy state not CLOSE");

        // solhint-disable-next-line
        console.log("checking bundle amounts after collateralizaion");
        (Amount amount, Amount lockedAmount, Amount feeAmount) = instanceStore.getAmounts(bundleNftId);
        Amount bundleFee = ep.bundleFeeFixAmount + ep.bundleFeeVarAmount;
        Amount netPremium = ep.netPremiumAmount;

        assertEq(amount.toInt(), DEFAULT_BUNDLE_CAPITALIZATION + netPremium.toInt() + bundleFee.toInt(), "unexpected bundle amount (4)");
        assertEq(lockedAmount.toInt(), 0, "unexpected locked amount");
        assertEq(feeAmount.toInt(), bundleFee.toInt(), "unexpected bundle fee amount");

        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertTrue(policyInfo.closedAt.gtz(), "expiredAt not set");
        
        assertEq(token.balanceOf(pool.getWallet()) - pb[pool.getWallet()], 120, "pool balance not 120"); // 100 (netPremium) + 10 (poolFee) + 10 (bundleFee)

        assertEq(instanceBundleSet.activePolicies(bundleNftId), 0, "expected no active policy");
    }

    function test_productPolicyClose_notPaid() public {
        // GIVEN
        vm.startPrank(registryOwner);
        token.transfer(customer, 1000);
        vm.stopPrank();

        vm.startPrank(productOwner);

        Fee memory productFee = FeeLib.toFee(UFixedLib.zero(), 10);
        product.setFees(productFee, FeeLib.zero());

        bytes memory data = "bla di blubb";
        RiskId riskId = product.createRisk("42x4711", data);

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

        vm.startPrank(productOwner);

        product.createPolicy(
            policyNftId, 
            false, 
            TimestampLib.blockTimestamp()); 

        vm.warp(100); // warp 100 seconds

        // THEN
        vm.expectRevert(abi.encodeWithSelector(
            IPolicyService.ErrorPolicyServicePremiumNotPaid.selector,
            policyNftId,
            instanceReader.getPremiumInfo(policyNftId).premiumAmount));

        // WHEN
        product.close(policyNftId);
    }

    /// @dev test that policy expiration works 
    function test_productPolicyExpireHappyCase() public {
        // GIVEN
        vm.startPrank(registryOwner);
        token.transfer(customer, 1000);
        vm.stopPrank();

        vm.startPrank(productOwner);

        bytes memory data = "bla di blubb";
        RiskId riskId = product.createRisk("42x4711", data);

        vm.stopPrank();

        vm.startPrank(customer);

        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(productNftId);
        token.approve(address(componentInfo.tokenHandler), 1000);

        // solhint-disable-next-line 
        console.log("before application creation");

        uint sumInsuredAmount = 1000;
        uint256 lifetime = 30;
        Seconds lifetimeSecs = SecondsLib.toSeconds(30);
        bytes memory applicationData = "";
        ReferralId referralId = ReferralLib.zero();
        NftId policyNftId = product.createApplication(
            customer,
            riskId,
            sumInsuredAmount,
            lifetimeSecs,
            applicationData,
            bundleNftId,
            referralId
        );
        uint256 createdAt = vm.getBlockTimestamp();

        vm.stopPrank();

        vm.startPrank(productOwner);

        // solhint-disable-next-line 
        console.log("before collateralization of", policyNftId.toInt());
        product.createPolicy(policyNftId, true, TimestampLib.blockTimestamp()); 

        assertTrue(instanceReader.getPolicyState(policyNftId) == COLLATERALIZED(), "policy state not COLLATERALIZED");
        IPolicy.PolicyInfo memory policyInfoBefore = instanceReader.getPolicyInfo(policyNftId);
        assertEq(policyInfoBefore.expiredAt.toInt(), createdAt + lifetime, "unexpected expiredAt");

        // WHEN
        uint256 expireAt = createdAt + 10;
        Timestamp expireAtTs = TimestampLib.toTimestamp(expireAt);
        product.expire(policyNftId, expireAtTs);

        // THEN
        IPolicy.PolicyInfo memory policyInfoAfter = instanceReader.getPolicyInfo(policyNftId);
        assertEq(policyInfoAfter.expiredAt.toInt(), expireAt, "unexpected expiredAt");
    }

    /// @dev test that policy expiration works when current timestamp is provided
    function test_productPolicyExpire_currentTimestamp() public {
        // GIVEN
        vm.startPrank(registryOwner);
        token.transfer(customer, 1000);
        vm.stopPrank();

        vm.startPrank(productOwner);

        bytes memory data = "bla di blubb";
        RiskId riskId = product.createRisk("42x4711", data);

        vm.stopPrank();

        vm.startPrank(customer);

        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(productNftId);
        token.approve(address(componentInfo.tokenHandler), 1000);

        // solhint-disable-next-line 
        console.log("before application creation");

        uint sumInsuredAmount = 1000;
        uint256 lifetime = 30;
        Seconds lifetimeSecs = SecondsLib.toSeconds(30);
        bytes memory applicationData = "";
        ReferralId referralId = ReferralLib.zero();
        NftId policyNftId = product.createApplication(
            customer,
            riskId,
            sumInsuredAmount,
            lifetimeSecs,
            applicationData,
            bundleNftId,
            referralId
        );
        uint256 createdAt = vm.getBlockTimestamp();

        vm.stopPrank();

        vm.startPrank(productOwner);

        // solhint-disable-next-line 
        console.log("before collateralization of", policyNftId.toInt());
        product.createPolicy(policyNftId, true, TimestampLib.blockTimestamp()); 

        assertTrue(instanceReader.getPolicyState(policyNftId) == COLLATERALIZED(), "policy state not COLLATERALIZED");
        IPolicy.PolicyInfo memory policyInfoBefore = instanceReader.getPolicyInfo(policyNftId);
        assertEq(policyInfoBefore.expiredAt.toInt(), createdAt + lifetime, "unexpected expiredAt");

        // WHEN
        Timestamp expireAtTs = TimestampLib.blockTimestamp();
        product.expire(policyNftId, expireAtTs);

        // THEN
        IPolicy.PolicyInfo memory policyInfoAfter = instanceReader.getPolicyInfo(policyNftId);
        assertEq(policyInfoAfter.expiredAt.toInt(), expireAtTs.toInt(), "unexpected expiredAt");
    }

    /// @dev test that policy expiration works when expireAt is set to 0
    function test_productPolicyExpire_earliestPossible() public {
        // GIVEN
        vm.startPrank(registryOwner);
        token.transfer(customer, 1000);
        vm.stopPrank();

        vm.startPrank(productOwner);

        bytes memory data = "bla di blubb";
        RiskId riskId = product.createRisk("42x4711", data);

        vm.stopPrank();

        vm.startPrank(customer);

        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(productNftId);
        token.approve(address(componentInfo.tokenHandler), 1000);

        // solhint-disable-next-line 
        console.log("before application creation");

        uint sumInsuredAmount = 1000;
        uint256 lifetime = 30;
        Seconds lifetimeSecs = SecondsLib.toSeconds(30);
        bytes memory applicationData = "";
        ReferralId referralId = ReferralLib.zero();
        NftId policyNftId = product.createApplication(
            customer,
            riskId,
            sumInsuredAmount,
            lifetimeSecs,
            applicationData,
            bundleNftId,
            referralId
        );
        uint256 createdAt = vm.getBlockTimestamp();

        vm.stopPrank();

        vm.startPrank(productOwner);

        // solhint-disable-next-line 
        console.log("before collateralization of", policyNftId.toInt());
        product.createPolicy(policyNftId, true, TimestampLib.blockTimestamp()); 

        // WHEN
        Timestamp expireAtTs = TimestampLib.zero();
        Timestamp expiredAt = product.expire(policyNftId, expireAtTs);

        // THEN
        assertEq(expiredAt.toInt(), vm.getBlockTimestamp(), "unexpected expiredAt (1)");
        IPolicy.PolicyInfo memory policyInfoAfter = instanceReader.getPolicyInfo(policyNftId);
        assertEq(policyInfoAfter.expiredAt.toInt(), vm.getBlockTimestamp(), "unexpected expiredAt (2)");
    }

    /// @dev test that policy expiration reverts if policy is not active
    function test_productPolicyExpire_policyNotActive() public {
        // GIVEN
        vm.startPrank(registryOwner);
        token.transfer(customer, 1000);
        vm.stopPrank();

        vm.startPrank(productOwner);

        bytes memory data = "bla di blubb";
        RiskId riskId = product.createRisk("42x4711", data);

        vm.stopPrank();

        vm.startPrank(customer);

        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(productNftId);
        token.approve(address(componentInfo.tokenHandler), 1000);

        // solhint-disable-next-line 
        console.log("before application creation");

        uint sumInsuredAmount = 1000;
        uint256 lifetime = 30;
        Seconds lifetimeSecs = SecondsLib.toSeconds(30);
        bytes memory applicationData = "";
        ReferralId referralId = ReferralLib.zero();
        NftId policyNftId = product.createApplication(
            customer,
            riskId,
            sumInsuredAmount,
            lifetimeSecs,
            applicationData,
            bundleNftId,
            referralId
        );
        uint256 createdAt = vm.getBlockTimestamp();

        vm.stopPrank();

        vm.startPrank(productOwner);

        // solhint-disable-next-line 
        product.decline(policyNftId);

        assertTrue(instanceReader.getPolicyState(policyNftId) == DECLINED(), "policy state not DECLINED");

        uint256 expireAt = createdAt + 10;
        Timestamp expireAtTs = TimestampLib.toTimestamp(expireAt);
        
        // THEN - expect revert
        vm.expectRevert(abi.encodeWithSelector(
            IPolicyService.ErrorPolicyServicePolicyNotActive.selector, 
            policyNftId,
            DECLINED()));

        // WHEN
        product.expire(policyNftId, expireAtTs);
    }

    function test_productDeclinePolicy_notApplied() public {
        // GIVEN

        vm.startPrank(productOwner);

        Fee memory productFee = FeeLib.toFee(UFixedLib.zero(), 10);
        product.setFees(productFee, FeeLib.zero());

        bytes memory data = "bla di blubb";
        RiskId riskId = product.createRisk("42x4711", data);

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
        assertEq(chainNft.ownerOf(policyNftId.toInt()), customer, "customer not owner of policyNftId");

        assertTrue(instance.getInstanceStore().getState(policyNftId.toKey32(POLICY())) == APPLIED(), "state not APPLIED");

        Amount maxPremiumAmount = AmountLib.toAmount(1000);
        product.revoke(policyNftId);

        vm.startPrank(productOwner);

        // THEN
        vm.expectRevert(abi.encodeWithSelector(
            IPolicyService.ErrorPolicyServicePolicyStateNotApplied.selector,
            policyNftId));

        // WHEN - state not applied
        product.decline(policyNftId); 
    }

    function test_productCollectPremium_notCollateralized() public {
        // GIVEN

        vm.startPrank(productOwner);

        Fee memory productFee = FeeLib.toFee(UFixedLib.zero(), 10);
        product.setFees(productFee, FeeLib.zero());

        bytes memory data = "bla di blubb";
        RiskId riskId = product.createRisk("42x4711", data);

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
        assertEq(chainNft.ownerOf(policyNftId.toInt()), customer, "customer not owner of policyNftId");

        assertTrue(instance.getInstanceStore().getState(policyNftId.toKey32(POLICY())) == APPLIED(), "state not APPLIED");

        Timestamp activateAt = TimestampLib.blockTimestamp();
        vm.startPrank(productOwner);

        // THEN
        vm.expectRevert(abi.encodeWithSelector(
            IPolicyService.ErrorPolicyServicePolicyStateNotCollateralized.selector,
            policyNftId));

        // WHEN - state not applied
        product.collectPremium(policyNftId, activateAt); 
    }

    function test_productCollectPremium_alreadyPaid() public {
        // GIVEN
        vm.startPrank(registryOwner);
        token.transfer(customer, 1000);
        vm.stopPrank();

        vm.startPrank(productOwner);

        Fee memory productFee = FeeLib.toFee(UFixedLib.zero(), 10);
        product.setFees(productFee, FeeLib.zero());

        bytes memory data = "bla di blubb";
        RiskId riskId = product.createRisk("42x4711", data);

        vm.stopPrank();
        vm.startPrank(customer);

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
        token.approve(address(instanceReader.getComponentInfo(productNftId).tokenHandler), 200);
        vm.stopPrank();
        
        assertTrue(policyNftId.gtz(), "policyNftId was zero");
        assertEq(chainNft.ownerOf(policyNftId.toInt()), customer, "customer not owner of policyNftId");

        assertTrue(instance.getInstanceStore().getState(policyNftId.toKey32(POLICY())) == APPLIED(), "state not APPLIED");

        Timestamp activateAt = TimestampLib.blockTimestamp();
        vm.startPrank(productOwner);
        product.createPolicy(policyNftId, true, activateAt); 

        // THEN
        vm.expectRevert(abi.encodeWithSelector(
            IPolicyService.ErrorPolicyServicePremiumAlreadyPaid.selector,
            policyNftId));

        // WHEN - state not applied
        product.collectPremium(policyNftId, activateAt);
    }

    /// @dev test that policy expiration reverts if the expireAt timestamp is too late
    function test_productPolicyExpire_expireAtTooLate() public {
        // GIVEN
        vm.startPrank(registryOwner);
        token.transfer(customer, 1000);
        vm.stopPrank();

        vm.startPrank(productOwner);

        bytes memory data = "bla di blubb";
        RiskId riskId = product.createRisk("42x4711", data);

        vm.stopPrank();

        vm.startPrank(customer);

        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(productNftId);
        token.approve(address(componentInfo.tokenHandler), 1000);

        // solhint-disable-next-line 
        console.log("before application creation");

        uint sumInsuredAmount = 1000;
        uint256 lifetime = 30;
        Seconds lifetimeSecs = SecondsLib.toSeconds(30);
        bytes memory applicationData = "";
        ReferralId referralId = ReferralLib.zero();
        NftId policyNftId = product.createApplication(
            customer,
            riskId,
            sumInsuredAmount,
            lifetimeSecs,
            applicationData,
            bundleNftId,
            referralId
        );
        uint256 createdAt = vm.getBlockTimestamp();

        vm.stopPrank();

        vm.startPrank(productOwner);
        product.createPolicy(policyNftId, true, TimestampLib.blockTimestamp()); 
        assertTrue(instanceReader.getPolicyState(policyNftId) == COLLATERALIZED(), "policy state not COLLATERALIZED");

        uint256 expireAt = createdAt + 30;
        Timestamp expireAtTs = TimestampLib.toTimestamp(expireAt);
        
        // THEN - expect revert
        vm.expectRevert(abi.encodeWithSelector(
            IPolicyService.ErrorPolicyServicePolicyExpirationTooLate.selector, 
            policyNftId,
            expireAtTs,
            expireAtTs));

        // WHEN
        product.expire(policyNftId, expireAtTs);

        // THEN - expect revert
        uint256 expireAt2 = createdAt + 35;
        Timestamp expireAtTs2 = TimestampLib.toTimestamp(expireAt);

        vm.expectRevert(abi.encodeWithSelector(
            IPolicyService.ErrorPolicyServicePolicyExpirationTooLate.selector, 
            policyNftId,
            expireAtTs,
            expireAtTs2));

        // WHEN
        product.expire(policyNftId, expireAtTs2);
    }

    /// @dev test that policy expiration reverts if the expireAt timestamp is too early
    function test_productPolicyExpire_expireAtTooEarly() public {
        skip(10);

        // GIVEN
        vm.startPrank(registryOwner);
        token.transfer(customer, 1000);
        vm.stopPrank();

        vm.startPrank(productOwner);

        bytes memory data = "bla di blubb";
        RiskId riskId = product.createRisk("42x4711", data);

        vm.stopPrank();

        vm.startPrank(customer);

        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(productNftId);
        token.approve(address(componentInfo.tokenHandler), 1000);

        // solhint-disable-next-line 
        console.log("before application creation");

        uint sumInsuredAmount = 1000;
        uint256 lifetime = 30;
        Seconds lifetimeSecs = SecondsLib.toSeconds(30);
        bytes memory applicationData = "";
        ReferralId referralId = ReferralLib.zero();
        NftId policyNftId = product.createApplication(
            customer,
            riskId,
            sumInsuredAmount,
            lifetimeSecs,
            applicationData,
            bundleNftId,
            referralId
        );
        uint256 createdAt = vm.getBlockTimestamp();

        vm.stopPrank();

        vm.startPrank(productOwner);
        product.createPolicy(policyNftId, true, TimestampLib.blockTimestamp()); 
        assertTrue(instanceReader.getPolicyState(policyNftId) == COLLATERALIZED(), "policy state not COLLATERALIZED");

        uint256 expireAt = createdAt - 5;
        Timestamp expireAtTs = TimestampLib.toTimestamp(expireAt);
        
        // THEN - expect revert
        vm.expectRevert(abi.encodeWithSelector(
            IPolicyService.ErrorPolicyServicePolicyExpirationTooEarly.selector, 
            policyNftId,
            vm.getBlockTimestamp(),
            expireAtTs));

        // WHEN
        product.expire(policyNftId, expireAtTs);
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