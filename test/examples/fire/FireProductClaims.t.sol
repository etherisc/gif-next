// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {Amount, AmountLib} from "../../../contracts/type/Amount.sol";
import {APPLIED, CLOSED, COLLATERALIZED, PAID} from "../../../contracts/type/StateId.sol";
import {ClaimId} from "../../../contracts/type/ClaimId.sol";
import {DAMAGE_LARGE, DAMAGE_MEDIUM, DAMAGE_SMALL} from "../../../contracts/examples/fire/DamageLevel.sol";
import {Fee, FeeLib} from "../../../contracts/type/Fee.sol";
import {FireProduct, ONE_YEAR} from "../../../contracts/examples/fire/FireProduct.sol";
import {FireTestBase} from "./FireTestBase.t.sol";
import {IClaimService} from "../../../contracts/product/IClaimService.sol";
import {INftOwnable} from "../../../contracts/shared/INftOwnable.sol";
import {IPolicy} from "../../../contracts/instance/module/IPolicy.sol";
import {NftId} from "../../../contracts/type/NftId.sol";
import {PayoutId} from "../../../contracts/type/PayoutId.sol";
import {Seconds, SecondsLib} from "../../../contracts/type/Seconds.sol";
import {Timestamp, TimestampLib} from "../../../contracts/type/Timestamp.sol";
import {UFixedLib} from "../../../contracts/type/UFixed.sol";

