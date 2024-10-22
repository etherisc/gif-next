// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../../../lib/forge-std/src/Test.sol";

import {IAccess} from "../../../contracts/authorization/IAccess.sol";
import {INftOwnable} from "../../../contracts/shared/INftOwnable.sol";
import {IOracle} from "../../../contracts/oracle/IOracle.sol";
import {IPolicy} from "../../../contracts/instance/module/IPolicy.sol";

import {Amount, AmountLib} from "../../../contracts/type/Amount.sol";
import {BUNDLE} from "../../../contracts/type/ObjectType.sol";
import {COLLATERALIZED, PAID} from "../../../contracts/type/StateId.sol";
import {FlightBaseTest} from "./FlightBase.t.sol";
import {FlightLib} from "../../../contracts/examples/flight/FlightLib.sol";
import {FlightNft} from "../../../contracts/examples/flight/FlightNft.sol";
import {FlightProduct} from "../../../contracts/examples/flight/FlightProduct.sol";
import {FlightOracle} from "../../../contracts/examples/flight/FlightOracle.sol";
import {IBundle} from "../../../contracts/instance/module/IBundle.sol";
import {NftId} from "../../../contracts/type/NftId.sol";
import {RiskId} from "../../../contracts/type/RiskId.sol";
import {RequestId, RequestIdLib} from "../../../contracts/type/RequestId.sol";
import {RoleId} from "../../../contracts/type/RoleId.sol";
import {Seconds, SecondsLib} from "../../../contracts/type/Seconds.sol";
import {StateId, ACTIVE, FAILED, FULFILLED} from "../../../contracts/type/StateId.sol";
import {Str, StrLib} from "../../../contracts/type/String.sol";
import {Timestamp, TimestampLib} from "../../../contracts/type/Timestamp.sol";

