// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {APPLIED, COLLATERALIZED} from "../../../contracts/type/StateId.sol";
import {Amount} from "../../../contracts/type/Amount.sol";
import {console} from "../../../lib/forge-std/src/Test.sol";
import {FeeLib} from "../../../contracts/type/Fee.sol";
import {IComponents} from "../../../contracts/instance/module/IComponents.sol";
import {IDistribution} from "../../../contracts/instance/module/IDistribution.sol";
import {IDistributionService} from "../../../contracts/distribution/IDistributionService.sol";
import {IPolicy} from "../../../contracts/instance/module/IPolicy.sol";
import {NftId, NftIdLib} from "../../../contracts/type/NftId.sol";
import {POLICY} from "../../../contracts/type/ObjectType.sol";
import {ReferralId, ReferralLib} from "../../../contracts/type/Referral.sol";
import {ReferralTestBase} from "./ReferralTestBase.sol";
import {RiskId, RiskIdLib} from "../../../contracts/type/RiskId.sol";
import {SecondsLib} from "../../../contracts/type/Seconds.sol";
import {SimpleDistribution} from "../../../contracts/examples/unpermissioned/SimpleDistribution.sol";
import {Timestamp, TimestampLib} from "../../../contracts/type/Timestamp.sol";
import {UFixed, UFixedLib} from "../../../contracts/type/UFixed.sol";

