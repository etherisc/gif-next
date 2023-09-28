// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {Test} from "../lib/forge-std/src/Test.sol";
import {DIP} from "./mock/Dip.sol";

contract DipTest is Test {
    DIP public dip;

    function setUp() public {
        dip = new DIP();
    }

    function testDecimals() public {
        assertEq(dip.decimals(), 18);
    }
}
