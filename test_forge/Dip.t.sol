// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import "../lib/forge-std/src/Test.sol";
import "../contracts/Dip.sol";

contract DipTest is Test {
    DIP dip;
    
    function setUp() public {
        dip = new DIP();
    }

    function test_decimals() public {
        assertEq(dip.decimals(), 18);
    }
}
