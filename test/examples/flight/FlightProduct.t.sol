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
import {FlightLib} from "../../../contracts/examples/flight/FlightLib.sol";
import {FlightProduct} from "../../../contracts/examples/flight/FlightProduct.sol";
import {FlightOracle} from "../../../contracts/examples/flight/FlightOracle.sol";
import {IBundle} from "../../../contracts/instance/module/IBundle.sol";
import {NftId} from "../../../contracts/type/NftId.sol";
import {RiskId} from "../../../contracts/type/RiskId.sol";
import {RequestId, RequestIdLib} from "../../../contracts/type/RequestId.sol";
import {SecondsLib} from "../../../contracts/type/Seconds.sol";
import {SigUtils} from "./SigUtils.sol";
import {Str, StrLib} from "../../../contracts/type/String.sol";
import {Timestamp, TimestampLib} from "../../../contracts/type/Timestamp.sol";

// solhint-disable func-name-mixedcase
contract FlightProductTest is FlightBaseTest {

    SigUtils internal sigUtils;

    // sample flight data
    Str public flightData = StrLib.toStr("LX 180 ZRH BKK 20241108");
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

        sigUtils = new SigUtils(flightUSD.DOMAIN_SEPARATOR());

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

    // TODO cleanup only createPolicyWithPermit is now public/external
    // function test_flightProductCreatePolicyHappyCase() public {
    //     // GIVEN - setp from flight base test
    //     approveProductTokenHandler();

    //     uint256 customerBalanceBefore = flightUSD.balanceOf(customer);
    //     uint256 poolBalanceBefore = flightUSD.balanceOf(flightPool.getWallet());
    //     uint256 productBalanceBefore = flightUSD.balanceOf(flightProduct.getWallet());
    //     Amount premiumAmount = AmountLib.toAmount(30 * 10 ** flightUSD.decimals());

    //     assertEq(instanceReader.risks(flightProductNftId), 0, "unexpected number of risks (before)");
    //     assertEq(instanceReader.activeRisks(flightProductNftId), 0, "unexpected number of active risks (before)");
    //     assertEq(flightOracle.activeRequests(), 0, "unexpected number of active requests (before)");

    //     (uint8 v, bytes32 r, bytes32 s) = _getSignature(
    //         dataSignerPrivateKey,
    //         flightData, 
    //         departureTime, 
    //         arrivalTime, 
    //         premiumAmount, 
    //         statistics);

    //     // WHEN
    //     vm.startPrank(statisticsProvider);
    //     (, NftId policyNftId) = flightProduct.createPolicy(
    //         customer,
    //         flightData,
    //         departureTime,
    //         "2024-11-08 Europe/Zurich",
    //         arrivalTime,
    //         "2024-11-08 Europe/Bangkok",
    //         premiumAmount,
    //         statistics);
    //     vm.stopPrank();

    //     // THEN
    //     // check risks
    //     assertEq(instanceReader.risks(flightProductNftId), 1, "unexpected number of risks (after)");
    //     assertEq(instanceReader.activeRisks(flightProductNftId), 1, "unexpected number of active risks (after)");

    //     RiskId riskId = instanceReader.getRiskId(flightProductNftId, 0);
    //     (bool exists, FlightProduct.FlightRisk memory flightRisk) = FlightLib.getFlightRisk(instanceReader, flightProductNftId, riskId);
    //     _printRisk(riskId, flightRisk);

    //     assertTrue(exists, "risk does not exist");
    //     assertEq(instanceReader.policiesForRisk(riskId), 1, "unexpected number of policies for risk");
    //     assertEq(instanceReader.getPolicyForRisk(riskId, 0).toInt(), policyNftId.toInt(), "unexpected 1st policy for risk");

    //     // check policy
    //     assertTrue(policyNftId.gtz(), "policy nft id zero");
    //     assertEq(registry.ownerOf(policyNftId), customer, "unexpected policy holder");
    //     assertEq(instanceReader.getPolicyState(policyNftId).toInt(), COLLATERALIZED().toInt(), "unexpected policy state");

    //     // check policy info
    //     IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
    //     _printPolicy(policyNftId, policyInfo);

    //     // check policy data
    //     assertTrue(instanceReader.isProductRisk(flightProductNftId, policyInfo.riskId), "risk does not exist for product");
    //     assertEq(policyInfo.productNftId.toInt(), flightProductNftId.toInt(), "unexpected product nft id");
    //     assertEq(policyInfo.bundleNftId.toInt(), bundleNftId.toInt(), "unexpected bundle nft id");
    //     assertEq(policyInfo.activatedAt.toInt(), departureTime.toInt(), "unexpected activate at timestamp");
    //     assertEq(policyInfo.lifetime.toInt(), flightProduct.LIFETIME().toInt(), "unexpected lifetime");
    //     assertTrue(policyInfo.sumInsuredAmount > premiumAmount, "sum insured <= premium amount");

    //     // check premium info
    //     IPolicy.PremiumInfo memory premiumInfo = instanceReader.getPremiumInfo(policyNftId);
    //     _printPremium(policyNftId, premiumInfo);
    //     assertEq(instanceReader.getPremiumState(policyNftId).toInt(), PAID().toInt(), "unexpected premium state");
        
    //     // check token balances
    //     assertEq(flightUSD.balanceOf(flightProduct.getWallet()), productBalanceBefore, "unexpected product balance");
    //     assertEq(flightUSD.balanceOf(flightPool.getWallet()), poolBalanceBefore + premiumAmount.toInt(), "unexpected pool balance");
    //     assertEq(flightUSD.balanceOf(customer), customerBalanceBefore - premiumAmount.toInt(), "unexpected customer balance");

    //     // check oracle request
    //     assertEq(flightOracle.activeRequests(), 1, "unexpected number of active requests (after policy creation)");

    //     RequestId requestId = flightOracle.getActiveRequest(0);
    //     assertTrue(requestId.gtz(), "request id zero");

    //     IOracle.RequestInfo memory requestInfo = instanceReader.getRequestInfo(requestId);
    //     _printRequest(requestId, requestInfo);

    //     FlightOracle.FlightStatusRequest memory statusRequest = abi.decode(requestInfo.requestData, (FlightOracle.FlightStatusRequest));
    //     _printStatusRequest(statusRequest);

    //     assertEq(statusRequest.riskId.toInt(), riskId.toInt(), "unexpected risk id");
    //     assertTrue(statusRequest.flightData == flightData, "unexpected flight data");
    //     assertEq(statusRequest.departureTime.toInt(), departureTime.toInt(), "unexpected departure time");
    // }

    function _createPermitWithSignature(
        address policyHolder,
        Amount premiumAmount,
        uint256 policyHolderPrivateKey,
        uint256 nonce
    )
        internal
        view
        returns (FlightProduct.PermitData memory permit)
    {
        SigUtils.Permit memory suPermit = SigUtils.Permit({
            owner: policyHolder,
            spender: address(flightProduct.getTokenHandler()),
            value: premiumAmount.toInt(),
            nonce: nonce,
            deadline: TimestampLib.current().toInt() + 3600
        });

        bytes32 digest = sigUtils.getTypedDataHash(suPermit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(policyHolderPrivateKey, digest);

        permit.owner = policyHolder;
        permit.spender = address(flightProduct.getTokenHandler());
        permit.value = premiumAmount.toInt();
        permit.deadline = TimestampLib.current().toInt() + 3600;
        permit.v = v;
        permit.r = r;
        permit.s = s;
    }


    function _createPolicy(
        Str flightData, // example: "LX 180 ZRH BKK 20241104"
        Timestamp departureTime,
        string memory departureTimeLocal, // example "2024-10-14T10:10:00.000 Europe/Zurich"
        Timestamp arrivalTime,
        string memory arrivalTimeLocal, // example "2024-10-14T10:10:00.000 Asia/Seoul"
        uint256 [6] memory statistics,
        FlightProduct.PermitData memory permit
    )
        internal
        returns (NftId policyNftId)
    {
        (, policyNftId) = flightProduct.createPolicyWithPermit(
            permit,
            FlightProduct.ApplicationData({
                flightData: flightData,
                departureTime: departureTime,
                departureTimeLocal: departureTimeLocal,
                arrivalTime: arrivalTime,
                arrivalTimeLocal: arrivalTimeLocal,
                premiumAmount: AmountLib.toAmount(permit.value),
                statistics: statistics
            })
        );
    }

    function test_flightProductCreatePolicyWithPermitHappyCase() public {
        // GIVEN - setp from flight base test
        approveProductTokenHandler();

        uint256 customerBalanceBefore = flightUSD.balanceOf(customer);
        uint256 poolBalanceBefore = flightUSD.balanceOf(flightPool.getWallet());
        uint256 productBalanceBefore = flightUSD.balanceOf(flightProduct.getWallet());
        Amount premiumAmount = AmountLib.toAmount(30 * 10 ** flightUSD.decimals());

        assertEq(instanceReader.risks(flightProductNftId), 0, "unexpected number of risks (before)");
        assertEq(instanceReader.activeRisks(flightProductNftId), 0, "unexpected number of active risks (before)");
        assertEq(flightOracle.activeRequests(), 0, "unexpected number of active requests (before)");

        // solhint-disable
        console.log("ts", block.timestamp);
        // solhint-enable

        // TODO cleanup
        // SigUtils.Permit memory permit = SigUtils.Permit({
        //     owner: customer,
        //     spender: address(flightProduct.getTokenHandler()),
        //     value: premiumAmount.toInt(),
        //     nonce: 0,
        //     deadline: TimestampLib.current().toInt() + 3600
        // });

        // // vm.startPrank(customer);
        // bytes32 digest = sigUtils.getTypedDataHash(permit);
        // (uint8 permitV, bytes32 permitR, bytes32 permitS) = vm.sign(customerPrivateKey, digest);
        // // vm.stopPrank();
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

        // (, NftId policyNftId) = flightProduct.createPolicyWithPermit(
        //     FlightProduct.PermitData({
        //         owner: customer,
        //         spender: address(flightProduct.getTokenHandler()),
        //         value: premiumAmount.toInt(),
        //         deadline: TimestampLib.current().toInt() + 3600,
        //         v: permit_v,
        //         r: permit_r,
        //         s: permit_s
        //     }),
        //     FlightProduct.ApplicationData({
        //         flightData: flightData,
        //         departureTime: departureTime,
        //         departureTimeLocal: "2024-11-08 Europe/Zurich",
        //         arrivalTime: arrivalTime,
        //         arrivalTimeLocal: "2024-11-08 Asia/Bangkok",
        //         premiumAmount: premiumAmount,
        //         statistics: statistics
        //     })
        // );
        vm.stopPrank();

        // THEN
        {
            // check risks
            assertEq(instanceReader.risks(flightProductNftId), 1, "unexpected number of risks (after)");
            assertEq(instanceReader.activeRisks(flightProductNftId), 1, "unexpected number of active risks (after)");

            RiskId riskId = instanceReader.getRiskId(flightProductNftId, 0);
            (bool exists, FlightProduct.FlightRisk memory flightRisk) = FlightLib.getFlightRisk(instanceReader, flightProductNftId, riskId);
            _printRisk(riskId, flightRisk);

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
            assertTrue(statusRequest.flightData == flightData, "unexpected flight data");
            assertEq(statusRequest.departureTime.toInt(), departureTime.toInt(), "unexpected departure time");
        }
    }

    function test_flightCreatePolicyAndProcessFlightStatus() public {
        // GIVEN - create policy
        approveProductTokenHandler();

        Amount premiumAmount = AmountLib.toAmount(30 * 10 ** flightUSD.decimals());

        // TODO cleanup
        // vm.startPrank(customer);
        // bytes32 digest = sigUtils.getTypedDataHash(permit);
        // (uint8 permitV, bytes32 permitR, bytes32 permitS) = vm.sign(customerPrivateKey, digest);
        // vm.stopPrank();
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
        // (RiskId riskId, NftId policyNftId) = flightProduct.createPolicy(
        //     customer,
        //     flightData,
        //     departureTime,
        //     "2024-11-08 Europe/Zurich",
        //     arrivalTime,
        //     "2024-11-08 Europe/Bangkok",
        //     premiumAmount,
        //     statistics);
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
        requestInfo = instanceReader.getRequestInfo(requestId);
        _printRequest(requestId, requestInfo);

        assertEq(flightOracle.activeRequests(), 0, "unexpected number of active requests (after status callback)");

        _printPolicy(
            policyNftId, 
            instanceReader.getPolicyInfo(policyNftId));
        
        // assertTrue(false, "oops");
    }
}