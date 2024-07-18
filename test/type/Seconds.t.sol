// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {Seconds, SecondsLib} from "../../contracts/type/Seconds.sol";

contract SecondsTest is Test {

    function test_SecondsToIntHappyCase() public {
        uint40 duration = 1691321541;
        assertEq(SecondsLib.toSeconds(duration).toInt(), duration, "unexpected duration");
    }

    function test_SecondsZero() public {
        assertEq(SecondsLib.zero().toInt(), 0, "zero not 0");
        assertTrue(SecondsLib.zero().eqz(), "zero not eqz");
    }

    function test_SecondsMax() public {
        uint40 durationMax = uint40(SecondsLib.max().toInt());
        assertEq(durationMax, type(uint40).max, "unexpected max value");
        assertEq(SecondsLib.toSeconds(durationMax).toInt(), durationMax, "unexpected duration");
        assertTrue(SecondsLib.max().gtz(), "max not gtz");
    }

    function test_SecondsEqz() public {
        assertTrue(SecondsLib.toSeconds(0).eqz(), "0 not zero");
        assertFalse(SecondsLib.toSeconds(1).eqz(), "1 is zero");
    }

    function test_SecondsGtz() public {
        assertTrue(SecondsLib.toSeconds(1).gtz(), "1 == zero");
        assertFalse(SecondsLib.toSeconds(0).gtz(), "0 > zero");
    }

    function test_SecondsAdd() public {
        uint40 duration1 = 1691321541;
        uint40 duration2 = 1691321541;
        uint40 duration3 = 3382643082;
        assertTrue(SecondsLib.add(SecondsLib.toSeconds(duration1), SecondsLib.toSeconds(duration2)).toInt() == duration3, "unexpected duration");
        assertTrue(SecondsLib.toSeconds(duration1) + SecondsLib.toSeconds(duration2) == SecondsLib.toSeconds(duration3), "unexpected duration");
    }

    function test_SecondsToIntDurationTooBig() public {
        uint256 duration = SecondsLib.max().toInt() + 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                SecondsLib.ErrorSecondsLibDurationTooBig.selector,
                duration));

        SecondsLib.toSeconds(duration);
    }
}
