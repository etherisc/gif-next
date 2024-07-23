// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {Amount, AmountLib} from "../../../contracts/type/Amount.sol";
import {APPLIED, CLOSED, COLLATERALIZED, DECLINED, PAID} from "../../../contracts/type/StateId.sol";
import {DAMAGE_SMALL} from "../../../contracts/examples/fire/DamageLevel.sol";
import {Fee, FeeLib} from "../../../contracts/type/Fee.sol";
import {FireProduct, ONE_YEAR} from "../../../contracts/examples/fire/FireProduct.sol";
import {FireTestBase} from "./FireTestBase.t.sol";
import {IPolicy} from "../../../contracts/instance/module/IPolicy.sol";
import {NftId} from "../../../contracts/type/NftId.sol";
import {Seconds, SecondsLib} from "../../../contracts/type/Seconds.sol";
import {Timestamp, TimestampLib} from "../../../contracts/type/Timestamp.sol";

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
        // TODO: for later
        // Amount sumInsured = AmountLib.toAmount(100000 * 10 ** 6);
        // policyNftId = _preparePolicy(
        //     cityName, 
        //     sumInsured, 
        //     ONE_YEAR(), 
        //     now,
        //     bundleNftId);
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

    function _preparePolicy(
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
        vm.startPrank(customer);
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