// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import "../lib/forge-std/src/Test.sol";
import {console} from "../lib/forge-std/src/Script.sol";

import {A} from "../contracts/experiment/inheritance/A.sol";

contract TestExperimentInheritance is Test {

    A a;
    
    function setUp() external {
        a = new A();
    }

    function testExperimentInheritanceInitalState() public {
        assertEq(a.getA(), 42, "a not 42");
        assertEq(a.getB(), 1, "b not 1");
        assertEq(a.getC(), 2, "c not 2");

        assertEq(a.getAfromB(), 42, "a from b not 42");
        assertEq(a.getAfromC(), 42, "a from c not 42");

        assertEq(a.getBfromC(), 1, "b from c not 1");
    }

    function testExperimentInheritanceSetNewValues() public {
        uint256 newA = 43;
        uint256 newB = 10;
        uint256 newC = 20;

        a.setA(newA);
        a.setB(newB);
        a.setC(newC);

        assertEq(a.getA(), newA, "a not 43");
        assertEq(a.getB(), newB, "b not 10");
        assertEq(a.getC(), newC, "c not 20");

        assertEq(a.getAfromB(), newA, "a from b not 43");
        assertEq(a.getAfromC(), newA, "a from c not 43");

        assertEq(a.getBfromC(), newB, "b from c not 10");
    }
}