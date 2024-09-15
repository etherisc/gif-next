// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../../../lib/forge-std/src/Test.sol";

import {INftOwnable} from "../../../contracts/shared/INftOwnable.sol";
import {IOracle} from "../../../contracts/oracle/IOracle.sol";
import {IPolicy} from "../../../contracts/instance/module/IPolicy.sol";

import {Amount, AmountLib} from "../../../contracts/type/Amount.sol";
import {BUNDLE} from "../../../contracts/type/ObjectType.sol";
import {COLLATERALIZED, PAID} from "../../../contracts/type/StateId.sol";
import {FlightBaseTest} from "./FlightBase.t.sol";
import {FlightProduct} from "../../../contracts/examples/flight/FlightProduct.sol";
import {IBundle} from "../../../contracts/instance/module/IBundle.sol";
import {NftId} from "../../../contracts/type/NftId.sol";
import {RiskId} from "../../../contracts/type/RiskId.sol";
import {RequestId, RequestIdLib} from "../../../contracts/type/RequestId.sol";
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
            Amount[5] memory payoutAmounts,
            Amount sumInsuredAmount // simply the max of payoutAmounts 
        ) = flightProduct.calculatePayoutAmounts(premiumAmount, statistics);

        console.log("weight", weight);
        console.log("sumInsuredAmount", sumInsuredAmount.toInt() / 10 ** flightUSD.decimals(), sumInsuredAmount.toInt());
    }


    function test_flightProductCreatePolicyHappyCase() public {
        // GIVEN - setp from flight base test

        uint256 customerBalanceBefore = flightUSD.balanceOf(customer);
        uint256 poolBalanceBefore = flightUSD.balanceOf(flightPool.getWallet());
        uint256 productBalanceBefore = flightUSD.balanceOf(flightProduct.getWallet());
        Amount premiumAmount = AmountLib.toAmount(30 * 10 ** flightUSD.decimals());

        assertEq(instanceReader.risks(flightProductNftId), 0, "unexpected number of risks (before)");
        assertEq(instanceReader.activeRisks(flightProductNftId), 0, "unexpected number of active risks (before)");
        assertEq(flightOracle.activeRequests(), 0, "unexpected number of active requests (before)");

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
        // check risks
        assertEq(instanceReader.risks(flightProductNftId), 1, "unexpected number of risks (after)");
        assertEq(instanceReader.activeRisks(flightProductNftId), 1, "unexpected number of active risks (after)");

        RiskId riskId = instanceReader.getRiskId(flightProductNftId, 0);
        (bool exists, FlightProduct.FlightRisk memory flightRisk) = flightProduct.getFlightRisk(riskId);
        _printRisk(riskId, flightRisk);

        assertTrue(exists, "risk does not exist");
        assertEq(instanceReader.policiesForRisk(riskId), 1, "unexpected number of policies for risk");
        assertEq(instanceReader.getPolicyForRisk(riskId, 0).toInt(), policyNftId.toInt(), "unexpected 1st policy for risk");

        // check policy
        assertTrue(policyNftId.gtz(), "policy nft id zero");
        assertEq(registry.ownerOf(policyNftId), customer, "unexpected policy holder");
        assertEq(instanceReader.getPolicyState(policyNftId).toInt(), COLLATERALIZED().toInt(), "unexpected policy state");

        // check policy info
        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
        _printPolicy(policyNftId, policyInfo);

        // check policy data
        assertTrue(instanceReader.isProductRisk(flightProductNftId, policyInfo.riskId), "risk does not exist for product");
        assertEq(policyInfo.productNftId.toInt(), flightProductNftId.toInt(), "unexpected product nft id");
        assertEq(policyInfo.bundleNftId.toInt(), bundleNftId.toInt(), "unexpected bundle nft id");
        assertEq(policyInfo.activatedAt.toInt(), departureTime.toInt(), "unexpected activate at timestamp");
        assertEq(policyInfo.lifetime.toInt(), flightProduct.LIFETIME().toInt(), "unexpected lifetime");
        assertTrue(policyInfo.sumInsuredAmount > premiumAmount, "sum insured <= premium amount");

        // check premium info
        IPolicy.PremiumInfo memory premiumInfo = instanceReader.getPremiumInfo(policyNftId);
        _printPremium(policyNftId, premiumInfo);
        assertEq(instanceReader.getPremiumState(policyNftId).toInt(), PAID().toInt(), "unexpected premium state");
        
        // check token balances
        assertEq(flightUSD.balanceOf(flightProduct.getWallet()), productBalanceBefore, "unexpected product balance");
        assertEq(flightUSD.balanceOf(flightPool.getWallet()), poolBalanceBefore + premiumAmount.toInt(), "unexpected pool balance");
        assertEq(flightUSD.balanceOf(customer), customerBalanceBefore - premiumAmount.toInt(), "unexpected customer balance");

        // check oracle request
        assertEq(flightOracle.activeRequests(), 1, "unexpected number of active requests (after policy creation)");

        RequestId requestId = flightOracle.getActiveRequest(0);
        assertTrue(requestId.gtz(), "request id zero");

        IOracle.RequestInfo memory requestInfo = instanceReader.getRequestInfo(requestId);
        _printRequest(requestId, requestInfo);
    }


    function test_flightCreatePolicyAndProcessFlightStatus() public {

        // GIVEN - create policy
        Amount premiumAmount = AmountLib.toAmount(30 * 10 ** flightUSD.decimals());
        (NftId policyNftId, ) = flightProduct.createPolicy(
            customer,
            carrierFlightNumber,
            departureYearMonthDay,
            departureTime,
            arrivalTime,
            premiumAmount,
            statistics);

        RequestId requestId = RequestIdLib.toRequestId(123);
        RiskId riskId = instanceReader.getPolicyInfo(policyNftId).riskId;

        // WHEN
        // set cheking time 2h after scheduled arrival time
        vm.warp(arrivalTime.toInt() + 2 * 3600);

        // push flight status (90 min late) to product
        bytes1 status = "L";
        int256 delay = 90; // TODO check why 40' delay seems to have 0 payout
        uint8 maxPoliciesToProcess = 1;

        flightProduct.flightStatusCallback(
            requestId, riskId, status, delay, maxPoliciesToProcess);

        _printPolicy(
            policyNftId, 
            instanceReader.getPolicyInfo(policyNftId));
    }


    function test_flightStatusPayoutOptions() public {
        // GIVEN
        RequestId rqId = RequestIdLib.toRequestId(1);
        RiskId rkId = flightProduct.getRiskId(
            carrierFlightNumber,
            departureTime,
            arrivalTime);

        // solhint-disable
        console.log("X 42", flightProduct.checkAndGetPayoutOption(rqId, rkId, "X", 42));
        console.log("A 0", flightProduct.checkAndGetPayoutOption(rqId, rkId, "A", 0));
        console.log("L -5", flightProduct.checkAndGetPayoutOption(rqId, rkId, "L", -5));
        console.log("L 10", flightProduct.checkAndGetPayoutOption(rqId, rkId, "L", 10));
        console.log("L 15", flightProduct.checkAndGetPayoutOption(rqId, rkId, "L", 15));
        console.log("L 30", flightProduct.checkAndGetPayoutOption(rqId, rkId, "L", 30));
        console.log("L 44", flightProduct.checkAndGetPayoutOption(rqId, rkId, "L", 44));
        console.log("L 45", flightProduct.checkAndGetPayoutOption(rqId, rkId, "L", 45));
        console.log("L 201", flightProduct.checkAndGetPayoutOption(rqId, rkId, "L", 201));
        console.log("C 0", flightProduct.checkAndGetPayoutOption(rqId, rkId, "C", 0));
        console.log("D 0", flightProduct.checkAndGetPayoutOption(rqId, rkId, "D", 0));
        // solhint-enable

        assertEq(flightProduct.checkAndGetPayoutOption(rqId, rkId, "X", 42), 255, "not 255 (no payout X)");
        assertEq(flightProduct.checkAndGetPayoutOption(rqId, rkId, "A", 0), 255, "not 255 (no payout A)");
        assertEq(flightProduct.checkAndGetPayoutOption(rqId, rkId, "L", -5), 255, "not 255 (L -5)");
        assertEq(flightProduct.checkAndGetPayoutOption(rqId, rkId, "L", 10), 255, "not 255 (L 10)");
        assertEq(flightProduct.checkAndGetPayoutOption(rqId, rkId, "L", 15), 0, "not 0 (L 15)");
        assertEq(flightProduct.checkAndGetPayoutOption(rqId, rkId, "L", 30), 1, "not 1 (L 30)");
        assertEq(flightProduct.checkAndGetPayoutOption(rqId, rkId, "L", 44), 1, "not 1 (L 44)");
        assertEq(flightProduct.checkAndGetPayoutOption(rqId, rkId, "L", 45), 2, "not 2 (L 45)");
        assertEq(flightProduct.checkAndGetPayoutOption(rqId, rkId, "L", 201), 2, "not 0 (L 201)");
        assertEq(flightProduct.checkAndGetPayoutOption(rqId, rkId, "C", 0), 3, "not 3 (cancelled)");
        assertEq(flightProduct.checkAndGetPayoutOption(rqId, rkId, "D", 0), 4, "not 4 (diverted)");
    }
}