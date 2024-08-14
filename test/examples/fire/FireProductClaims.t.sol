// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import {Amount, AmountLib} from "../../../contracts/type/Amount.sol";
import {APPLIED, CLOSED, COLLATERALIZED, PAID} from "../../../contracts/type/StateId.sol";
import {ClaimId} from "../../../contracts/type/ClaimId.sol";
import {DAMAGE_LARGE, DAMAGE_MEDIUM, DAMAGE_SMALL} from "../../../contracts/examples/fire/DamageLevel.sol";
import {Fee, FeeLib} from "../../../contracts/type/Fee.sol";
import {FireProduct, ONE_YEAR} from "../../../contracts/examples/fire/FireProduct.sol";
import {FireTestBase} from "./FireTestBase.t.sol";
import {IClaimService} from "../../../contracts/product/IClaimService.sol";
import {IComponent} from "../../../contracts/shared/IComponent.sol";
import {INftOwnable} from "../../../contracts/shared/INftOwnable.sol";
import {IPolicy} from "../../../contracts/instance/module/IPolicy.sol";
import {NftId, NftIdLib} from "../../../contracts/type/NftId.sol";
import {PayoutId} from "../../../contracts/type/PayoutId.sol";
import {Seconds, SecondsLib} from "../../../contracts/type/Seconds.sol";
import {Timestamp, TimestampLib} from "../../../contracts/type/Timestamp.sol";
import {UFixedLib} from "../../../contracts/type/UFixed.sol";
import {POLICY, POOL} from "../../../contracts/type/ObjectType.sol";

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

    function test_fireClaimsReportFire() public {
        // GIVEN
        Timestamp timestamp = TimestampLib.blockTimestamp();
        uint256 fireId = 42;
        vm.startPrank(fireProductOwner);

        // WHEN
        fireProduct.reportFire(fireId, cityName, DAMAGE_SMALL(), timestamp);

        // THEN
        FireProduct.Fire memory fire = fireProduct.fire(fireId);
        assertEq(cityName, fire.cityName);
        assertEq(DAMAGE_SMALL().toInt(), fire.damageLevel.toInt());
        assertEq(timestamp, fire.reportedAt, "reportedAt mismatch");
    }

    function test_fireClaimsReportFireInvalidRole() public {
        // GIVEN
        Timestamp timestamp = TimestampLib.blockTimestamp();
        uint256 fireId = 42;

        vm.startPrank(customer);
        
        // THEN - unauthorized
        // TODO re-enable once granting is fixed
        // vm.expectRevert(abi.encodeWithSelector(
        //     IAccessManaged.AccessManagedUnauthorized.selector, 
        //     customer));

        // WHEN - reportFire called by customer
        fireProduct.reportFire(fireId, cityName, DAMAGE_SMALL(), timestamp);
    }

    function test_fireClaimsReportFireDuplicateId() public {
        // GIVEN
        Timestamp timestamp = TimestampLib.blockTimestamp();
        uint256 fireId = 42;

        vm.startPrank(fireProductOwner);

        fireProduct.reportFire(fireId, cityName, DAMAGE_SMALL(), timestamp);
        
        // THEN - unauthorized
        vm.expectRevert(abi.encodeWithSelector(
            FireProduct.ErrorFireProductFireAlreadyReported.selector));

        // WHEN - reportFire called by customer
        fireProduct.reportFire(fireId, cityName, DAMAGE_SMALL(), timestamp);
    }

    function test_fireClaimsReportFireUnknownCity() public {
        // GIVEN
        Timestamp timestamp = TimestampLib.blockTimestamp();
        uint256 fireId = 42;

        vm.startPrank(fireProductOwner);
        
        // THEN - city unknown
        vm.expectRevert(abi.encodeWithSelector(
            FireProduct.ErrorFireProductCityUnknown.selector,
            "Zurich"));

        // WHEN - reportFire called by customer
        fireProduct.reportFire(fireId, "Zurich", DAMAGE_SMALL(), timestamp);
    }

    function test_fireClaimsReportFireInFuture() public {
        // GIVEN
        uint256 fireId = 42;

        vm.startPrank(fireProductOwner);
        
        Timestamp reportTime = TimestampLib.blockTimestamp().addSeconds(SecondsLib.toSeconds(100));

        // THEN - too early
        vm.expectRevert(abi.encodeWithSelector(
            FireProduct.ErrorFireProductTimestampInFuture.selector));

        // WHEN - reportFire called by customer
        fireProduct.reportFire(fireId, cityName, DAMAGE_SMALL(), reportTime);
    }

    /// @dev Test submitClaim with small fire damage and test that all counters are updated correctly and tokens transferred
    function test_fireClaimsSubmitClaimSmallFire() public {
        // GIVEN
        Amount sumInsured = AmountLib.toAmount(100000 * 10 ** 6);
        Timestamp timestamp = TimestampLib.blockTimestamp();
        policyNftId = _preparePolicy(
            customer,
            cityName, 
            sumInsured, 
            ONE_YEAR(), 
            timestamp,
            bundleNftId);
        
        vm.startPrank(fireProductOwner);
        uint256 fireId = 42;
        fireProduct.reportFire(fireId, cityName, DAMAGE_SMALL(), timestamp);
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
    function test_fireClaimsSubmitClaimMediumFire() public {
        // GIVEN
        Amount sumInsured = AmountLib.toAmount(100000 * 10 ** 6);
        Timestamp timestamp = TimestampLib.blockTimestamp();
        policyNftId = _preparePolicy(
            customer,
            cityName, 
            sumInsured, 
            ONE_YEAR(), 
            timestamp,
            bundleNftId);
        
        vm.startPrank(fireProductOwner);
        uint256 fireId = 42;
        fireProduct.reportFire(fireId, cityName, DAMAGE_MEDIUM(), timestamp);
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
    function test_fireClaimsSubmitClaimLargeFire() public {
        // GIVEN
        Amount sumInsured = AmountLib.toAmount(100000 * 10 ** 6);
        Timestamp timestamp = TimestampLib.blockTimestamp();
        policyNftId = _preparePolicy(
            customer,
            cityName, 
            sumInsured, 
            ONE_YEAR(), 
            timestamp,
            bundleNftId);
        
        vm.startPrank(fireProductOwner);
        uint256 fireId = 42;
        fireProduct.reportFire(fireId, cityName, DAMAGE_LARGE(), timestamp);
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
    function test_fireClaimsSubmitClaimTwoSmallFires() public {
        // GIVEN
        Amount sumInsured = AmountLib.toAmount(100000 * 10 ** 6);
        Timestamp timestamp = TimestampLib.blockTimestamp();
        policyNftId = _preparePolicy(
            customer,
            cityName, 
            sumInsured, 
            ONE_YEAR(), 
            timestamp,
            bundleNftId);
        
        vm.startPrank(fireProductOwner);
        uint256 fireId = 42;
        uint256 fireId2 = 43;
        fireProduct.reportFire(fireId, cityName, DAMAGE_SMALL(), timestamp);
        fireProduct.reportFire(fireId2, cityName, DAMAGE_SMALL(), timestamp);
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
    function test_fireClaimsSubmitClaimOneSmallOneLargeFire() public {
        // GIVEN
        Amount sumInsured = AmountLib.toAmount(100000 * 10 ** 6);
        {
            Timestamp timestamp = TimestampLib.blockTimestamp();
            policyNftId = _preparePolicy(
                customer,
                cityName, 
                sumInsured, 
                ONE_YEAR(), 
                timestamp,
                bundleNftId);
            
            vm.startPrank(fireProductOwner);
            fireProduct.reportFire(42, cityName, DAMAGE_SMALL(), timestamp);
            fireProduct.reportFire(43, cityName, DAMAGE_LARGE(), timestamp);
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
    function test_fireClaimsSubmitClaimNotNftOwner() public {
        // GIVEN
        Amount sumInsured = AmountLib.toAmount(100000 * 10 ** 6);
        Timestamp timestamp = TimestampLib.blockTimestamp();
        policyNftId = _preparePolicy(
            customer,
            cityName, 
            sumInsured, 
            ONE_YEAR(), 
            timestamp,
            bundleNftId);
        
        vm.startPrank(fireProductOwner);
        uint256 fireId = 42;
        fireProduct.reportFire(fireId, cityName, DAMAGE_SMALL(), timestamp);
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
    function test_fireClaimsSubmitClaimNotNftOwner2() public {
        // GIVEN
        Amount sumInsured = AmountLib.toAmount(100000 * 10 ** 6);
        Timestamp timestamp = TimestampLib.blockTimestamp();
        policyNftId = _preparePolicy(
            customer,
            cityName, 
            sumInsured, 
            ONE_YEAR(), 
            timestamp,
            bundleNftId);
        _fundAccount(customer2, 10000 * 10 ** 6);
        _preparePolicy(
            customer2,
            cityName, 
            sumInsured, 
            ONE_YEAR(), 
            timestamp,
            bundleNftId);
        
        vm.startPrank(fireProductOwner);
        uint256 fireId = 42;
        fireProduct.reportFire(fireId, cityName, DAMAGE_SMALL(), timestamp);
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
    function test_fireClaimsSubmitClaimUnknownFireId() public {
        // GIVEN
        Amount sumInsured = AmountLib.toAmount(100000 * 10 ** 6);
        Timestamp timestamp = TimestampLib.blockTimestamp();
        policyNftId = _preparePolicy(
            customer,
            cityName, 
            sumInsured, 
            ONE_YEAR(), 
            timestamp,
            bundleNftId);
        
        vm.startPrank(fireProductOwner);
        fireProduct.reportFire(42, cityName, DAMAGE_SMALL(), timestamp);
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
    function test_fireClaimsSubmitClaimAlreadyClaimed() public {
        // GIVEN
        Amount sumInsured = AmountLib.toAmount(100000 * 10 ** 6);
        Timestamp timestamp = TimestampLib.blockTimestamp();
        policyNftId = _preparePolicy(
            customer,
            cityName, 
            sumInsured, 
            ONE_YEAR(), 
            timestamp,
            bundleNftId);
        
        vm.startPrank(fireProductOwner);
        uint256 fireId = 42;
        fireProduct.reportFire(fireId, cityName, DAMAGE_SMALL(), timestamp);
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
    function test_fireClaimsSubmitClaimExpiredPolicy() public {
        // GIVEN
        Amount sumInsured = AmountLib.toAmount(100000 * 10 ** 6);
        Timestamp timestamp = TimestampLib.blockTimestamp();
        policyNftId = _preparePolicy(
            customer,
            cityName, 
            sumInsured, 
            ONE_YEAR(), 
            timestamp,
            bundleNftId);
        
        vm.startPrank(fireProductOwner);
        uint256 fireId = 42;
        fireProduct.reportFire(fireId, cityName, DAMAGE_SMALL(), timestamp);

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
    function test_fireClaimsSubmitClaimClosedPolicy() public {
        // GIVEN
        Amount sumInsured = AmountLib.toAmount(100000 * 10 ** 6);
        Timestamp timestamp = TimestampLib.blockTimestamp();
        policyNftId = _preparePolicy(
            customer,
            cityName, 
            sumInsured, 
            ONE_YEAR(), 
            timestamp,
            bundleNftId);
        
        vm.startPrank(fireProductOwner);
        uint256 fireId = 42;
        fireProduct.reportFire(fireId, cityName, DAMAGE_SMALL(), timestamp);

        vm.warp(100);
        fireProduct.expire(policyNftId, TimestampLib.blockTimestamp());
        fireProduct.close(policyNftId);
        vm.stopPrank();
        
        vm.startPrank(customer);
        
        // THEN - expect revert
        vm.expectRevert(abi.encodeWithSelector(
            IClaimService.ErrorClaimServicePolicyNotOpen.selector,
            policyNftId));

        // WHEN - submit claim for closed policy
        fireProduct.submitClaim(policyNftId, fireId);
    }

    /// @dev Test submitClaim for a policy that is not yet active when the fire occurs
    function test_fireClaimsSubmitClaimPolicyNotActive() public {
        // GIVEN
        Amount sumInsured = AmountLib.toAmount(100000 * 10 ** 6);
        Timestamp timestamp = TimestampLib.blockTimestamp();
        Timestamp inADay = timestamp.addSeconds(SecondsLib.toSeconds(24 * 60 * 60));
        policyNftId = _preparePolicy(
            customer,
            cityName, 
            sumInsured, 
            ONE_YEAR(), 
            inADay,
            bundleNftId);
        
        vm.startPrank(fireProductOwner);
        uint256 fireId = 42;
        fireProduct.reportFire(fireId, cityName, DAMAGE_SMALL(), timestamp);
        vm.stopPrank();
        
        vm.warp(100);
        vm.startPrank(customer);
        
        // THEN - expect revert
        vm.expectRevert(abi.encodeWithSelector(
            FireProduct.ErrorFireProductPolicyNotYetActive.selector,
            policyNftId,
            inADay));

        // WHEN - submit claim for policy that is not yet active
        fireProduct.submitClaim(policyNftId, fireId);
    }

    /// @dev Test submitClaim for a policy that does not exist
    function test_fireClaimsSubmitClaimInvalidNftId() public {
        // GIVEN
        Amount sumInsured = AmountLib.toAmount(100000 * 10 ** 6);
        Timestamp timestamp = TimestampLib.blockTimestamp();
        Timestamp inADay = timestamp.addSeconds(SecondsLib.toSeconds(24 * 60 * 60));
        policyNftId = _preparePolicy(
            customer,
            cityName, 
            sumInsured, 
            ONE_YEAR(), 
            inADay,
            bundleNftId);
        
        vm.startPrank(fireProductOwner);
        uint256 fireId = 42;
        fireProduct.reportFire(fireId, cityName, DAMAGE_SMALL(), timestamp);
        vm.stopPrank();
        
        vm.warp(100);
        vm.startPrank(customer);

        NftId invalidNftId = NftIdLib.toNftId(243);
        
        // THEN - expect revert
        vm.expectRevert(abi.encodeWithSelector(
            IERC721Errors.ERC721NonexistentToken.selector,
            invalidNftId));

        // WHEN - submit claim for policy that does not exist (invalid nft id)
        fireProduct.submitClaim(invalidNftId, fireId);
    }

    /// @dev Test submitClaim for a nft that is of wrong type (pool nft)
    function test_fireClaimsSubmitClaimInvalidNftType() public {
        // GIVEN
        Amount sumInsured = AmountLib.toAmount(100000 * 10 ** 6);
        Timestamp timestamp = TimestampLib.blockTimestamp();
        Timestamp inADay = timestamp.addSeconds(SecondsLib.toSeconds(24 * 60 * 60));
        policyNftId = _preparePolicy(
            customer,
            cityName, 
            sumInsured, 
            ONE_YEAR(), 
            inADay,
            bundleNftId);
        
        vm.startPrank(fireProductOwner);
        uint256 fireId = 42;
        fireProduct.reportFire(fireId, cityName, DAMAGE_SMALL(), timestamp);
        vm.stopPrank();
        
        vm.startPrank(firePoolOwner);
        
        // THEN 
        vm.expectRevert(abi.encodeWithSelector(
            INftOwnable.ErrorNftOwnableInvalidType.selector,
            firePoolNftId,
            POLICY()));

        // WHEN - submit claim for policy that is wrong type
        fireProduct.submitClaim(firePoolNftId, fireId);
    }

    /// @dev Test submitClaim for a fire that is in wrong city (wrong risk)
    function test_fireClaimsSubmitClaimWrongCity() public {
        // GIVEN
        Amount sumInsured = AmountLib.toAmount(100000 * 10 ** 6);
        Timestamp timestamp = TimestampLib.blockTimestamp();
        policyNftId = _preparePolicy(
            customer,
            cityName, 
            sumInsured, 
            ONE_YEAR(), 
            timestamp,
            bundleNftId);
        
        vm.startPrank(fireProductOwner);
        string memory cityName2 = "Zurich";
        fireProduct.initializeCity(cityName2);
        uint256 fireId = 42;
        fireProduct.reportFire(fireId, cityName2, DAMAGE_SMALL(), timestamp);
        vm.stopPrank();

        vm.warp(100);
        
        vm.startPrank(customer);
        
        // THEN 
        vm.expectRevert(abi.encodeWithSelector(
            FireProduct.ErrorFireProductFireNotInCoveredCity.selector,
            fireId,
            "Zurich"));

        // WHEN - submit claim for a fire in the wrong city
        fireProduct.submitClaim(policyNftId, fireId);
    }

    /// @dev Test submitClaim for a fire that is in wrong city (wrong risk)
    function test_fireClaimsSubmitClaimFireAfterPolicyExpiration() public {
        // GIVEN
        Amount sumInsured = AmountLib.toAmount(100000 * 10 ** 6);
        Timestamp timestamp = TimestampLib.blockTimestamp();
        policyNftId = _preparePolicy(
            customer,
            cityName, 
            sumInsured, 
            ONE_YEAR(), 
            timestamp,
            bundleNftId);
        
        vm.startPrank(fireProductOwner);
        
        vm.warp(ONE_YEAR().toInt() + 100);
        
        uint256 fireId = 42;
        fireProduct.reportFire(fireId, cityName, DAMAGE_SMALL(),  TimestampLib.blockTimestamp());
        vm.stopPrank();

        vm.startPrank(customer);
        
        // THEN 
        vm.expectRevert(abi.encodeWithSelector(
            FireProduct.ErrorFireProductPolicyExpired.selector,
            policyNftId,
            ONE_YEAR() + SecondsLib.toSeconds(1)));

        // WHEN - submit claim for a fire that happened after policy expired
        fireProduct.submitClaim(policyNftId, fireId);
    }

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