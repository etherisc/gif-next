// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {Amount, AmountLib} from "../../../contracts/type/Amount.sol";
import {APPLIED, CLOSED, COLLATERALIZED, DECLINED, PAID} from "../../../contracts/type/StateId.sol";
import {ClaimId} from "../../../contracts/type/ClaimId.sol";
import {DAMAGE_SMALL} from "../../../contracts/examples/fire/DamageLevel.sol";
import {Fee, FeeLib} from "../../../contracts/type/Fee.sol";
import {FireProduct, ONE_YEAR} from "../../../contracts/examples/fire/FireProduct.sol";
import {FireTestBase} from "./FireTestBase.t.sol";
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

    function test_FireProductClaims_submitClaim() public {
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

    // TODO: test submit claim with MEDIUM damage
    // TODO: test submit claim with LARGE damage
    // TODO: test submit with two fires
    // TODO: test submit with two fires, first small, second large
    // TODO: test submitClaim with not nft owner
    // TODO: test submitClaim with invalid fire id
    // TODO: test submitClaim but already claimed
    // TODO: test submitClaim but policy closed
    // TODO: test submitClaim but not active yet
    // TODO: test submitClaim but already expired

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