// solhint-disable func-name-mixedcase
contract FireProductClaimsTest is FireTestBase {

    string public cityName;
    NftId public policyNftId;

    function setUp() public override {
        super.setUp();
        
        _createInitialBundle();
        cityName = "London";
        fireProduct.initializeCity(cityName);
    }

    function test_FireProductClaims_reportFire() public {
        // GIVEN
        Timestamp now = TimestampLib.blockTimestamp();
        uint256 fireId = 42;
        vm.startPrank(fireProductOwner);

        // WHEN
        fireProduct.reportFire(fireId, cityName, DAMAGE_SMALL(), now);

        // THEN
        FireProduct.Fire memory fire = fireProduct.fire(fireId);
        assertEq(cityName, fire.cityName);
        assertEq(DAMAGE_SMALL().toInt(), fire.damageLevel.toInt());
        assertEq(now, fire.reportedAt, "reportedAt mismatch");
    }

    function test_FireProductClaims_reportFire_invalidRole() public {
        // GIVEN
        Timestamp now = TimestampLib.blockTimestamp();
        uint256 fireId = 42;

        vm.startPrank(customer);
        
        // THEN - unauthorized
        vm.expectRevert(abi.encodeWithSelector(
            IAccessManaged.AccessManagedUnauthorized.selector, 
            customer));

        // WHEN - reportFire called by customer
        fireProduct.reportFire(fireId, cityName, DAMAGE_SMALL(), now);
    }

    function test_FireProductClaims_reportFire_duplicateId() public {
        // GIVEN
        Timestamp now = TimestampLib.blockTimestamp();
        uint256 fireId = 42;

        vm.startPrank(fireProductOwner);

        fireProduct.reportFire(fireId, cityName, DAMAGE_SMALL(), now);
        
        // THEN - unauthorized
        vm.expectRevert(abi.encodeWithSelector(
            FireProduct.ErrorFireProductFireAlreadyReported.selector));

        // WHEN - reportFire called by customer
        fireProduct.reportFire(fireId, cityName, DAMAGE_SMALL(), now);
    }

    function test_FireProductClaims_reportFire_unknownCity() public {
        // GIVEN
        Timestamp now = TimestampLib.blockTimestamp();
        uint256 fireId = 42;

        vm.startPrank(fireProductOwner);
        
        // THEN - city unknown
        vm.expectRevert(abi.encodeWithSelector(
            FireProduct.ErrorFireProductCityUnknown.selector,
            "Zurich"));

        // WHEN - reportFire called by customer
        fireProduct.reportFire(fireId, "Zurich", DAMAGE_SMALL(), now);
    }

    function test_FireProductClaims_reportFire_tooEarly() public {
        // GIVEN
        Timestamp now = TimestampLib.blockTimestamp();
        uint256 fireId = 42;

        vm.startPrank(fireProductOwner);
        vm.warp(100);
        
        // THEN - too early
        vm.expectRevert(abi.encodeWithSelector(
            FireProduct.ErrorFireProductTimestampTooEarly.selector));

        // WHEN - reportFire called by customer
        fireProduct.reportFire(fireId, cityName, DAMAGE_SMALL(), now);
    }

    /// @dev Test submitClaim with small fire damage and test that all counters are updated correctly and tokens transferred
    function test_FireProductClaims_submitClaim_smallFire() public {
        // GIVEN
        Amount sumInsured = AmountLib.toAmount(100000 * 10 ** 6);
        Timestamp now = TimestampLib.blockTimestamp();
        policyNftId = _preparePolicy(
            customer,
            cityName, 
            sumInsured, 
            ONE_YEAR(), 
            now,
            bundleNftId);
        
        vm.startPrank(fireProductOwner);
        uint256 fireId = 42;
        fireProduct.reportFire(fireId, cityName, DAMAGE_SMALL(), now);
        vm.stopPrank();
        
        vm.startPrank(customer);

        uint256 customerTokenBalanceBefore = fireUSD.balanceOf(customer);
        uint256 poolTokenBalanceBefore = fireUSD.balanceOf(firePool.getWallet());
        Amount poolBalanceBefore = instanceReader.getBalanceAmount(firePoolNftId);
        Amount bundleBalanceBefore = instanceReader.getBalanceAmount(bundleNftId);
        Amount bundleLockedBefore = instanceReader.getLockedAmount(bundleNftId);
        
        // WHEN - submit claim
        (ClaimId claimId, PayoutId payoutId) = fireProduct.submitClaim(policyNftId, fireId);
        Timestamp claimSubmittedAt = TimestampLib.blockTimestamp();
        
        // THEN
        Amount expectedClaimAmount = sumInsured.multiplyWith(UFixedLib.toUFixed(25, -2));

        // assert policy state and info
        assertTrue(COLLATERALIZED().eq(instanceReader.getPolicyState(policyNftId)));
        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertEq(1, policyInfo.claimsCount);
        assertEq(0, policyInfo.openClaimsCount);
        assertEq(expectedClaimAmount, policyInfo.claimAmount, "claimAmount mismatch");
        assertEq(expectedClaimAmount, policyInfo.payoutAmount, "payoutAmount mismatch");
        
        // assert claim state and info
        assertTrue(CLOSED().eq(instanceReader.getClaimState(policyNftId, claimId)));
        IPolicy.ClaimInfo memory claimInfo = instanceReader.getClaimInfo(policyNftId, claimId);
        assertEq(expectedClaimAmount, claimInfo.claimAmount, "claimAmount mismatch");
        assertEq(expectedClaimAmount, claimInfo.paidAmount, "paidAmount mismatch");
        assertEq(1, claimInfo.payoutsCount);
        assertEq(0, claimInfo.openPayoutsCount);
        assertEq(claimSubmittedAt, claimInfo.closedAt, "closedAt mismatch");

        // assert payout state and info
        assertTrue(PAID().eq(instanceReader.getPayoutState(policyNftId, payoutId)));
        IPolicy.PayoutInfo memory payoutInfo = instanceReader.getPayoutInfo(policyNftId, payoutId);
        assertTrue(claimId == payoutInfo.claimId, "claimId mismatch");
        assertEq(expectedClaimAmount, payoutInfo.amount, "amount mismatch");
        assertEq(customer, payoutInfo.beneficiary, "beneficiary mismatch");
        assertEq(claimSubmittedAt, payoutInfo.paidAt, "paidAt mismatch");

        // assert token balances
        assertEq(customerTokenBalanceBefore + expectedClaimAmount.toInt(), fireUSD.balanceOf(customer), "customerTokenBalance mismatch");
        assertEq(poolTokenBalanceBefore - expectedClaimAmount.toInt(), fireUSD.balanceOf(firePool.getWallet()), "poolTokenBalance mismatch");
        assertEq(poolBalanceBefore - expectedClaimAmount, instanceReader.getBalanceAmount(firePoolNftId), "poolBalance mismatch");
        assertEq(bundleBalanceBefore - expectedClaimAmount, instanceReader.getBalanceAmount(bundleNftId), "bundleBalance mismatch");
        assertEq(bundleLockedBefore - expectedClaimAmount, instanceReader.getLockedAmount(bundleNftId), "bundleLocked mismatch");
    }

    /// @dev Test submitClaim with medium fire damage and test that all counters are updated correctly and tokens transferred
    function test_FireProductClaims_submitClaim_mediumFire() public {
        // GIVEN
        Amount sumInsured = AmountLib.toAmount(100000 * 10 ** 6);
        Timestamp now = TimestampLib.blockTimestamp();
        policyNftId = _preparePolicy(
            customer,
            cityName, 
            sumInsured, 
            ONE_YEAR(), 
            now,
            bundleNftId);
        
        vm.startPrank(fireProductOwner);
        uint256 fireId = 42;
        fireProduct.reportFire(fireId, cityName, DAMAGE_MEDIUM(), now);
        vm.stopPrank();
        
        vm.startPrank(customer);

        uint256 customerTokenBalanceBefore = fireUSD.balanceOf(customer);
        uint256 poolTokenBalanceBefore = fireUSD.balanceOf(firePool.getWallet());
        Amount poolBalanceBefore = instanceReader.getBalanceAmount(firePoolNftId);
        Amount bundleBalanceBefore = instanceReader.getBalanceAmount(bundleNftId);
        Amount bundleLockedBefore = instanceReader.getLockedAmount(bundleNftId);
        
        // WHEN - submit claim
        (ClaimId claimId, PayoutId payoutId) = fireProduct.submitClaim(policyNftId, fireId);
        Timestamp claimSubmittedAt = TimestampLib.blockTimestamp();
        
        // THEN
        Amount expectedClaimAmount = sumInsured.multiplyWith(UFixedLib.toUFixed(5, -1));

        // assert policy state and info
        assertTrue(COLLATERALIZED().eq(instanceReader.getPolicyState(policyNftId)));
        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertEq(1, policyInfo.claimsCount);
        assertEq(0, policyInfo.openClaimsCount);
        assertEq(expectedClaimAmount, policyInfo.claimAmount, "claimAmount mismatch");
        assertEq(expectedClaimAmount, policyInfo.payoutAmount, "payoutAmount mismatch");
        
        // assert claim state and info
        assertTrue(CLOSED().eq(instanceReader.getClaimState(policyNftId, claimId)));
        IPolicy.ClaimInfo memory claimInfo = instanceReader.getClaimInfo(policyNftId, claimId);
        assertEq(expectedClaimAmount, claimInfo.claimAmount, "claimAmount mismatch");
        assertEq(expectedClaimAmount, claimInfo.paidAmount, "paidAmount mismatch");
        assertEq(1, claimInfo.payoutsCount);
        assertEq(0, claimInfo.openPayoutsCount);
        assertEq(claimSubmittedAt, claimInfo.closedAt, "closedAt mismatch");

        // assert payout state and info
        assertTrue(PAID().eq(instanceReader.getPayoutState(policyNftId, payoutId)));
        IPolicy.PayoutInfo memory payoutInfo = instanceReader.getPayoutInfo(policyNftId, payoutId);
        assertTrue(claimId == payoutInfo.claimId, "claimId mismatch");
        assertEq(expectedClaimAmount, payoutInfo.amount, "amount mismatch");
        assertEq(customer, payoutInfo.beneficiary, "beneficiary mismatch");
        assertEq(claimSubmittedAt, payoutInfo.paidAt, "paidAt mismatch");

        // assert token balances
        assertEq(customerTokenBalanceBefore + expectedClaimAmount.toInt(), fireUSD.balanceOf(customer), "customerTokenBalance mismatch");
        assertEq(poolTokenBalanceBefore - expectedClaimAmount.toInt(), fireUSD.balanceOf(firePool.getWallet()), "poolTokenBalance mismatch");
        assertEq(poolBalanceBefore - expectedClaimAmount, instanceReader.getBalanceAmount(firePoolNftId), "poolBalance mismatch");
        assertEq(bundleBalanceBefore - expectedClaimAmount, instanceReader.getBalanceAmount(bundleNftId), "bundleBalance mismatch");
        assertEq(bundleLockedBefore - expectedClaimAmount, instanceReader.getLockedAmount(bundleNftId), "bundleLocked mismatch");
    }

    /// @dev Test submitClaim with large fire damage and test that all counters are updated correctly and tokens transferred
    function test_FireProductClaims_submitClaim_largeFire() public {
        // GIVEN
        Amount sumInsured = AmountLib.toAmount(100000 * 10 ** 6);
        Timestamp now = TimestampLib.blockTimestamp();
        policyNftId = _preparePolicy(
            customer,
            cityName, 
            sumInsured, 
            ONE_YEAR(), 
            now,
            bundleNftId);
        
        vm.startPrank(fireProductOwner);
        uint256 fireId = 42;
        fireProduct.reportFire(fireId, cityName, DAMAGE_LARGE(), now);
        vm.stopPrank();
        
        vm.startPrank(customer);

        uint256 customerTokenBalanceBefore = fireUSD.balanceOf(customer);
        uint256 poolTokenBalanceBefore = fireUSD.balanceOf(firePool.getWallet());
        Amount poolBalanceBefore = instanceReader.getBalanceAmount(firePoolNftId);
        Amount bundleBalanceBefore = instanceReader.getBalanceAmount(bundleNftId);
        Amount bundleLockedBefore = instanceReader.getLockedAmount(bundleNftId);
        
        // WHEN - submit claim
        (ClaimId claimId, PayoutId payoutId) = fireProduct.submitClaim(policyNftId, fireId);
        Timestamp claimSubmittedAt = TimestampLib.blockTimestamp();
        
        // THEN
        Amount expectedClaimAmount = sumInsured;
        
        // assert policy state and info
        assertTrue(COLLATERALIZED().eq(instanceReader.getPolicyState(policyNftId)));
        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertEq(1, policyInfo.claimsCount);
        assertEq(0, policyInfo.openClaimsCount);
        assertEq(expectedClaimAmount, policyInfo.claimAmount, "claimAmount mismatch");
        assertEq(expectedClaimAmount, policyInfo.payoutAmount, "payoutAmount mismatch");
        assertEq(claimSubmittedAt, policyInfo.expiredAt, "expiredAt mismatch");
        assertEq(TimestampLib.zero(), policyInfo.closedAt, "closedAt mismatch");
        
        // assert claim state and info
        assertTrue(CLOSED().eq(instanceReader.getClaimState(policyNftId, claimId)));
        IPolicy.ClaimInfo memory claimInfo = instanceReader.getClaimInfo(policyNftId, claimId);
        assertEq(expectedClaimAmount, claimInfo.claimAmount, "claimAmount mismatch");
        assertEq(expectedClaimAmount, claimInfo.paidAmount, "paidAmount mismatch");
        assertEq(1, claimInfo.payoutsCount);
        assertEq(0, claimInfo.openPayoutsCount);
        assertEq(claimSubmittedAt, claimInfo.closedAt, "closedAt mismatch");

        // assert payout state and info
        assertTrue(PAID().eq(instanceReader.getPayoutState(policyNftId, payoutId)));
        IPolicy.PayoutInfo memory payoutInfo = instanceReader.getPayoutInfo(policyNftId, payoutId);
        assertTrue(claimId == payoutInfo.claimId, "claimId mismatch");
        assertEq(expectedClaimAmount, payoutInfo.amount, "amount mismatch");
        assertEq(customer, payoutInfo.beneficiary, "beneficiary mismatch");
        assertEq(claimSubmittedAt, payoutInfo.paidAt, "paidAt mismatch");

        // assert token balances
        assertEq(customerTokenBalanceBefore + expectedClaimAmount.toInt(), fireUSD.balanceOf(customer), "customerTokenBalance mismatch");
        assertEq(poolTokenBalanceBefore - expectedClaimAmount.toInt(), fireUSD.balanceOf(firePool.getWallet()), "poolTokenBalance mismatch");
        assertEq(poolBalanceBefore - expectedClaimAmount, instanceReader.getBalanceAmount(firePoolNftId), "poolBalance mismatch");
        assertEq(bundleBalanceBefore - expectedClaimAmount, instanceReader.getBalanceAmount(bundleNftId), "bundleBalance mismatch");
        assertEq(bundleLockedBefore - expectedClaimAmount, instanceReader.getLockedAmount(bundleNftId), "bundleLocked mismatch");
    }

    /// @dev Test submitClaim with two small fire damage and test that all counters are updated correctly and tokens transferred
    function test_FireProductClaims_submitClaim_twoSmallFires() public {
        // GIVEN
        Amount sumInsured = AmountLib.toAmount(100000 * 10 ** 6);
        Timestamp now = TimestampLib.blockTimestamp();
        policyNftId = _preparePolicy(
            customer,
            cityName, 
            sumInsured, 
            ONE_YEAR(), 
            now,
            bundleNftId);
        
        vm.startPrank(fireProductOwner);
        uint256 fireId = 42;
        uint256 fireId2 = 43;
        fireProduct.reportFire(fireId, cityName, DAMAGE_SMALL(), now);
        fireProduct.reportFire(fireId2, cityName, DAMAGE_SMALL(), now);
        vm.stopPrank();
        
        vm.startPrank(customer);

        uint256 customerTokenBalanceBefore = fireUSD.balanceOf(customer);
        uint256 poolTokenBalanceBefore = fireUSD.balanceOf(firePool.getWallet());
        Amount poolBalanceBefore = instanceReader.getBalanceAmount(firePoolNftId);
        Amount bundleBalanceBefore = instanceReader.getBalanceAmount(bundleNftId);
        Amount bundleLockedBefore = instanceReader.getLockedAmount(bundleNftId);
        
        // WHEN - submit two claim
        vm.warp(100);
        (ClaimId claimId, PayoutId payoutId) = fireProduct.submitClaim(policyNftId, fireId);
        Timestamp claimSubmittedAt = TimestampLib.blockTimestamp();
        vm.warp(100);
        (ClaimId claimId2, PayoutId payoutId2) = fireProduct.submitClaim(policyNftId, fireId2);
        Timestamp claimSubmittedAt2 = TimestampLib.blockTimestamp();
        
        // THEN
        Amount expectedClaimAmount = sumInsured.multiplyWith(UFixedLib.toUFixed(25, -2));
        Amount expectedClaimAmountTotal = expectedClaimAmount + expectedClaimAmount;

        // assert policy state and info
        {
            assertTrue(COLLATERALIZED().eq(instanceReader.getPolicyState(policyNftId)));
            IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
            assertEq(2, policyInfo.claimsCount);
            assertEq(0, policyInfo.openClaimsCount);
            assertEq(expectedClaimAmountTotal, policyInfo.claimAmount, "claimAmount mismatch");
            assertEq(expectedClaimAmountTotal, policyInfo.payoutAmount, "payoutAmount mismatch");
        }
        
        // assert claim state and info
        {
            assertTrue(CLOSED().eq(instanceReader.getClaimState(policyNftId, claimId)));
            IPolicy.ClaimInfo memory claimInfo = instanceReader.getClaimInfo(policyNftId, claimId);
            assertEq(expectedClaimAmount, claimInfo.claimAmount, "claimAmount mismatch");
            assertEq(expectedClaimAmount, claimInfo.paidAmount, "paidAmount mismatch");
            assertEq(1, claimInfo.payoutsCount);
            assertEq(0, claimInfo.openPayoutsCount);
            assertEq(claimSubmittedAt, claimInfo.closedAt, "closedAt mismatch");

            assertTrue(CLOSED().eq(instanceReader.getClaimState(policyNftId, claimId2)));
            claimInfo = instanceReader.getClaimInfo(policyNftId, claimId2);
            assertEq(expectedClaimAmount, claimInfo.claimAmount, "claimAmount mismatch (2)");
            assertEq(expectedClaimAmount, claimInfo.paidAmount, "paidAmount mismatch (2)");
            assertEq(1, claimInfo.payoutsCount);
            assertEq(0, claimInfo.openPayoutsCount);
            assertEq(claimSubmittedAt2, claimInfo.closedAt, "closedAt mismatch (2)");
        }

        // assert payout state and info
        {
            assertTrue(PAID().eq(instanceReader.getPayoutState(policyNftId, payoutId)));
            IPolicy.PayoutInfo memory payoutInfo = instanceReader.getPayoutInfo(policyNftId, payoutId);
            assertTrue(claimId == payoutInfo.claimId, "claimId mismatch");
            assertEq(expectedClaimAmount, payoutInfo.amount, "amount mismatch");
            assertEq(customer, payoutInfo.beneficiary, "beneficiary mismatch");
            assertEq(claimSubmittedAt, payoutInfo.paidAt, "paidAt mismatch");

            assertTrue(PAID().eq(instanceReader.getPayoutState(policyNftId, payoutId2)));
            payoutInfo = instanceReader.getPayoutInfo(policyNftId, payoutId2);
            assertTrue(claimId2 == payoutInfo.claimId, "claimId mismatch (2)");
            assertEq(expectedClaimAmount, payoutInfo.amount, "amount mismatch (2)");
            assertEq(customer, payoutInfo.beneficiary, "beneficiary mismatch (2)");
            assertEq(claimSubmittedAt2, payoutInfo.paidAt, "paidAt mismatch (2)");
        }

        // assert token balances
        {
            assertEq(customerTokenBalanceBefore + expectedClaimAmountTotal.toInt(), fireUSD.balanceOf(customer), "customerTokenBalance mismatch");
            assertEq(poolTokenBalanceBefore - expectedClaimAmountTotal.toInt(), fireUSD.balanceOf(firePool.getWallet()), "poolTokenBalance mismatch");
            assertEq(poolBalanceBefore - expectedClaimAmountTotal, instanceReader.getBalanceAmount(firePoolNftId), "poolBalance mismatch");
            assertEq(bundleBalanceBefore - expectedClaimAmountTotal, instanceReader.getBalanceAmount(bundleNftId), "bundleBalance mismatch");
            assertEq(bundleLockedBefore - expectedClaimAmountTotal, instanceReader.getLockedAmount(bundleNftId), "bundleLocked mismatch");
        }
    }

    /// @dev Test submitClaim with small fire damage and one for a large fire. expect full sum insured to be payed out, 
    /// but seconds claim only pays 75% as the sumInsured is already exhausted
    function test_FireProductClaims_submitClaim_oneSmallOneLargeFire() public {
        // GIVEN
        Amount sumInsured = AmountLib.toAmount(100000 * 10 ** 6);
        {
            Timestamp now = TimestampLib.blockTimestamp();
            policyNftId = _preparePolicy(
                customer,
                cityName, 
                sumInsured, 
                ONE_YEAR(), 
                now,
                bundleNftId);
            
            vm.startPrank(fireProductOwner);
            fireProduct.reportFire(42, cityName, DAMAGE_SMALL(), now);
            fireProduct.reportFire(43, cityName, DAMAGE_LARGE(), now);
            vm.stopPrank();
        }
        
        vm.startPrank(customer);

        uint256 customerTokenBalanceBefore = fireUSD.balanceOf(customer);
        uint256 poolTokenBalanceBefore = fireUSD.balanceOf(firePool.getWallet());
        Amount poolBalanceBefore = instanceReader.getBalanceAmount(firePoolNftId);
        Amount bundleBalanceBefore = instanceReader.getBalanceAmount(bundleNftId);
        Amount bundleLockedBefore = instanceReader.getLockedAmount(bundleNftId);
        
        // WHEN - submit two claims
        vm.warp(100);
        (ClaimId claimId, PayoutId payoutId) = fireProduct.submitClaim(policyNftId, 42);
        Timestamp claimSubmittedAt = TimestampLib.blockTimestamp();
        vm.warp(100);
        (ClaimId claimId2, PayoutId payoutId2) = fireProduct.submitClaim(policyNftId, 43);
        Timestamp claimSubmittedAt2 = TimestampLib.blockTimestamp();

        vm.stopPrank();
        
        // THEN
        {
            Amount expectedClaimAmount1 = sumInsured.multiplyWith(UFixedLib.toUFixed(25, -2));
            Amount expectedPayoutAmount2 = sumInsured.multiplyWith(UFixedLib.toUFixed(75, -2));

            // assert policy state and info
            {
                assertTrue(COLLATERALIZED().eq(instanceReader.getPolicyState(policyNftId)));
                IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
                assertEq(sumInsured, policyInfo.claimAmount, "policyInfo.claimAmount mismatch");
                assertEq(sumInsured, policyInfo.payoutAmount, "policyInfo.payoutAmount mismatch");
                assertEq(2, policyInfo.claimsCount);
                assertEq(0, policyInfo.openClaimsCount);
                assertEq(claimSubmittedAt2, policyInfo.expiredAt, "policyInfo.expiredAt mismatch");
                assertEq(TimestampLib.zero(), policyInfo.closedAt, "policyInfo.closedAt mismatch");
            }
            
            // assert claim state and info
            {
                assertTrue(CLOSED().eq(instanceReader.getClaimState(policyNftId, claimId)));
                IPolicy.ClaimInfo memory claimInfo = instanceReader.getClaimInfo(policyNftId, claimId);
                assertEq(expectedClaimAmount1, claimInfo.claimAmount, "claimAmount mismatch");
                assertEq(expectedClaimAmount1, claimInfo.paidAmount, "paidAmount mismatch");
                assertEq(1, claimInfo.payoutsCount);
                assertEq(0, claimInfo.openPayoutsCount);
                assertEq(claimSubmittedAt, claimInfo.closedAt, "closedAt mismatch");

                assertTrue(CLOSED().eq(instanceReader.getClaimState(policyNftId, claimId2)));
                claimInfo = instanceReader.getClaimInfo(policyNftId, claimId2);
                assertEq(expectedPayoutAmount2, claimInfo.claimAmount, "claimAmount mismatch (2)");
                assertEq(expectedPayoutAmount2, claimInfo.paidAmount, "paidAmount mismatch (2)");
                assertEq(1, claimInfo.payoutsCount);
                assertEq(0, claimInfo.openPayoutsCount);
                assertEq(claimSubmittedAt2, claimInfo.closedAt, "closedAt mismatch (2)");
            }

            // assert payout state and info
            {
                assertTrue(PAID().eq(instanceReader.getPayoutState(policyNftId, payoutId)));
                IPolicy.PayoutInfo memory payoutInfo = instanceReader.getPayoutInfo(policyNftId, payoutId);
                assertTrue(claimId == payoutInfo.claimId, "claimId mismatch");
                assertEq(expectedClaimAmount1, payoutInfo.amount, "amount mismatch");
                assertEq(customer, payoutInfo.beneficiary, "beneficiary mismatch");
                assertEq(claimSubmittedAt, payoutInfo.paidAt, "paidAt mismatch");

                assertTrue(PAID().eq(instanceReader.getPayoutState(policyNftId, payoutId2)));
                payoutInfo = instanceReader.getPayoutInfo(policyNftId, payoutId2);
                assertTrue(claimId2 == payoutInfo.claimId, "claimId mismatch (2)");
                assertEq(expectedPayoutAmount2, payoutInfo.amount, "amount mismatch (2)");
                assertEq(customer, payoutInfo.beneficiary, "beneficiary mismatch (2)");
                assertEq(claimSubmittedAt2, payoutInfo.paidAt, "paidAt mismatch (2)");
            }
        }

        // assert token balances
        {
            assertEq(customerTokenBalanceBefore + sumInsured.toInt(), fireUSD.balanceOf(customer), "customerTokenBalance mismatch");
            assertEq(poolTokenBalanceBefore - sumInsured.toInt(), fireUSD.balanceOf(firePool.getWallet()), "poolTokenBalance mismatch");
            assertEq(poolBalanceBefore - sumInsured, instanceReader.getBalanceAmount(firePoolNftId), "poolBalance mismatch");
            assertEq(bundleBalanceBefore - sumInsured, instanceReader.getBalanceAmount(bundleNftId), "bundleBalance mismatch");
            assertEq(bundleLockedBefore - sumInsured, instanceReader.getLockedAmount(bundleNftId), "bundleLocked mismatch");
        }
    }

    /// @dev Test submitClaim with a user that it not the nft owner
    function test_FireProductClaims_submitClaim_notNftOwner() public {
        // GIVEN
        Amount sumInsured = AmountLib.toAmount(100000 * 10 ** 6);
        Timestamp now = TimestampLib.blockTimestamp();
        policyNftId = _preparePolicy(
            customer,
            cityName, 
            sumInsured, 
            ONE_YEAR(), 
            now,
            bundleNftId);
        
        vm.startPrank(fireProductOwner);
        uint256 fireId = 42;
        fireProduct.reportFire(fireId, cityName, DAMAGE_SMALL(), now);
        vm.stopPrank();
        
        vm.startPrank(customer2);

        // THEN - expect revert
        vm.expectRevert(abi.encodeWithSelector(
            INftOwnable.ErrorNftOwnableNotOwner.selector,
            customer2));

        // WHEN - submit claim
        fireProduct.submitClaim(policyNftId, fireId);
    }

    /// @dev Test submitClaim with a user that it not the nft owner
    function test_FireProductClaims_submitClaim_notNftOwner2() public {
        // GIVEN
        Amount sumInsured = AmountLib.toAmount(100000 * 10 ** 6);
        Timestamp now = TimestampLib.blockTimestamp();
        policyNftId = _preparePolicy(
            customer,
            cityName, 
            sumInsured, 
            ONE_YEAR(), 
            now,
            bundleNftId);
        _fundAccount(customer2, 10000 * 10 ** 6);
        _preparePolicy(
            customer2,
            cityName, 
            sumInsured, 
            ONE_YEAR(), 
            now,
            bundleNftId);
        
        vm.startPrank(fireProductOwner);
        uint256 fireId = 42;
        fireProduct.reportFire(fireId, cityName, DAMAGE_SMALL(), now);
        vm.stopPrank();
        
        vm.startPrank(customer2);

        // THEN - expect revert
        vm.expectRevert(abi.encodeWithSelector(
            INftOwnable.ErrorNftOwnableNotOwner.selector,
            customer2));

        // WHEN - submit claim
        fireProduct.submitClaim(policyNftId, fireId);
    }

    /// @dev Test submitClaim for an unknown fireId
    function test_FireProductClaims_submitClaim_unknownFireId() public {
        // GIVEN
        Amount sumInsured = AmountLib.toAmount(100000 * 10 ** 6);
        Timestamp now = TimestampLib.blockTimestamp();
        policyNftId = _preparePolicy(
            customer,
            cityName, 
            sumInsured, 
            ONE_YEAR(), 
            now,
            bundleNftId);
        
        vm.startPrank(fireProductOwner);
        fireProduct.reportFire(42, cityName, DAMAGE_SMALL(), now);
        vm.stopPrank();
        
        vm.startPrank(customer);

        // THEN - expect revert
        vm.expectRevert(abi.encodeWithSelector(
            FireProduct.ErrorFireProductFireUnknown.selector,
            43));

        // WHEN - submit claim for unknown fire id
        fireProduct.submitClaim(policyNftId, 43);
    }

    /// @dev Test submitClaim for an already claimed fireId
    function test_FireProductClaims_submitClaim_alreadyClaimed() public {
        // GIVEN
        Amount sumInsured = AmountLib.toAmount(100000 * 10 ** 6);
        Timestamp now = TimestampLib.blockTimestamp();
        policyNftId = _preparePolicy(
            customer,
            cityName, 
            sumInsured, 
            ONE_YEAR(), 
            now,
            bundleNftId);
        
        vm.startPrank(fireProductOwner);
        uint256 fireId = 42;
        fireProduct.reportFire(fireId, cityName, DAMAGE_SMALL(), now);
        vm.stopPrank();
        
        vm.startPrank(customer);
        fireProduct.submitClaim(policyNftId, fireId);

        // THEN - expect revert
        vm.expectRevert(abi.encodeWithSelector(
            FireProduct.ErrorFireProductAlreadyClaimed.selector));

        // WHEN - submit claim for already claimed fire
        fireProduct.submitClaim(policyNftId, fireId);
    }

    /// @dev Test submitClaim for an expired policy
    function test_FireProductClaims_submitClaim_expiredPolicy() public {
        // GIVEN
        Amount sumInsured = AmountLib.toAmount(100000 * 10 ** 6);
        Timestamp now = TimestampLib.blockTimestamp();
        policyNftId = _preparePolicy(
            customer,
            cityName, 
            sumInsured, 
            ONE_YEAR(), 
            now,
            bundleNftId);
        
        vm.startPrank(fireProductOwner);
        uint256 fireId = 42;
        fireProduct.reportFire(fireId, cityName, DAMAGE_SMALL(), now);

        vm.warp(100);
        fireProduct.expire(policyNftId, TimestampLib.blockTimestamp());
        vm.stopPrank();
        
        vm.startPrank(customer);
        
        // THEN - expect revert
        vm.expectRevert(abi.encodeWithSelector(
            IClaimService.ErrorClaimServicePolicyNotOpen.selector,
            policyNftId));

        // WHEN - submit claim for expired policy
        fireProduct.submitClaim(policyNftId, fireId);
    }

    /// @dev Test submitClaim for a closed policy
    function test_FireProductClaims_submitClaim_closedPolicy() public {
        // GIVEN
        Amount sumInsured = AmountLib.toAmount(100000 * 10 ** 6);
        Timestamp now = TimestampLib.blockTimestamp();
        policyNftId = _preparePolicy(
            customer,
            cityName, 
            sumInsured, 
            ONE_YEAR(), 
            now,
            bundleNftId);
        
        vm.startPrank(fireProductOwner);
        uint256 fireId = 42;
        fireProduct.reportFire(fireId, cityName, DAMAGE_SMALL(), now);

        vm.warp(100);
        fireProduct.expire(policyNftId, TimestampLib.blockTimestamp());
        fireProduct.close(policyNftId);
        vm.stopPrank();
        
        vm.startPrank(customer);
        
        // THEN - expect revert
        vm.expectRevert(abi.encodeWithSelector(
            FireProduct.ErrorFireProductPolicyNotActive.selector,
            policyNftId));

        // WHEN - submit claim for closed policy
        fireProduct.submitClaim(policyNftId, fireId);
    }

    // TODO: test submitClaim wrong city
    // TODO: test submitClaim but policy closed
    // TODO: test submitClaim but not active yet
    // TODO: test submitClaim but already expired
    // TODO: test submitClaim invalid policy nft 
    // TODO: test submitClaim fire time after policy expired
    // TODO: test submitClaim fire time before policy active

    function _preparePolicy(
        address account,
        string memory cityName,
        Amount sumInsured,
        Seconds duration,
        Timestamp activateAt,
        NftId bundleNftId
    ) 
        internal 
        returns (NftId policyNftId)
    {
        // apply for policy
        vm.startPrank(account);
        Amount premium = fireProduct.calculatePremium(
            cityName, 
            sumInsured, 
            duration,
            bundleNftId);
        policyNftId = fireProduct.createApplication(
            cityName, 
            sumInsured, 
            duration, 
            bundleNftId);
        fireUSD.approve(address(fireProduct.getTokenHandler()), premium.toInt());
        vm.stopPrank();

        assertTrue(APPLIED().eq(instanceReader.getPolicyState(policyNftId)));
        
        vm.startPrank(fireProductOwner);
        fireProduct.createPolicy(policyNftId, activateAt);
        assertTrue(COLLATERALIZED().eq(instanceReader.getPolicyState(policyNftId)));
        vm.stopPrank();
    }

    function _createInitialBundle() internal {
        vm.startPrank(investor);
        Fee memory bundleFee = FeeLib.percentageFee(2);
        Amount investAmount = AmountLib.toAmount(10000000 * 10 ** 6);
        fireUSD.approve(
            address(firePool.getTokenHandler()), 
            investAmount.toInt());
        (bundleNftId,) = firePool.createBundle(
            bundleFee, 
            investAmount, 
            SecondsLib.toSeconds(5 * 365 * 24 * 60 * 60)); // 5 years
        vm.stopPrank();
    }
}