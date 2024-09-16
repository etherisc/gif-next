// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../../../lib/forge-std/src/Test.sol";

import {IOracle} from "../../../contracts/oracle/IOracle.sol";
import {IPolicy} from "../../../contracts/instance/module/IPolicy.sol";

import {Amount, AmountLib} from "../../../contracts/type/Amount.sol";
import {FlightOracle} from "../../../contracts/examples/flight/FlightOracle.sol";
import {FlightOracleAuthorization} from "../../../contracts/examples/flight/FlightOracleAuthorization.sol";
import {FlightPool} from "../../../contracts/examples/flight/FlightPool.sol";
import {FlightPoolAuthorization} from "../../../contracts/examples/flight/FlightPoolAuthorization.sol";
import {FlightProduct} from "../../../contracts/examples/flight/FlightProduct.sol";
import {FlightProductAuthorization} from "../../../contracts/examples/flight/FlightProductAuthorization.sol";
import {FlightUSD} from "../../../contracts/examples/flight/FlightUSD.sol";
import {GifTest} from "../../base/GifTest.sol";
import {NftId} from "../../../contracts/type/NftId.sol";
import {RequestId} from "../../../contracts/type/RequestId.sol";
import {RiskId} from "../../../contracts/type/RiskId.sol";
import {VersionPartLib} from "../../../contracts/type/Version.sol";


