// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../../../lib/forge-std/src/Test.sol";

import {INftOwnable} from "../../../contracts/shared/INftOwnable.sol";
import {IPolicy} from "../../../contracts/instance/module/IPolicy.sol";

import {Amount, AmountLib} from "../../../contracts/type/Amount.sol";
import {BUNDLE} from "../../../contracts/type/ObjectType.sol";
import {COLLATERALIZED, PAID} from "../../../contracts/type/StateId.sol";
import {FlightBaseTest} from "./FlightBase.t.sol";
import {IBundle} from "../../../contracts/instance/module/IBundle.sol";
import {NftId} from "../../../contracts/type/NftId.sol";
import {SecondsLib} from "../../../contracts/type/Seconds.sol";
import {Str, StrLib} from "../../../contracts/type/String.sol";
import {Timestamp, TimestampLib} from "../../../contracts/type/Timestamp.sol";

// solhint-disable func-name-mixedcase
contract FlightProductTest is FlightBaseTest {

    // sample flight data
    Str public carrierFlightNumber = StrLib.toStr("LX180");
    Str public departureYearMonthDay = StrLib.toStr("2024-11-08");
    Timestamp public departureTime = TimestampLib.toTimestamp(1731085200);
    Timestamp public arrivalTime = TimestampLib.toTimestamp(1731166800);

    uint256[6] public statistics = [
        uint256(20), // total number of flights
        2, // number of flights late 15'
        5, // number of flights late 30'
        3, // number of flights late 45'
        1, // number of flights cancelled
        0 // number of flights diverted
    ];

    function setUp() public override {
        super.setUp();

        // set time to somewhere before devcon in bkk
        vm.warp(1726260993);

        // create and set bundle for flight product
        bundleNftId = _createInitialBundle();

        vm.prank(flightOwner);
        flightProduct.setDefaultBundle(bundleNftId);

        // approve flight product to buy policies
        vm.startPrank(customer);
        flightUSD.approve(
            address(flightProduct.getTokenHandler()), 
            flightUSD.balanceOf(customer));
        vm.stopPrank();
    }


    function test_flightProductSetup() public {
        // GIVEN - setp from flight base test

        // solhint-disable
        console.log("");
        console.log("flight product", flightProductNftId.toInt(), address(flightProduct));
        console.log("flight product wallet", flightProduct.getWallet());
        console.log("flight pool token handler", address(flightProduct.getTokenHandler()));
        console.log("flight owner", flightOwner);
        console.log("customer", customer);
        console.log("customer balance [$]", flightUSD.balanceOf(customer) / 10 ** flightUSD.decimals());
        console.log("customer allowance [$] (token handler)", flightUSD.allowance(customer, address(flightProduct.getTokenHandler())) / 10 ** flightUSD.decimals());
        console.log("");
        console.log("LX180 departure on 2024-11-08", departureTime.toInt());
        console.log("now", TimestampLib.current().toInt());
        console.log("departure time not before", departureTime.subtractSeconds(flightProduct.MAX_TIME_BEFORE_DEPARTURE()).toInt());
        console.log("departure time not after", departureTime.subtractSeconds(flightProduct.MIN_TIME_BEFORE_DEPARTURE()).toInt());
        // solhint-enable

        // THEN
        assertTrue(flightUSD.allowance(customer, address(flightProduct.getTokenHandler())) > 0, "product allowance zero");
        assertEq(registry.getNftIdForAddress(address(flightProduct)).toInt(), flightProductNftId.toInt(), "unexpected pool nft id");
        assertEq(registry.ownerOf(flightProductNftId), flightOwner, "unexpected product owner");
        assertEq(flightProduct.getWallet(), address(flightProduct.getTokenHandler()), "unexpected product wallet address");
    }


    function test_flightProductCalculateSumInsuredHappyCase() public {
        // GIVEN 
        Amount premiumAmount = AmountLib.toAmount(30 * 10 ** flightUSD.decimals());

        // WHEN
        (
            uint256 weight, 
            Amount sumInsuredAmount
        ) = flightProduct.checkAndCalculateSumInsured(premiumAmount, statistics);

        console.log("weight", weight);
        console.log("sumInsuredAmount", sumInsuredAmount.toInt() / 10 ** flightUSD.decimals(), sumInsuredAmount.toInt());
    }


    function test_flightProductCreatePolicyHappyCase() public {
        // GIVEN - setp from flight base test

        uint256 customerBalanceBefore = flightUSD.balanceOf(customer);
        uint256 poolBalanceBefore = flightUSD.balanceOf(flightPool.getWallet());
        uint256 productBalanceBefore = flightUSD.balanceOf(flightProduct.getWallet());
        Amount premiumAmount = AmountLib.toAmount(30 * 10 ** flightUSD.decimals());

        // WHEN
        (NftId policyNftId, ) = flightProduct.createPolicy(
            customer,
            carrierFlightNumber,
            departureYearMonthDay,
            departureTime,
            arrivalTime,
            premiumAmount,
            statistics);

        // THEN
        assertTrue(policyNftId.gtz(), "policy nft id zero");
        assertEq(registry.ownerOf(policyNftId), customer, "unexpected policy holder");
        assertEq(instanceReader.getPolicyState(policyNftId).toInt(), COLLATERALIZED().toInt(), "unexpected policy state");

        // check policy info
        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertEq(policyInfo.productNftId.toInt(), flightProductNftId.toInt(), "unexpected product nft id");
        assertEq(policyInfo.bundleNftId.toInt(), bundleNftId.toInt(), "unexpected bundle nft id");
        assertEq(policyInfo.activatedAt.toInt(), departureTime.toInt(), "unexpected activate at timestamp");
        assertEq(policyInfo.lifetime.toInt(), flightProduct.LIFETIME().toInt(), "unexpected lifetime");
        assertTrue(policyInfo.sumInsuredAmount > premiumAmount, "sum insured <= premium amount");

        // check premium info
        assertEq(instanceReader.getPremiumState(policyNftId).toInt(), PAID().toInt(), "unexpected premium state");
        IPolicy.PremiumInfo memory premiumInfo = instanceReader.getPremiumInfo(policyNftId);
        console.log("policyInfo.sumInsuredAmount", policyInfo.sumInsuredAmount.toInt());
        console.log("premiumAmount", premiumAmount.toInt());
        console.log("premium.premiumAmount", premiumInfo.premiumAmount.toInt());
        console.log("premium.productFeeAmount", premiumInfo.productFeeAmount.toInt());
        console.log("premium.distributionFeeAndCommissionAmount", premiumInfo.distributionFeeAndCommissionAmount.toInt());
        console.log("premium.poolPremiumAndFeeAmount", premiumInfo.poolPremiumAndFeeAmount.toInt());
        console.log("premium.discountAmount", premiumInfo.discountAmount.toInt());
        
        // check token balances
        assertEq(flightUSD.balanceOf(flightProduct.getWallet()), productBalanceBefore, "unexpected product balance");
        assertEq(flightUSD.balanceOf(flightPool.getWallet()), poolBalanceBefore + premiumAmount.toInt(), "unexpected pool balance");
        assertEq(flightUSD.balanceOf(customer), customerBalanceBefore - premiumAmount.toInt(), "unexpected customer balance");
    }
}