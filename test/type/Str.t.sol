// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {StrLib} from "../../contracts/type/String.sol";

contract StrTest is Test {

    function test_ObjecTypeIntToString() public {
        assertEq(StrLib.uintToString(0), "0", "unexpected string for uint");
        assertEq(StrLib.uintToString(1), "1", "unexpected string for uint");
        assertEq(StrLib.uintToString(17), "17", "unexpected string for uint");
        assertEq(StrLib.uintToString(99), "99", "unexpected string for uint");
        assertEq(StrLib.uintToString(100), "100", "unexpected string for uint");
        assertEq(StrLib.uintToString(987654321), "987654321", "unexpected string for uint");
    }
}