contract FlightBaseTest is GifTest {

    address public flightOwner = makeAddr("flightOwner");

    FlightUSD public flightUSD;
    FlightOracle public flightOracle;
    FlightPool public flightPool;
    FlightProduct public flightProduct;

    NftId public flightOracleNftId;
    NftId public flightPoolNftId;
    NftId public flightProductNftId;

    function setUp() public virtual override {
        super.setUp();
        
        _deployFlightUSD();
        _deployFlightProduct();
        _deployFlightOracle();
        _deployFlightPool();

        // fetches oracle nft id via instance
        flightProduct.setOracleNftId();

        _initialFundAccounts();
    }

    function _deployFlightUSD() internal {
        // deploy fire token
        vm.startPrank(flightOwner);
        flightUSD = new FlightUSD();
        vm.stopPrank();

        // whitelist fire token and make it active for release 3
        vm.startPrank(registryOwner);
        tokenRegistry.registerToken(address(flightUSD));
        tokenRegistry.setActiveForVersion(
            currentChainId, 
            address(flightUSD), 
            VersionPartLib.toVersionPart(3),
            true);
        vm.stopPrank();
    }


    function _deployFlightProduct() internal {
        vm.startPrank(flightOwner);
        FlightProductAuthorization productAuthz = new FlightProductAuthorization("FlightProduct");
        flightProduct = new FlightProduct(
            address(registry),
            instanceNftId,
            "FlightProduct",
            productAuthz
        );
        vm.stopPrank();

        // instance owner registeres fire product with instance (and registry)
        vm.prank(instanceOwner);
        flightProductNftId = instance.registerProduct(
            address(flightProduct), 
            address(flightUSD));

        // complete setup
        vm.prank(flightOwner);
        flightProduct.completeSetup();
    }


    function _deployFlightPool() internal {
        vm.startPrank(flightOwner);
        FlightPoolAuthorization poolAuthz = new FlightPoolAuthorization("FlightPool");
        flightPool = new FlightPool(
            address(registry),
            flightProductNftId,
            "FlightPool",
            poolAuthz
        );
        vm.stopPrank();

        flightPoolNftId = _registerComponent(
            flightOwner, 
            flightProduct, 
            address(flightPool), 
            "flightPool");
    }


    function _deployFlightOracle() internal {
        vm.startPrank(flightOwner);
        FlightOracleAuthorization oracleAuthz = new FlightOracleAuthorization("FlightOracle");
        flightOracle = new FlightOracle(
            address(registry),
            flightProductNftId,
            oracleAuthz,
            flightOwner
        );
        vm.stopPrank();

        flightOracleNftId = _registerComponent(
            flightOwner, 
            flightProduct, 
            address(flightOracle), 
            "FlightOracle");
    }


    function _createInitialBundle() internal returns (NftId bundleNftId) {
        vm.startPrank(flightOwner);
        Amount investAmount = AmountLib.toAmount(10000000 * 10 ** 6);
        flightUSD.approve(
            address(flightPool.getTokenHandler()), 
            investAmount.toInt());
        bundleNftId = flightPool.createBundle(investAmount);
        vm.stopPrank();
    }


    function _initialFundAccounts() internal {
        _fundAccount(flightOwner, 100000 * 10 ** flightUSD.decimals());
        _fundAccount(customer, 10000 * 10 ** flightUSD.decimals());
    }


    function _fundAccount(address account, uint256 amount) internal {
        vm.startPrank(flightOwner);
        flightUSD.transfer(account, amount);
        vm.stopPrank();
    }


    function _printStatusRequest(FlightOracle.FlightStatusRequest memory statusRequest) internal {
        // solhint-disable
        console.log("FlightStatusRequest (requestData)", statusRequest.riskId.toInt());
        console.log("- riskId", statusRequest.riskId.toInt());
        console.log("- carrierFlightNumber", statusRequest.carrierFlightNumber.toString());
        console.log("- departureYearMonthDay", statusRequest.departureYearMonthDay.toString());
        console.log("- departureTime", statusRequest.departureTime.toInt());
        // solhint-enable
    }


    function _printRisk(RiskId riskId, FlightProduct.FlightRisk memory flightRisk) internal {
        // solhint-disable
        console.log("riskId", riskId.toInt());
        console.log("- carrierFlightNumber", flightRisk.carrierFlightNumber.toString());
        console.log("- departureYearMonthDay", flightRisk.departureYearMonthDay.toString());
        console.log("- departureTime", flightRisk.departureTime.toInt());
        console.log("- arrivalTime", flightRisk.arrivalTime.toInt());
        console.log("- delayMinutes", flightRisk.delayMinutes);
        console.log("- status", uint8(flightRisk.status));
        console.log("- sumOfSumInsuredAmounts", flightRisk.sumOfSumInsuredAmounts.toInt());
        console.log("- premiumMultiplier", flightRisk.premiumMultiplier);
        console.log("- weight", flightRisk.weight);   
        // solhint-enable
    }


    function _printRequest(RequestId requestId, IOracle.RequestInfo memory requestInfo) internal {
        // solhint-disable
        console.log("requestId", requestId.toInt());
        console.log("- state", instanceReader.getRequestState(requestId).toInt());
        console.log("- requesterNftId", requestInfo.requesterNftId.toInt());
        console.log("- oracleNftId", requestInfo.oracleNftId.toInt());
        console.log("- isCancelled", requestInfo.isCancelled);
        console.log("- respondedAt", requestInfo.respondedAt.toInt());
        console.log("- expiredAt", requestInfo.expiredAt.toInt());
        console.log("- callbackMethodName", requestInfo.callbackMethodName);
        console.log("- requestData.length", requestInfo.requestData.length);
        console.log("- responseData.length", requestInfo.responseData.length);
        // solhint-enable
    }


    function _printPolicy(NftId policyNftId, IPolicy.PolicyInfo memory policyInfo) internal {
        // solhint-disable
        console.log("policy", policyNftId.toInt());
        console.log("- productNftId", policyInfo.productNftId.toInt());
        console.log("- bundleNftId", policyInfo.bundleNftId.toInt());
        console.log("- riskId referralId", policyInfo.riskId.toInt(), policyInfo.referralId.toInt());
        console.log("- activatedAt lifetime", policyInfo.activatedAt.toInt(), policyInfo.lifetime.toInt());
        console.log("- expiredAt closedAt", policyInfo.expiredAt.toInt(), policyInfo.closedAt.toInt());
        console.log("- sumInsuredAmount", policyInfo.sumInsuredAmount.toInt());
        console.log("- premiumAmount", policyInfo.premiumAmount.toInt());
        console.log("- claimsCount claimAmount", policyInfo.claimsCount, policyInfo.claimAmount.toInt());
        console.log("- payoutAmount", policyInfo.payoutAmount.toInt());
        // solhint-enable
    }


    function _printPremium(NftId policyNftId, IPolicy.PremiumInfo memory premiumInfo) internal {
        // solhint-disable
        console.log("premium", policyNftId.toInt());
        console.log("- premiumAmount", premiumInfo.premiumAmount.toInt());
        console.log("- netPremiumAmount", premiumInfo.netPremiumAmount.toInt());
        console.log("- productFeeAmount", premiumInfo.productFeeAmount.toInt());
        console.log("- distributionFeeAndCommissionAmount", premiumInfo.distributionFeeAndCommissionAmount.toInt());
        console.log("- poolPremiumAndFeeAmount", premiumInfo.poolPremiumAndFeeAmount.toInt());
        console.log("- discountAmount", premiumInfo.discountAmount.toInt());
        // solhint-enable
    }
}