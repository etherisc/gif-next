// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../../lib/forge-std/src/Test.sol";

import {Amount, AmountLib} from "../../contracts/type/Amount.sol";
import {GifTest} from "../base/GifTest.sol";
import {Seconds, SecondsLib} from "../../contracts/type/Seconds.sol";
import {StakeManagerLib} from "../../contracts/staking/StakeManagerLib.sol";
import {UFixed, UFixedLib} from "../../contracts/type/UFixed.sol";


contract RewardCalculation is GifTest {

    function test_rewardCalculationConsoleLog() public {
        // solhint-disable
        console.log("getYearDuration()", SecondsLib.oneYear().toInt());
        console.log("356 * 24 * 3600", uint(356 * 24 * 3600));

        Seconds halfYear = SecondsLib.toSeconds(SecondsLib.oneYear().toInt() / 2);
        console.log("halfYear", halfYear.toInt());
        UFixed halfYearFraction = StakeManagerLib.getYearFraction(halfYear);
        console.log("getYearFraction(halfYear)", _times1000(halfYearFraction));

        UFixed third = _third();
        console.log("third * 1000", _times1000(third));
        // solhint-enable
    }

    function test_rewardCalculationGetYearFraction() public {

        // check for 1 year
        Seconds yearDuration = SecondsLib.oneYear();
        uint256 yearDurationInt = yearDuration.toInt();
        assertEq(yearDurationInt, 365 * 24 * 3600, "unexpected year duration");

        UFixed one = UFixedLib.toUFixed(1);
        UFixed fractionFullYear = StakeManagerLib.getYearFraction(yearDuration);
        assertEq(_times1000(fractionFullYear), 1000, "unexpected full year fraction (x1000)");
        assertTrue(fractionFullYear == one, "unexpected full year fraction (equals)");

        // check for 4 years
        uint256 fourYearDurationInt = 4 * yearDuration.toInt();
        Seconds fourYearDuration = SecondsLib.toSeconds(fourYearDurationInt);
        assertEq(fourYearDurationInt, 4 * 365 * 24 * 3600, "unexpected 4 year duration");

        UFixed four = UFixedLib.toUFixed(4);
        UFixed fractionFourYears = StakeManagerLib.getYearFraction(fourYearDuration);
        assertEq(_times1000(fractionFourYears), 4000, "unexpected 4 year fraction (x1000)");
        assertTrue(fractionFourYears == four, "unexpected 4 year fraction (equals)");

        // check 1/3 year
        Seconds thirdYearDuration = SecondsLib.toSeconds(yearDurationInt / 3);
        UFixed epsilon = UFixedLib.toUFixed(1, -10);
        UFixed third = _third();
        UFixed fractionThirdYear = StakeManagerLib.getYearFraction(thirdYearDuration);
        assertEq(_times1000(fractionThirdYear), 333, "unexpected third year fraction (x1000)");
        assertTrue(UFixedLib.delta(fractionThirdYear, third) < epsilon, "unexpected third year fraction (equals)");

        Seconds oneHourDuration = SecondsLib.toSeconds(3600);
        // 1 / (365 * 24) = 0.00011415525114155251
        UFixed oneHFraction = UFixedLib.toUFixed(114155251141, -15);
        UFixed fractionOneH = StakeManagerLib.getYearFraction(oneHourDuration);
        assertEq(_times1e9(fractionOneH), 114155, "unexpected 1h fraction (x1e9)");
        assertTrue(UFixedLib.delta(fractionOneH, oneHFraction) < epsilon, "unexpected 1h fraction (equals)");
    }


    function test_rewardCalculationCalculateRewardInitial() public {

        // check for 1 year
        UFixed tenPercentAPR = UFixedLib.toUFixed(1, -1); 
        Seconds yearDuration = SecondsLib.oneYear();
        Amount thousand = AmountLib.toAmount(1000);

        // staking 1000 for 1 year with 10% apr -> reward amount 100
        Amount rewardAmount = StakeManagerLib.calculateRewardAmount(
            tenPercentAPR, 
            yearDuration, 
            thousand);

        assertEq(rewardAmount.toInt(), 100, "unexpected reward amount for (10%, 1 year, 1000)");
    }


    function test_rewardCalculationCalculateRewardApr() public {

        // check for 1 year
        UFixed tenPercentAPR = UFixedLib.toUFixed(1, -1); 
        Seconds yearDuration = SecondsLib.oneYear();
        Amount thousand = AmountLib.toAmount(1000);

        // 20% reward rate
        assertEq(
            StakeManagerLib.calculateRewardAmount(UFixedLib.toUFixed(2, -1), yearDuration, thousand).toInt(), 
            200, "unexpected reward amount for (20%, 1 year, 1000)");

        // 0.1% reward rate
        assertEq(
            StakeManagerLib.calculateRewardAmount(UFixedLib.toUFixed(1, -3), yearDuration, thousand).toInt(), 
            1, "unexpected reward amount for (1%, 1 year, 1000)");
    }


    function test_rewardCalculationCalculateRewardDuration() public {

        // check for 1 year
        UFixed tenPercentAPR = UFixedLib.toUFixed(1, -1); 
        Seconds yearDuration = SecondsLib.oneYear();
        uint256 yearDurationInt = yearDuration.toInt();
        Amount thousand = AmountLib.toAmount(1000);

        // 5 years
        assertEq(
            StakeManagerLib.calculateRewardAmount(tenPercentAPR, SecondsLib.toSeconds(5 * yearDurationInt), thousand).toInt(), 
            500, "unexpected reward amount for (10%, 5 year, 1000)");

        // 2 years
        assertEq(
            StakeManagerLib.calculateRewardAmount(tenPercentAPR, SecondsLib.toSeconds(2 * yearDurationInt), thousand).toInt(), 
            200, "unexpected reward amount for (10%, 2 year, 1000)");

        // 1/2 year
        assertEq(
            StakeManagerLib.calculateRewardAmount(tenPercentAPR, SecondsLib.toSeconds(yearDurationInt / 2), thousand).toInt(), 
            50, "unexpected reward amount for (10%, 1/2 year, 1000)");

        // 1/10 year
        assertEq(
            StakeManagerLib.calculateRewardAmount(tenPercentAPR, SecondsLib.toSeconds(yearDurationInt / 10), thousand).toInt(), 
            10, "unexpected reward amount for (10%, 1/10 year, 1000)");
    }


    function test_rewardCalculationCalculateRewardAmount() public {

        // check for 1 year
        UFixed tenPercentAPR = UFixedLib.toUFixed(1, -1); 
        Seconds yearDuration = SecondsLib.oneYear();
        uint256 yearDurationInt = yearDuration.toInt();
        Amount thousand = AmountLib.toAmount(1000);

        // 4000
        assertEq(
            StakeManagerLib.calculateRewardAmount(tenPercentAPR, yearDuration, AmountLib.toAmount(4000)).toInt(), 
            400, "unexpected reward amount for (10%, 1 year, 4000)");

        // 1500
        assertEq(
            StakeManagerLib.calculateRewardAmount(tenPercentAPR, yearDuration, AmountLib.toAmount(1500)).toInt(), 
            150, "unexpected reward amount for (10%, 1 year, 1500)");

        // 100
        assertEq(
            StakeManagerLib.calculateRewardAmount(tenPercentAPR, yearDuration, AmountLib.toAmount(100)).toInt(), 
            10, "unexpected reward amount for (10%, 1 year, 100)");

        // 10
        assertEq(
            StakeManagerLib.calculateRewardAmount(tenPercentAPR, yearDuration, AmountLib.toAmount(10)).toInt(), 
            1, "unexpected reward amount for (10%, 1 year, 10)");
    }


    function test_rewardCalculationCalculateRewardZero() public {

        UFixed tenPercentAPR = UFixedLib.toUFixed(1, -1); 
        Seconds yearDuration = SecondsLib.oneYear();
        Amount thousand = AmountLib.toAmount(1000);

        // 0% reward rate
        assertEq(
            StakeManagerLib.calculateRewardAmount(UFixedLib.toUFixed(0), yearDuration, thousand).toInt(), 
            0, "unexpected reward amount for (0%, 1 year, 1000)");

        // 0 seconds
        assertEq(
            StakeManagerLib.calculateRewardAmount(tenPercentAPR, SecondsLib.toSeconds(0), thousand).toInt(), 
            0, "unexpected reward amount for (10%, 0 seconds, 1000)");

        // 0 amount
        assertEq(
            StakeManagerLib.calculateRewardAmount(tenPercentAPR, yearDuration, AmountLib.zero()).toInt(), 
            0, "unexpected reward amount for (10%, 1 year, 0)");
    }


    function _third() internal pure returns (UFixed third) {
        uint256 many3 = 333333333333;
        third = UFixedLib.toUFixed(many3, -12);
    }

    function _times1000(UFixed value) internal pure returns (uint256) {
        return (UFixedLib.toUFixed(1000) * value).toInt();
    }

    function _times1e9(UFixed value) internal pure returns (uint256) {
        return (UFixedLib.toUFixed(1000000000) * value).toInt();
    }

}