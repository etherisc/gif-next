// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import "../lib/forge-std/src/Test.sol";
import {console} from "../lib/forge-std/src/Script.sol";

import {TypeA, toTypeA} from "../contracts/experiment/types/TypeA.sol";
import {TypeB, toTypeB} from "../contracts/experiment/types/TypeB.sol";

contract TestExperimentInheritance is Test {

    TypeA a1;
    TypeA a2;

    TypeB b1;
    TypeB b2;

    function setUp() external {
        a1 = toTypeA(1);
        a2 = toTypeA(2);

        b1 = toTypeB(1);
        b2 = toTypeB(2);
    }

    function testExperimentTypesSetUp() public {
        assertEq(a1.toInt(), 1, "a1 not 1");
        assertEq(a2.toInt(), 2, "a2 not 2");

        assertTrue(a1 == a1, "a1 != a1");
        assertTrue(a1 != a2, "a1 == a2");

        assertEq(b1.toInt(), 1, "b1 not 1");
        assertEq(b2.toInt(), 2, "b2 not 2");

        assertTrue(b1 == b1, "b1 != b1");
    }

    function testExperimentTypeBAdding() public {
        TypeB sum = b1 + b2;
        assertTrue(sum == toTypeB(3), "sum not 3");
    }

    function testExperimentTypeNotCompiling() public {
        // TypeB sum = b1 + 2; // + only for TypeB on both sides
        // bool same = (a1 == b1); // only for same type on both sides
        // TypeB x = toTypeB(a1); // only uint256 for toTypeB function
    }
}