contract ReferralTest is ReferralTestBase {

    function setUp() public override {
        super.setUp();
        _prepareProduct();
    }

    function test_referralIsValidTrue() public {
        _setupTestData(true);

        // solhint-disable-next-line 
        console.log("distributor nft id", distributorNftId.toInt());

        SimpleDistribution sdistribution = SimpleDistribution(address(distribution));

        vm.startPrank(customer);
        referralId = sdistribution.createReferral(
            distributorNftId,
            referralCode,
            discountPercentage,
            maxReferrals,
            expiryAt,
            referralData);
        vm.stopPrank();

        assertTrue(distributionService.referralIsValid(distributionNftId, referralId), "referral is not valid");
    }

    function test_referralIsValidFalse() public {
        _setupTestData(true);

        // solhint-disable-next-line 
        console.log("distributor nft id", distributorNftId.toInt());

        SimpleDistribution sdistribution = SimpleDistribution(address(distribution));

        vm.startPrank(customer);
        referralId = sdistribution.createReferral(
            distributorNftId,
            referralCode,
            discountPercentage,
            maxReferrals,
            expiryAt,
            referralData);
        vm.stopPrank();

        assertFalse(distributionService.referralIsValid(distributionNftId, ReferralLib.toReferralId(distributionNftId, "UNKNOWN")), "referral is valid");
    }

    function test_referralCollateralizeWithReferral() public {

        _setupTestData(true);

        Amount bundleBalanceInitial = instanceReader.getBalanceAmount(bundleNftId);
        Amount bundleFeeInitial = instanceReader.getFeeAmount(bundleNftId);

        assertEq(instanceReader.getBalanceAmount(bundleNftId).toInt(), bundleBalanceInitial.toInt(), "unexpected initial bundle balance");
        assertEq(instanceReader.getFeeAmount(bundleNftId).toInt(), bundleFeeInitial.toInt(), "unexpected initial bundle balance");

        // GIVEN
        vm.startPrank(tokenIssuer);
        token.transfer(customer, 1000);
        vm.stopPrank();

        uint256 initialCustomerBalance = token.balanceOf(customer);
        uint256 initialPoolBalance = token.balanceOf(pool.getWallet());

        // create risk
        vm.startPrank(productOwner);
        bytes memory data = "bla di blubb";
        RiskId riskId = product.createRisk("42x4711", data);
        vm.stopPrank();

        vm.startPrank(customer);
        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(productNftId);
        token.approve(address(componentInfo.tokenHandler), 1000);

        referralId = distribution.createReferral(
            distributorNftId,
            referralCode,
            UFixedLib.toUFixed(5, -2),
            maxReferrals,
            expiryAt,
            referralData);

        NftId policyNftId = product.createApplication(
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

        assertTrue(instance.getProductStore().getState(policyNftId.toKey32(POLICY())) == APPLIED(), "state not APPLIED");
        
        vm.stopPrank();

        assertEq(instanceReader.getBalanceAmount(distributionNftId).toInt(), 0, "unexpected initial distribution balance");
        assertEq(instanceReader.getFeeAmount(distributionNftId).toInt(), 0, "unexpected initial distribution fees");

        // WHEN
        vm.startPrank(productOwner);
        product.createPolicy(policyNftId, true, TimestampLib.current()); 
        vm.stopPrank();

        // THEN - check 13 tokens in distribution wallet (120 premium ), 887 tokens in customer wallet, 10100 tokens in pool wallet
        assertTrue(instanceReader.getPolicyState(policyNftId) == COLLATERALIZED(), "policy state not COLLATERALIZED");

        uint256 netPremium = 100;
        uint256 expectedPremium = netPremium + 17; // 100 (net premium) + 17 (distribution fee 3 + pool fee 3 + 11 distributor commission)
        assertEq(token.balanceOf(address(customer)), initialCustomerBalance - expectedPremium, "customer balance not 883");

        {
            IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
            assertEq(policyInfo.premiumAmount.toInt(), expectedPremium, "unexpected policy premium amount");
            assertTrue(policyInfo.activatedAt.gtz(), "activatedAt not set");
            assertTrue(policyInfo.expiredAt.gtz(), "expiredAt not set");
        }

        // check distribution financials and balance
        assertEq(token.balanceOf(distribution.getWallet()), 14, "distribution balance not 14 (1)");
        assertEq(instanceReader.getBalanceAmount(distributionNftId).toInt(), 14, "distribution balance not 14 (2)");
        assertEq(instanceReader.getFeeAmount(distributionNftId).toInt(), 11, "distribution fee not 14");

        {
            IDistribution.DistributorInfo memory distributorInfo = instanceReader.getDistributorInfo(distributorNftId);
            assertEq(distributorInfo.numPoliciesSold, 1, "numPoliciesSold not 1");
            assertEq(instanceReader.getFeeAmount(distributorNftId).toInt(), 3, "sumCommisions not 3");
        }

        // check pool financials and balance
        {
            uint256 expectedPoolFee = 3;
            assertEq(instanceReader.getBalanceAmount(poolNftId).toInt(), initialPoolBalance + netPremium + expectedPoolFee, "unexpected pool balance (1)");
            assertEq(token.balanceOf(pool.getWallet()), initialPoolBalance + netPremium + expectedPoolFee, "unexpected pool balance (2)");
        }

        assertEq(instanceBundleSet.activePolicies(bundleNftId), 1, "expected one active policy");
        assertTrue(instanceBundleSet.getActivePolicy(bundleNftId, 0).eq(policyNftId), "active policy nft id in bundle manager not equal to policy nft id");

        // check bundle financials
        {
            Amount lockedAmount = instanceReader.getLockedAmount(bundleNftId);
            assertEq(lockedAmount.toInt(), 1000, "unexpected lockedAmount");
            Amount capitalAmount = instanceReader.getBalanceAmount(bundleNftId) - instanceReader.getFeeAmount(bundleNftId);
            assertEq(capitalAmount.toInt(), bundleBalanceInitial.toInt() + 100, "unexpected capitalAmount");
        }
    }

    function test_referralCollateralizeMultipleWithReferral() public {
        uint256 bundleAmount = 10000;

        _setupTestData(true);
        // _setupBundle(bundleAmount);

        // GIVEN - two policies to collateralize
        vm.startPrank(tokenIssuer);
        token.transfer(customer, 1000);
        token.transfer(customer2, 1000);
        vm.stopPrank();

        vm.startPrank(productOwner);
        bytes memory data = "bla di blubb";
        RiskId riskId = product.createRisk("42x4711", data);
        vm.stopPrank();

        vm.startPrank(customer);

        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(productNftId);
        token.approve(address(componentInfo.tokenHandler), 1000);

        referralId = distribution.createReferral(
            distributorNftId,
            referralCode,
            UFixedLib.toUFixed(5, -2),
            maxReferrals,
            expiryAt,
            referralData);

        NftId policyNftId = product.createApplication(
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

        NftId policyNftId2 = product.createApplication(
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
        
        vm.stopPrank();

        Amount capitalAmountBefore = instanceReader.getBalanceAmount(bundleNftId) - instanceReader.getFeeAmount(bundleNftId);

        // WHEN
        vm.startPrank(productOwner);
        product.createPolicy(policyNftId, true, TimestampLib.current()); 
        product.createPolicy(policyNftId2, true, TimestampLib.current()); 

        // THEN - check 13 tokens in distribution wallet (120 premium ), 887 tokens in customer wallet, 10100 tokens in pool wallet
        assertTrue(instanceReader.getPolicyState(policyNftId) == COLLATERALIZED(), "policy state not COLLATERALIZED");
        assertTrue(instanceReader.getPolicyState(policyNftId2) == COLLATERALIZED(), "policy state not COLLATERALIZED");

        Amount lockedAmount = instanceReader.getLockedAmount(bundleNftId);
        assertEq(lockedAmount.toInt(), 2000, "unexpected lockedAmount (not 2000)");
        Amount capitalAmount = instanceReader.getBalanceAmount(bundleNftId) - instanceReader.getFeeAmount(bundleNftId);
        assertEq(capitalAmount.toInt() - capitalAmountBefore.toInt(), 200, "capitalAmount increase not 200");
        
        assertEq(token.balanceOf(distribution.getWallet()), 28, "distribution balance not 14");
        
        assertEq(instanceBundleSet.activePolicies(bundleNftId), 2, "expected one active policy");
        
        IDistribution.DistributorInfo memory distributorInfo = instanceReader.getDistributorInfo(distributorNftId);
        assertEq(distributorInfo.numPoliciesSold, 2, "numPoliciesSold not 2");
        assertEq(instanceReader.getFeeAmount(distributorNftId).toInt(), 6, "commissionAmount not 6");

        assertEq(instanceReader.getFeeAmount(distributionNftId).toInt(), 22, "sumDistributionOwnerFees not 22");
        vm.stopPrank();

        // --------------------------------------------------------------
        // GIVEN one more policy to collateralize with a different referral
        vm.startPrank(distributionOwner);
        NftId distributorNftId2 = distribution.createDistributor(
            distributor,
            distributorType,
            distributorData);
        vm.stopPrank();

        vm.startPrank(distributor);
        ReferralId referralId2 = distribution.createReferral(
            distributorNftId2,
            "SAVE2!!!",
            UFixedLib.toUFixed(5, -2),
            maxReferrals,
            expiryAt,
            referralData);
        vm.stopPrank();

        vm.startPrank(customer2);
        token.approve(address(componentInfo.tokenHandler), 1000);

        NftId policyNftId3 = product.createApplication(
            customer2,
            riskId,
            1000,
            SecondsLib.toSeconds(30),
            "",
            bundleNftId,
            referralId2
        );

        // WHEN 
        product.createPolicy(policyNftId3, true, TimestampLib.current()); 

        // THEN 
        assertTrue(instanceReader.getPolicyState(policyNftId3) == COLLATERALIZED(), "policy3 state not COLLATERALIZED");

        lockedAmount = instanceReader.getLockedAmount(bundleNftId);
        assertEq(lockedAmount.toInt(), 3000, "unexpected lockedAmount (not 3000)");

        capitalAmount = instanceReader.getBalanceAmount(bundleNftId) - instanceReader.getFeeAmount(bundleNftId);
        assertEq(capitalAmount.toInt() - capitalAmountBefore.toInt(), 300, "unexpected capitalAmount increase (not 300)");
        
        assertEq(token.balanceOf(distribution.getWallet()), 42, "distribution balance not 42");
        
        assertEq(instanceBundleSet.activePolicies(bundleNftId), 3, "expected one active policy");

        assertEq(instanceReader.getFeeAmount(distributionNftId).toInt(), 33, "sumDistributionOwnerFees not 33");
        vm.stopPrank();
    }

    function test_referralCreateCodeEmpty() public {
        // GIVEN
        _setupTestData(true);
    
        vm.startPrank(customer);

        // THEN
        vm.expectRevert(abi.encodeWithSelector(
            IDistributionService.ErrorDistributionServiceInvalidReferral.selector));

        // WHEN
        referralId = distribution.createReferral(
            distributorNftId,
            "",
            discountPercentage,
            maxReferrals,
            expiryAt,
            referralData);
    }

    function test_referralCreateExpirationInvalid() public {
        // GIVEN
        _setupTestData(true);

        vm.warp(500);

        vm.startPrank(customer);
        Timestamp tsZero = TimestampLib.zero();

        // THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                IDistributionService.ErrorDistributionServiceExpirationInvalid.selector,
                0));

        // WHEN
        referralId = distribution.createReferral(
            distributorNftId,
            "CODE",
            discountPercentage,
            maxReferrals,
            tsZero,
            referralData);

        Timestamp exp =  TimestampLib.toTimestamp(TimestampLib.current().toInt() - 10);

        // THEN
        vm.expectRevert(abi.encodeWithSelector(
            IDistributionService.ErrorDistributionServiceExpirationInvalid.selector,
            exp));

        // WHEN
        referralId = distribution.createReferral(
            distributorNftId,
            "CODE",
            discountPercentage,
            maxReferrals,
            exp,
            referralData);

        exp =  TimestampLib.toTimestamp(TimestampLib.current().toInt() + maxReferralLifetime.toInt() + 10);

        // THEN
        vm.expectRevert(abi.encodeWithSelector(
            IDistributionService.ErrorDistributionServiceExpiryTooLong.selector,
            maxReferralLifetime,
            exp));

        // WHEN
        referralId = distribution.createReferral(
            distributorNftId,
            "CODE",
            discountPercentage,
            maxReferrals,
            exp,
            referralData);
    }


    function test_createReferral_referralCountInvalid() public {
        // GIVEN
        _setupTestData(true);
        vm.startPrank(customer);
        Timestamp exp = TimestampLib.current().addSeconds(SecondsLib.toSeconds(10));

        // THEN
        vm.expectRevert(abi.encodeWithSelector(
            IDistributionService.ErrorDistributionServiceMaxReferralsExceeded.selector,
            20,
            42));

        // WHEN
        referralId = distribution.createReferral(
            distributorNftId,
            "CODE",
            discountPercentage,
            42,
            exp,
            referralData);
    }

    function test_createReferral_discoundInvalid() public {
        // GIVEN
        _setupTestData(true);
        vm.startPrank(customer);
        Timestamp exp = TimestampLib.current().addSeconds(SecondsLib.toSeconds(10));
        UFixed discount = UFixedLib.toUFixed(3, -2);

        // THEN
        vm.expectRevert(abi.encodeWithSelector(
            IDistributionService.ErrorDistributionServiceDiscountTooLow.selector,
            minDiscountPercentage,
            discount));

        // WHEN
        referralId = distribution.createReferral(
            distributorNftId,
            "CODE",
            discount,
            15,
            exp,
            referralData);

        // THEN
        discount = UFixedLib.toUFixed(22, -2);
        vm.expectRevert(abi.encodeWithSelector(
            IDistributionService.ErrorDistributionServiceDiscountTooHigh.selector,
            maxDiscountPercentage,
            discount));

        // WHEN
        referralId = distribution.createReferral(
            distributorNftId,
            "CODE",
            discount,
            15,
            exp,
            referralData);
    }

    function _setupBundle(uint256 bundleAmount) internal {

        vm.startPrank(tokenIssuer);
        token.transfer(investor, bundleAmount);
        vm.stopPrank();

        vm.startPrank(investor);
        IComponents.ComponentInfo memory poolInfo = instanceReader.getComponentInfo(poolNftId);
        token.approve(address(poolInfo.tokenHandler), bundleAmount);

        // SimplePool spool = SimplePool(address(pool));
        (bundleNftId,) = pool.createBundle(
            FeeLib.zero(), 
            bundleAmount, 
            SecondsLib.toSeconds(604800), 
            ""
        );
        vm.stopPrank();
    }

}