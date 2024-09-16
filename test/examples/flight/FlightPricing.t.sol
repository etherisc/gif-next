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
import {Str, StrLib} from "../../../contracts/type/String.sol";
import {Timestamp, TimestampLib} from "../../../contracts/type/Timestamp.sol";

// solhint-disable func-name-mixedcase
contract FlightPricingTest is FlightBaseTest {

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


    function test_flightPricingPrintMultipliers() public {
        // solhint-disable
        console.log("");
        // solhint-enable

        _printMultipliers([uint256(20), 2, 5, 3, 1, 0]);
        _printMultipliers([uint256(100), 0, 0, 0, 0, 0]);

        _printMultipliers([uint256(100), 20,  0,  0,  0,  0]);
        _printMultipliers([uint256(100),  0, 20,  0,  0,  0]);
        _printMultipliers([uint256(100),  0,  0, 20,  0,  0]);
        _printMultipliers([uint256(100),  0,  0,  0, 20,  0]);
        _printMultipliers([uint256(100),  0,  0,  0,  0, 20]);

        // smooting 0 to minimal 1 observation (1%)
        _printMultipliers([uint256(100), 20,  1,  1,  1,  1]);
        _printMultipliers([uint256(100),  1, 20,  1,  1,  1]);
        _printMultipliers([uint256(100),  1,  1, 20,  1,  1]);
        _printMultipliers([uint256(100),  1,  1,  1, 20,  1]);
        _printMultipliers([uint256(100),  1,  1,  1,  1, 20]);

        // smooting 0 to minimal 2 observation (2%)
        _printMultipliers([uint256(100), 20,  2,  2,  2,  2]);
        _printMultipliers([uint256(100),  2, 20,  2,  2,  2]);
        _printMultipliers([uint256(100),  2,  2, 20,  2,  2]);
        _printMultipliers([uint256(100),  2,  2,  2, 20,  2]);
        _printMultipliers([uint256(100),  2,  2,  2,  2, 20]);

        // smooting 0 to minimal 5 observation (5%)
        _printMultipliers([uint256(100), 20,  5,  5,  5,  5]);
        _printMultipliers([uint256(100),  5, 20,  5,  5,  5]);
        _printMultipliers([uint256(100),  5,  5, 20,  5,  5]);
        _printMultipliers([uint256(100),  5,  5,  5, 20,  5]);
        _printMultipliers([uint256(100),  5,  5,  5,  5, 20]);

        _printMultipliers([uint256(100), 20, 20, 20, 20, 20]);
    }


    function test_flightPricingPayoutOptions() public {
        // GIVEN
        RequestId rqId = RequestIdLib.toRequestId(1);
        RiskId rkId = FlightLib.getRiskId(
            flightProductNftId,
            carrierFlightNumber,
            departureTime,
            arrivalTime);

        // solhint-disable
        console.log("X 42", FlightLib.checkAndGetPayoutOption(rqId, rkId, "X", 42));
        console.log("A 0", FlightLib.checkAndGetPayoutOption(rqId, rkId, "A", 0));
        console.log("L -5", FlightLib.checkAndGetPayoutOption(rqId, rkId, "L", -5));
        console.log("L 10", FlightLib.checkAndGetPayoutOption(rqId, rkId, "L", 10));
        console.log("L 15", FlightLib.checkAndGetPayoutOption(rqId, rkId, "L", 15));
        console.log("L 30", FlightLib.checkAndGetPayoutOption(rqId, rkId, "L", 30));
        console.log("L 44", FlightLib.checkAndGetPayoutOption(rqId, rkId, "L", 44));
        console.log("L 45", FlightLib.checkAndGetPayoutOption(rqId, rkId, "L", 45));
        console.log("L 201", FlightLib.checkAndGetPayoutOption(rqId, rkId, "L", 201));
        console.log("C 0", FlightLib.checkAndGetPayoutOption(rqId, rkId, "C", 0));
        console.log("D 0", FlightLib.checkAndGetPayoutOption(rqId, rkId, "D", 0));
        // solhint-enable

        assertEq(FlightLib.checkAndGetPayoutOption(rqId, rkId, "X", 42), 255, "not 255 (no payout X)");
        assertEq(FlightLib.checkAndGetPayoutOption(rqId, rkId, "A", 0), 255, "not 255 (no payout A)");
        assertEq(FlightLib.checkAndGetPayoutOption(rqId, rkId, "L", -5), 255, "not 255 (L -5)");
        assertEq(FlightLib.checkAndGetPayoutOption(rqId, rkId, "L", 10), 255, "not 255 (L 10)");
        assertEq(FlightLib.checkAndGetPayoutOption(rqId, rkId, "L", 15), 0, "not 0 (L 15)");
        assertEq(FlightLib.checkAndGetPayoutOption(rqId, rkId, "L", 30), 1, "not 1 (L 30)");
        assertEq(FlightLib.checkAndGetPayoutOption(rqId, rkId, "L", 44), 1, "not 1 (L 44)");
        assertEq(FlightLib.checkAndGetPayoutOption(rqId, rkId, "L", 45), 2, "not 2 (L 45)");
        assertEq(FlightLib.checkAndGetPayoutOption(rqId, rkId, "L", 201), 2, "not 0 (L 201)");
        assertEq(FlightLib.checkAndGetPayoutOption(rqId, rkId, "C", 0), 3, "not 3 (cancelled)");
        assertEq(FlightLib.checkAndGetPayoutOption(rqId, rkId, "D", 0), 4, "not 4 (diverted)");
    }


    function test_flightPricingCalculateSumInsuredHappyCase() public {
        // GIVEN 
        Amount premiumAmount = AmountLib.toAmount(100 * 10 ** flightUSD.decimals());

        // WHEN
        (
            uint256 weight, 
            Amount[5] memory payoutAmounts,
            Amount sumInsuredAmount // simply the max of payoutAmounts 
        ) = FlightLib.calculatePayoutAmounts(flightProduct, premiumAmount, statistics);

        // solhint-disable
        console.log("weight", weight);
        console.log("premiumAmount", premiumAmount.toInt() / 10 ** flightUSD.decimals());
        console.log("sumInsuredAmount", sumInsuredAmount.toInt() / 10 ** flightUSD.decimals(), sumInsuredAmount.toInt());
        // solhint-enable
    }


    function _printMultipliers(uint256[6] memory statistics) internal {
        uint256 weight = FlightLib.calculateWeight(flightProduct, statistics);

        string memory stat = string(
            abi.encodePacked(
                StrLib.uintToString(statistics[0]), " ", 
                StrLib.uintToString(statistics[1]), " ", 
                StrLib.uintToString(statistics[2]), " ", 
                StrLib.uintToString(statistics[3]), " ", 
                StrLib.uintToString(statistics[4]), " ", 
                StrLib.uintToString(statistics[5])));

        string memory multipliers = string(
            abi.encodePacked(
                StrLib.uintToString(m(weight, 1)), " ", 
                StrLib.uintToString(m(weight, 2)), " ", 
                StrLib.uintToString(m(weight, 3)), " ", 
                StrLib.uintToString(m(weight, 4)), " ", 
                StrLib.uintToString(m(weight, 5))));

        // solhint-disable
        console.log(
            "statistics : multipliers_(x100)", stat, ":", multipliers);
        // solhint-enable
    }


    function m(uint256 weight, uint256 idx) internal view returns (uint256 multiplier) {
        uint256 factor = 100;
        multiplier = (factor * 10000 * uint256(flightProduct.WEIGHT_PATTERN(idx))) / weight;
    }
}