// solhint-disable func-name-mixedcase
contract FlightProductTest is FlightBaseTest {

    // sample flight data
    string public flightData = "LX 180 ZRH BKK 20241108";
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
    }


    function approveProductTokenHandler() public {
        // approve flight product to buy policies
        vm.startPrank(customer);
        flightUSD.approve(
            address(flightProduct.getTokenHandler()), 
            flightUSD.balanceOf(customer));
        vm.stopPrank();
    }


    function test_flightProductSetup() public {
        // GIVEN - setp from flight base test
        approveProductTokenHandler();
        
        _printAuthz(instance.getInstanceAdmin(), "instance");

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


    function test_flightProductSetTestMode() public {
        // GIVEN - setup from flight base test

        assertFalse(flightProduct.isTestMode(), "test mode already set");

        (RoleId publicRoleId, ) = instanceReader.getRoleForName("PublicRole");
        IAccess.FunctionInfo memory setTestModeFunction = instanceReader.toFunction(
            FlightProduct.setTestMode.selector, 
            "setTestMode");

        IAccess.FunctionInfo[] memory functions = new IAccess.FunctionInfo[](1);
        functions[0] = setTestModeFunction;

        vm.prank(instanceOwner);
        instance.authorizeFunctions(address(flightProduct), publicRoleId, functions);

        console.log("setTestMode selector");
        console.logBytes4(FlightProduct.setTestMode.selector);

        // WHEN
        vm.prank(flightOwner);
        flightProduct.setTestMode(true);

        // THEN
        assertTrue(flightProduct.isTestMode(), "test mode not set");

        // assertTrue(false, "oops");
    }


    function test_flightProductCreatePolicyTestModeFlightSevenDayAgo() public {
        // GIVEN - setup from flight base test

        vm.prank(flightOwner);
        flightProduct.setTestMode(true);

        assertTrue(flightProduct.isTestMode(), "test mode already set");

        Amount premiumAmount = flightProduct.MAX_PREMIUM(); // AmountLib.toAmount(30 * 10 ** flightUSD.decimals());
        (FlightProduct.PermitData memory permit) = _createPermitWithSignature(
            customer, 
            premiumAmount, 
            customerPrivateKey, 
            0); // nonce

        // WHEN
        Timestamp departureTimeModified = TimestampLib.toTimestamp(block.timestamp - 7 * 24 * 3600);
        Timestamp arrivalTimeModified = departureTimeModified.addSeconds(
            SecondsLib.toSeconds(5 * 3600)); // 5h flight

        Timestamp currentTime = TimestampLib.current();
        Seconds minTimeBeforeDeparture = flightProduct.MIN_TIME_BEFORE_DEPARTURE();

        vm.startPrank(statisticsProvider);
        NftId policyNftId = _createPolicySimple(
            flightData, 
            departureTimeModified, 
            arrivalTimeModified, 
            statistics,
            permit);
        vm.stopPrank();

        // THEN
        assertTrue(policyNftId.gtz(), "policy nft id zero");
    }


    function test_flightProductCreatePolicyTestModeFlightInOneHour() public {
        // GIVEN - setup from flight base test

        vm.prank(flightOwner);
        flightProduct.setTestMode(true);

        assertTrue(flightProduct.isTestMode(), "test mode already set");

        Amount premiumAmount = flightProduct.MAX_PREMIUM(); // AmountLib.toAmount(30 * 10 ** flightUSD.decimals());
        (FlightProduct.PermitData memory permit) = _createPermitWithSignature(
            customer, 
            premiumAmount, 
            customerPrivateKey, 
            0); // nonce

        // WHEN
        Timestamp departureTimeModified = TimestampLib.current().addSeconds(
            SecondsLib.toSeconds(3600));
        Timestamp arrivalTimeModified = departureTimeModified.addSeconds(
            SecondsLib.toSeconds(5 * 3600)); // 5h flight

        Timestamp currentTime = TimestampLib.current();
        Seconds minTimeBeforeDeparture = flightProduct.MIN_TIME_BEFORE_DEPARTURE();

        vm.startPrank(statisticsProvider);
        NftId policyNftId = _createPolicySimple(
            flightData, 
            departureTimeModified, 
            arrivalTimeModified, 
            statistics,
            permit);
        vm.stopPrank();

        // THEN
        assertTrue(policyNftId.gtz(), "policy nft id zero");
    }


    function test_flightProductCreatePolicyTestModeFlightInOneYear() public {
        // GIVEN - setup from flight base test

        vm.prank(flightOwner);
        flightProduct.setTestMode(true);

        assertTrue(flightProduct.isTestMode(), "test mode already set");

        Amount premiumAmount = flightProduct.MAX_PREMIUM(); // AmountLib.toAmount(30 * 10 ** flightUSD.decimals());
        (FlightProduct.PermitData memory permit) = _createPermitWithSignature(
            customer, 
            premiumAmount, 
            customerPrivateKey, 
            0); // nonce

        // WHEN
        Timestamp departureTimeModified = TimestampLib.current().addSeconds(
            SecondsLib.toSeconds(365 * 24 * 3600));
        Timestamp arrivalTimeModified = departureTimeModified.addSeconds(
            SecondsLib.toSeconds(5 * 3600)); // 5h flight

        Timestamp currentTime = TimestampLib.current();
        Seconds minTimeBeforeDeparture = flightProduct.MIN_TIME_BEFORE_DEPARTURE();

        vm.startPrank(statisticsProvider);
        NftId policyNftId = _createPolicySimple(
            flightData, 
            departureTimeModified, 
            arrivalTimeModified, 
            statistics,
            permit);
        vm.stopPrank();

        // THEN
        assertTrue(policyNftId.gtz(), "policy nft id zero");
    }


    function test_flightProductCreateAndTriggerPolicyTestModeFlightSevenDaysAgo() public {
        // GIVEN - setup from flight base test

        vm.prank(flightOwner);
        flightProduct.setTestMode(true);

        assertTrue(flightProduct.isTestMode(), "test mode already set");

        Amount premiumAmount = flightProduct.MAX_PREMIUM(); // AmountLib.toAmount(30 * 10 ** flightUSD.decimals());
        (FlightProduct.PermitData memory permit) = _createPermitWithSignature(
            customer, 
            premiumAmount, 
            customerPrivateKey, 
            0); // nonce

        // WHEN
        Timestamp departureTimeModified = TimestampLib.toTimestamp(block.timestamp - 7 * 24 * 3600);
        Timestamp arrivalTimeModified = departureTimeModified.addSeconds(
            SecondsLib.toSeconds(5 * 3600)); // 5h flight

        Timestamp currentTime = TimestampLib.current();
        Seconds minTimeBeforeDeparture = flightProduct.MIN_TIME_BEFORE_DEPARTURE();

        vm.startPrank(statisticsProvider);
        NftId policyNftId = _createPolicySimple(
            flightData, 
            departureTimeModified, 
            arrivalTimeModified, 
            statistics,
            permit);
        vm.stopPrank();

        // THEN
        assertTrue(policyNftId.gtz(), "policy nft id zero");
        assertEq(flightOracle.activeRequests(), 1, "unexpected number of active requests (before status callback)");
        RequestId requestId = flightOracle.getActiveRequest(0);
        assertEq(requestId.toInt(), 1, "unexpected request id");

        // WHEN
        bytes1 status = "L";
        int256 delayMinutes = 16;
        vm.startPrank(statusProvider);
        flightOracle.respondWithFlightStatus(requestId, status, delayMinutes);
    }


    function test_flightNftHappyCase() public {
        // GIVEN - setp from flight base test

        // deploy flight nft
        FlightNft flightNft = new FlightNft(
            address(flightProduct),
            "FDPLCY",
            "Flight Delay Policy",
            "https://flightdelay.integration.etherisc.com/api/nft/");

        // create policy
        approveProductTokenHandler();
        Amount premiumAmount = flightProduct.MAX_PREMIUM(); // AmountLib.toAmount(30 * 10 ** flightUSD.decimals());

        (FlightProduct.PermitData memory permit) = _createPermitWithSignature(
            customer, 
            premiumAmount, 
            customerPrivateKey, 
            0); // nonce

        // WHEN
        vm.startPrank(statisticsProvider);
        NftId policyNftId = _createPolicy(
            flightData, 
            departureTime, 
            "2024-11-08 Europe/Zurich", 
            arrivalTime, 
            "2024-11-08 Asia/Bangkok", 
            statistics,
            permit);
        vm.stopPrank();

        // solhint-disable
        console.log("token uri", flightNft.tokenURI(policyNftId.toInt()));
        console.log("token meatadata", flightNft.getMetadataJson(policyNftId.toInt()));
        // solhint-enable
    }


    function test_flightProductCreatePolicyWithPermitHappyCase() public {
        // GIVEN - setp from flight base test
        approveProductTokenHandler();

        uint256 customerBalanceBefore = flightUSD.balanceOf(customer);
        uint256 poolBalanceBefore = flightUSD.balanceOf(flightPool.getWallet());
        uint256 productBalanceBefore = flightUSD.balanceOf(flightProduct.getWallet());
        Amount premiumAmount = flightProduct.MAX_PREMIUM(); // AmountLib.toAmount(30 * 10 ** flightUSD.decimals());

        assertEq(instanceReader.risks(flightProductNftId), 0, "unexpected number of risks (before)");
        assertEq(instanceReader.activeRisks(flightProductNftId), 0, "unexpected number of active risks (before)");
        assertEq(flightOracle.activeRequests(), 0, "unexpected number of active requests (before)");

        // solhint-disable
        console.log("ts", block.timestamp);
        // solhint-enable

        (FlightProduct.PermitData memory permit) = _createPermitWithSignature(
            customer, 
            premiumAmount, 
            customerPrivateKey, 
            0); // nonce

        // WHEN
        vm.startPrank(statisticsProvider);
        NftId policyNftId = _createPolicy(
            flightData, 
            departureTime, 
            "2024-11-08 Europe/Zurich", 
            arrivalTime, 
            "2024-11-08 Asia/Bangkok", 
            statistics,
            permit);
        vm.stopPrank();

        // THEN
        {
            // check risks
            assertEq(instanceReader.risks(flightProductNftId), 1, "unexpected number of risks (after)");
            assertEq(instanceReader.activeRisks(flightProductNftId), 1, "unexpected number of active risks (after)");

            RiskId riskId = instanceReader.getRiskId(flightProductNftId, 0);
            (bool exists, FlightProduct.FlightRisk memory flightRisk) = FlightLib.getFlightRisk(instanceReader, flightProductNftId, riskId, false);
            _printRisk(riskId, flightRisk);

            // assertTrue(false, "oops");

            assertTrue(exists, "risk does not exist");
            assertEq(instanceReader.policiesForRisk(riskId), 1, "unexpected number of policies for risk");
            assertEq(instanceReader.getPolicyForRisk(riskId, 0).toInt(), policyNftId.toInt(), "unexpected 1st policy for risk");
        

            // check policy
            assertTrue(policyNftId.gtz(), "policy nft id zero");
            assertEq(registry.ownerOf(policyNftId), customer, "unexpected policy holder");
            assertEq(instanceReader.getPolicyState(policyNftId).toInt(), COLLATERALIZED().toInt(), "unexpected policy state");

            // check policy info
            {
                IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
                _printPolicy(policyNftId, policyInfo);

                // check policy data
                assertTrue(instanceReader.isProductRisk(flightProductNftId, policyInfo.riskId), "risk does not exist for product");
                assertEq(policyInfo.productNftId.toInt(), flightProductNftId.toInt(), "unexpected product nft id");
                assertEq(policyInfo.bundleNftId.toInt(), bundleNftId.toInt(), "unexpected bundle nft id");
                assertEq(policyInfo.activatedAt.toInt(), departureTime.toInt(), "unexpected activate at timestamp");
                assertEq(policyInfo.lifetime.toInt(), flightProduct.LIFETIME().toInt(), "unexpected lifetime");
                assertTrue(policyInfo.sumInsuredAmount > premiumAmount, "sum insured <= premium amount");
            }

            {
                // check premium info
                IPolicy.PremiumInfo memory premiumInfo = instanceReader.getPremiumInfo(policyNftId);
                _printPremium(policyNftId, premiumInfo);
                assertEq(instanceReader.getPremiumState(policyNftId).toInt(), PAID().toInt(), "unexpected premium state");
            }
            
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

            FlightOracle.FlightStatusRequest memory statusRequest = abi.decode(requestInfo.requestData, (FlightOracle.FlightStatusRequest));
            _printStatusRequest(statusRequest);

            assertEq(statusRequest.riskId.toInt(), riskId.toInt(), "unexpected risk id");
            assertTrue(statusRequest.flightData == StrLib.toStr(flightData), "unexpected flight data");
            assertEq(statusRequest.departureTime.toInt(), departureTime.toInt(), "unexpected departure time");
        }
    }


    function test_flightProductCreatePolicyAndCheckRequest() public {
        // GIVEN - setp from flight base test
        approveProductTokenHandler();

        uint256 customerBalanceBefore = flightUSD.balanceOf(customer);
        uint256 poolBalanceBefore = flightUSD.balanceOf(flightPool.getWallet());
        uint256 productBalanceBefore = flightUSD.balanceOf(flightProduct.getWallet());
        Amount premiumAmount = flightProduct.MAX_PREMIUM(); // AmountLib.toAmount(30 * 10 ** flightUSD.decimals());

        assertEq(instanceReader.risks(flightProductNftId), 0, "unexpected number of risks (before)");
        assertEq(instanceReader.activeRisks(flightProductNftId), 0, "unexpected number of active risks (before)");
        assertEq(flightOracle.activeRequests(), 0, "unexpected number of active requests (before)");

        // solhint-disable
        console.log("ts", block.timestamp);
        // solhint-enable

        // add payout token (externally managed pool does not intitially need to be filled with tokens)
        _transferTokenToPoolWallet(1000 *  10 ** flightUSD.decimals(), true);

        (FlightProduct.PermitData memory permit) = _createPermitWithSignature(
            customer, 
            premiumAmount, 
            customerPrivateKey, 
            0); // nonce

        // WHEN
        vm.startPrank(statisticsProvider);
        NftId policyNftId = _createPolicy(
            flightData, 
            departureTime, 
            "2024-11-08 Europe/Zurich", 
            arrivalTime, 
            "2024-11-08 Asia/Bangkok", 
            statistics,
            permit);
        vm.stopPrank();

        // THEN
        RequestId requestId = flightOracle.getActiveRequest(0);
        (
            RiskId riskId,
            string memory flightData,
            StateId requestState,
            bool readyForResponse,
            bool waitingForResend
        ) = flightOracle.getRequestState(requestId);

        // solhint-disable
        console.log("--- after policy creation (before departure) ---");
        console.log("request id", requestId.toInt(), "risk id");
        console.logBytes8(RiskId.unwrap(riskId));
        console.log("flight data", flightData, "request state", requestState.toInt());
        // console.log("request state", requestState.toInt());
        console.log("readyForResponse, waitingForResend", readyForResponse, waitingForResend);
        // solhint-enable

        assertEq(requestState.toInt(), ACTIVE().toInt(), "unexpected request state (not active)");
        assertFalse(readyForResponse, "ready for response (1)");
        assertFalse(waitingForResend, "waiting for resend (1)");

        // WHEN wait until after scheduled departure
        vm.warp(departureTime.toInt() + 1);

        // THEN
        (
            riskId,
            flightData,
            requestState,
            readyForResponse,
            waitingForResend
        ) = flightOracle.getRequestState(requestId);

        assertTrue(readyForResponse, "ready for response (2)");
        assertFalse(waitingForResend, "waiting for resend (2)");

        // WHEN send flight cancelled using insufficient gas
        bytes1 status = "C";
        int256 delay = 0; 
        uint8 maxPoliciesToProcess = 1;
        // gas amount experimentally determined to make the tx run out of gas while inside product callback
        // this results in an updated request but in a failed callback
        uint256 insufficientGas = 1300000;

        vm.startPrank(statusProvider);
        flightOracle.respondWithFlightStatus{gas:insufficientGas}(requestId, status, delay);
        vm.stopPrank();

        // THEN
        (
            riskId,
            flightData,
            requestState,
            readyForResponse,
            waitingForResend
        ) = flightOracle.getRequestState(requestId);

        // solhint-disable
        console.log("--- after response with insufficient gas ---");
        console.log("request id", requestId.toInt(), "risk id");
        console.logBytes8(RiskId.unwrap(riskId));
        console.log("flight data", flightData, "request state", requestState.toInt());
        // console.log("request state", requestState.toInt());
        console.log("readyForResponse, waitingForResend", readyForResponse, waitingForResend);
        // solhint-enable

        assertEq(requestState.toInt(), FAILED().toInt(), "unexpected request state (not failed)");
        assertFalse(readyForResponse, "ready for response (3)");
        assertTrue(waitingForResend, "waiting for resend (3)");

        // WHEN resend request (with sufficient gas)
        vm.startPrank(flightOwner);
        flightProduct.resendRequest(requestId);
        vm.stopPrank();

        // THEN
        (
            riskId,
            flightData,
            requestState,
            readyForResponse,
            waitingForResend
        ) = flightOracle.getRequestState(requestId);

        // solhint-disable
        console.log("--- after resend ---");
        console.log("request id", requestId.toInt(), "risk id");
        console.logBytes8(RiskId.unwrap(riskId));
        console.log("flight data", flightData, "request state", requestState.toInt());
        // console.log("request state", requestState.toInt());
        console.log("readyForResponse, waitingForResend", readyForResponse, waitingForResend);
        // solhint-enable

        assertEq(requestState.toInt(), FULFILLED().toInt(), "unexpected request state (not failed)");
        assertFalse(readyForResponse, "ready for response (4)");
        assertFalse(waitingForResend, "waiting for resend (4)");
    }


    function test_flightCreatePolicyAndProcessFlightStatusWithPayoutHappyCase() public {
        // GIVEN - create policy
        approveProductTokenHandler();

        // add payout token (externally managed pool does not intitially need to be filled with tokens)
        _transferTokenToPoolWallet(1000 *  10 ** flightUSD.decimals(), true);

        Amount premiumAmount = flightProduct.MAX_PREMIUM(); // AmountLib.toAmount(30 * 10 ** flightUSD.decimals());

        (FlightProduct.PermitData memory permit) = _createPermitWithSignature(
            customer, 
            premiumAmount, 
            customerPrivateKey, 
            0); // nonce

        // WHEN
        vm.startPrank(statisticsProvider);
        NftId policyNftId = _createPolicy(
            flightData, 
            departureTime, 
            "2024-11-08 Europe/Zurich", 
            arrivalTime, 
            "2024-11-08 Asia/Bangkok", 
            statistics,
            permit);
        vm.stopPrank();

        assertEq(flightOracle.activeRequests(), 1, "unexpected number of active requests (before status callback)");
        RequestId requestId = flightOracle.getActiveRequest(0);
        assertTrue(requestId.gtz(), "request id zero");

        // create flight status data (90 min late)
        bytes1 status = "L";
        int256 delay = 90; 
        uint8 maxPoliciesToProcess = 1;

        // print request before allback
        IOracle.RequestInfo memory requestInfo = instanceReader.getRequestInfo(requestId);
        _printRequest(requestId, requestInfo);

        // WHEN
        // set cheking time 2h after scheduled arrival time
        vm.warp(arrivalTime.toInt() + 2 * 3600);

        vm.startPrank(statusProvider);
        flightOracle.respondWithFlightStatus(requestId, status, delay);
        vm.stopPrank();

        assertEq(instanceReader.getRequestState(requestId).toInt(), FULFILLED().toInt(), "request state not FULFILLED after callback");

        // THEN
        requestInfo = instanceReader.getRequestInfo(requestId);
        _printRequest(requestId, requestInfo);

        assertEq(flightOracle.activeRequests(), 0, "unexpected number of active requests (after status callback)");

        _printPolicy(
            policyNftId, 
            instanceReader.getPolicyInfo(policyNftId));
        
        // assertTrue(false, "oops");
    }


    function test_flightCreateThreePoliciesWithSingleRiskAndProcessFlightStatusWithPayout() public {
        // GIVEN - create policy
        approveProductTokenHandler();

        Amount premiumAmount = flightProduct.MAX_PREMIUM(); // AmountLib.toAmount(30 * 10 ** flightUSD.decimals());

        // add payout token (externally managed pool does not intitially need to be filled with tokens)
        _transferTokenToPoolWallet(5000 *  10 ** flightUSD.decimals(), true);

        // WHEN

        // 1st policy
        (FlightProduct.PermitData memory permit1) = _createPermitWithSignature(
            customer, 
            premiumAmount, 
            customerPrivateKey, 
            0); // nonce

        vm.startPrank(statisticsProvider);
        NftId policyNftId1 = _createPolicy(
            flightData, 
            departureTime, 
            "2024-11-08 Europe/Zurich", 
            arrivalTime, 
            "2024-11-08 Asia/Bangkok", 
            statistics,
            permit1);
        vm.stopPrank();

        // 2nd policy
        (FlightProduct.PermitData memory permit2) = _createPermitWithSignature(
            customer, 
            premiumAmount, 
            customerPrivateKey, 
            1); // nonce

        vm.startPrank(statisticsProvider);
        NftId policyNftId2 = _createPolicy(
            flightData, 
            departureTime, 
            "2024-11-08 Europe/Zurich", 
            arrivalTime, 
            "2024-11-08 Asia/Bangkok", 
            statistics,
            permit2);
        vm.stopPrank();

        // 3rd policy
        (FlightProduct.PermitData memory permit3) = _createPermitWithSignature(
            customer, 
            premiumAmount, 
            customerPrivateKey, 
            2); // nonce

        vm.startPrank(statisticsProvider);
        NftId policyNftId3 = _createPolicy(
            flightData, 
            departureTime, 
            "2024-11-08 Europe/Zurich", 
            arrivalTime, 
            "2024-11-08 Asia/Bangkok", 
            statistics,
            permit3);
        vm.stopPrank();

        // THEN

        RiskId riskId1 = instanceReader.getPolicyInfo(policyNftId1).riskId;
        assertEq(instanceReader.activeRisks(flightProduct.getNftId()), 1, "unexpected number of active risks (before status callback)");
        assertTrue(instanceReader.getActiveRiskId(flightProduct.getNftId(), 0) == riskId1, "unexpected active risk id");

        assertEq(flightOracle.activeRequests(), 1, "unexpected number of active requests (before status callback)");
        RequestId requestId1 = flightOracle.getActiveRequest(0);
        assertTrue(requestId1.gtz(), "request id zero");

        assertEq(instanceReader.policiesForRisk(riskId1), 3, "unexpected number of policies for risk");
        assertEq(instanceReader.getPolicyForRisk(riskId1, 0).toInt(), policyNftId1.toInt(), "unexpected 1st policy for risk");
        assertEq(instanceReader.getPolicyForRisk(riskId1, 1).toInt(), policyNftId2.toInt(), "unexpected 2nd policy for risk");
        assertEq(instanceReader.getPolicyForRisk(riskId1, 2).toInt(), policyNftId3.toInt(), "unexpected 3rd policy for risk");

        // create flight status data (90 min late)
        bytes1 status = "L";
        int256 delay = 90; 
        uint8 maxPoliciesToProcess = 2;

        // print request before allback
        IOracle.RequestInfo memory requestInfo1 = instanceReader.getRequestInfo(requestId1);
        _printRequest(requestId1, requestInfo1);

        // WHEN
        // set cheking time 2h after scheduled arrival time
        vm.warp(arrivalTime.toInt() + 2 * 3600);

        vm.startPrank(statusProvider);
        flightOracle.respondWithFlightStatus(requestId1, status, delay);
        vm.stopPrank();

        // THEN

        // check remaining policy for risk
        assertEq(instanceReader.policiesForRisk(riskId1), 1, "unexpected remaining number of policies for risk");
        assertEq(instanceReader.getPolicyForRisk(riskId1, 0).toInt(), policyNftId3.toInt(), "unexpected remaining policy for risk");

        // assertTrue(false, "oops");

        requestInfo1 = instanceReader.getRequestInfo(requestId1);
        _printRequest(requestId1, requestInfo1);

        assertEq(instanceReader.activeRisks(flightProduct.getNftId()), 1, "unexpected number of active risks (after status callback)");
        assertTrue(instanceReader.getActiveRiskId(flightProduct.getNftId(), 0) == riskId1, "unexpected active risk id");

        assertEq(flightOracle.activeRequests(), 0, "unexpected number of active requests (after status callback)");

        _printPolicy(
            policyNftId1, 
            instanceReader.getPolicyInfo(policyNftId1));

        // assertTrue(false, "oops");

        // WHEN - process remaining policy (unpermissioned function)
        vm.startPrank(flightOwner);
        flightProduct.processPayoutsAndClosePolicies(riskId1, 2);
        vm.stopPrank();

        // THEN
        assertEq(instanceReader.policiesForRisk(riskId1), 0, "unexpected number of policies for risk (after processing last policy)");
        assertEq(flightOracle.activeRequests(), 0, "unexpected number of active requests (after processing last policy)");

        // assertTrue(false, "oops");
    }


    function test_flightCreatePolicyAndProcessFlightStatusWithInsufficientWalletBalance() public {
        // GIVEN - create policy
        approveProductTokenHandler();

        Amount premiumAmount = flightProduct.MAX_PREMIUM(); // AmountLib.toAmount(30 * 10 ** flightUSD.decimals());

        (FlightProduct.PermitData memory permit) = _createPermitWithSignature(
            customer, 
            premiumAmount, 
            customerPrivateKey, 
            0); // nonce

        // WHEN
        vm.startPrank(statisticsProvider);
        NftId policyNftId = _createPolicy(
            flightData, 
            departureTime, 
            "2024-11-08 Europe/Zurich", 
            arrivalTime, 
            "2024-11-08 Asia/Bangkok", 
            statistics,
            permit);
        vm.stopPrank();

        assertEq(flightOracle.activeRequests(), 1, "unexpected number of active requests (before status callback)");
        RequestId requestId = flightOracle.getActiveRequest(0);
        assertTrue(requestId.gtz(), "request id zero");

        // create flight status data (90 min late)
        bytes1 status = "L";
        int256 delay = 90; 
        uint8 maxPoliciesToProcess = 1;

        // print request before allback
        IOracle.RequestInfo memory requestInfo = instanceReader.getRequestInfo(requestId);
        _printRequest(requestId, requestInfo);

        // WHEN
        // set cheking time 2h after scheduled arrival time
        vm.warp(arrivalTime.toInt() + 2 * 3600);

        vm.startPrank(statusProvider);
        flightOracle.respondWithFlightStatus(requestId, status, delay);
        vm.stopPrank();

        // THEN
        assertEq(flightOracle.activeRequests(), 1, "unexpected number of active requests after status callback");
        assertEq(instanceReader.getRequestState(requestId).toInt(), FAILED().toInt(), "request state not FAILED after callback");

        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertEq(policyInfo.claimsCount, 0, "unexpected number of claims (after status callback with insufficient wallet balance)");
        assertEq(policyInfo.closedAt.toInt(), 0, "unexpected closed at (after status callback with insufficient wallet balance)");

        // WHEN - add funding and resend request
        _transferTokenToPoolWallet(5000 *  10 ** flightUSD.decimals(), true);

        vm.startPrank(statusProvider);
        flightProduct.resendRequest(requestId);
        vm.stopPrank();

        // check intermediate state
        assertEq(flightOracle.activeRequests(), 1, "unexpected number of active requests before updateRequestState");

        // update request state -> will remove request from active requests if state is fulfilled
        flightOracle.updateRequestState(requestId);

        // THEN
        assertEq(flightOracle.activeRequests(), 0, "unexpected number of active requests after resend request");
        assertEq(instanceReader.getRequestState(requestId).toInt(), FULFILLED().toInt(), "request state not FAILED resend request");

        policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertEq(policyInfo.claimsCount, 1, "unexpected number of claims (after resending request with sufficient wallet balance)");
        assertEq(policyInfo.closedAt.toInt(), TimestampLib.current().toInt(), "unexpected closed at (after resending request with sufficient wallet balance)");

        console.log("--- state after pool funding and resending request ---");
        console.log("policy closed at", policyInfo.closedAt.toInt());

        // WHEN - check that function may be called more than once without reverts
        flightOracle.updateRequestState(requestId);

        requestInfo = instanceReader.getRequestInfo(requestId);
        _printRequest(requestId, requestInfo);

        _printPolicy(
            policyNftId, 
            instanceReader.getPolicyInfo(policyNftId));
        
        // assertTrue(false, "oops");
    }


    function test_flightCreatePolicyAndProcessFlightStatusWithoutPayout() public {
        // GIVEN - create policy
        approveProductTokenHandler();

        Amount premiumAmount = flightProduct.MAX_PREMIUM(); // AmountLib.toAmount(30 * 10 ** flightUSD.decimals());

        (FlightProduct.PermitData memory permit) = _createPermitWithSignature(
            customer, 
            premiumAmount, 
            customerPrivateKey, 
            0); // nonce

        // WHEN
        vm.startPrank(statisticsProvider);
        NftId policyNftId = _createPolicy(
            flightData, 
            departureTime, 
            "2024-11-08 Europe/Zurich", 
            arrivalTime, 
            "2024-11-08 Asia/Bangkok", 
            statistics,
            permit);
        vm.stopPrank();

        assertEq(flightOracle.activeRequests(), 1, "unexpected number of active requests (before status callback)");
        RequestId requestId = flightOracle.getActiveRequest(0);
        assertTrue(requestId.gtz(), "request id zero");

        // create flight status data (90 min late)
        bytes1 status = "L";
        int256 delay = 22; 
        uint8 maxPoliciesToProcess = 1;

        // print request before allback
        IOracle.RequestInfo memory requestInfo = instanceReader.getRequestInfo(requestId);
        _printRequest(requestId, requestInfo);

        // WHEN
        // set cheking time 2h after scheduled arrival time
        vm.warp(arrivalTime.toInt() + 2 * 3600);

        vm.startPrank(statusProvider);
        flightOracle.respondWithFlightStatus(requestId, status, delay);
        vm.stopPrank();

        // THEN
        requestInfo = instanceReader.getRequestInfo(requestId);
        _printRequest(requestId, requestInfo);

        assertEq(flightOracle.activeRequests(), 0, "unexpected number of active requests (after status callback)");

        _printPolicy(
            policyNftId, 
            instanceReader.getPolicyInfo(policyNftId));
        
        // assertTrue(false, "oops");
    }
}