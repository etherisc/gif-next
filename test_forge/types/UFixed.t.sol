// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import { Test } from  "../../lib/forge-std/src/Test.sol";
import "../../contracts/types/UFixed.sol";

contract UFixedTest is Test {
    using UFixedMathLib for UFixed;

    function test_testDecimals() public {
        assertEq(UFixedMathLib.decimals(), 18);
    }
    
    function test_op_equal() public {
        UFixed a = UFixed.wrap(1);
        UFixed b = UFixed.wrap(1);
        assertTrue(a == b);

        UFixed c = UFixed.wrap(2);
        assertFalse(a == c);
    }

    function test_UFixedMathLib() public {
        UFixed a = UFixed.wrap(1);
        UFixed b = UFixed.wrap(1);
        assertTrue(a.eq(b));

        UFixed c = UFixed.wrap(2);
        assertFalse(a.eq(c));
    }

    function test_op_add() public {
        UFixed a = UFixed.wrap(1);
        UFixed b = UFixed.wrap(1);
        UFixed c = UFixed.wrap(2);
        UFixed d = UFixed.wrap(3);
        assertTrue((a + b) == c);

        assertTrue((a + c) == d);

        UFixed e = UFixed.wrap(0);
        assertTrue((a + e) == a);
        assertTrue((e + e) == e);
    }

    function test_UFixedMathLib_add() public {
        UFixed a = UFixed.wrap(1);
        UFixed b = UFixed.wrap(1);
        UFixed c = UFixed.wrap(2);
        UFixed d = UFixed.wrap(3);
        assertTrue(a.add(b) == c);

        assertTrue(a.add(c) == d);

        UFixed e = UFixed.wrap(0);
        assertTrue(a.add(e) == a);
        assertTrue(e.add(e) == e);
    }

    function test_op_sub() public {
        UFixed a = UFixed.wrap(1);
        UFixed b = UFixed.wrap(1);
        UFixed c = UFixed.wrap(2);
        UFixed d = UFixed.wrap(3);
        assertTrue((c - b) == a);

        assertTrue((d - c) == a);

        UFixed e = UFixed.wrap(0);
        assertTrue((a - a) == e);
        assertTrue((a - e) == a);
        assertTrue((e - e) == e);

        vm.expectRevert("ERROR:UFM-010:NEGATIVE_RESULT");
        a - c;
    }

    function test_UFixedMathLib_sub() public {
        UFixed a = UFixed.wrap(1);
        UFixed b = UFixed.wrap(1);
        UFixed c = UFixed.wrap(2);
        UFixed d = UFixed.wrap(3);
        assertTrue(c.sub(b) == a);

        assertTrue(d.sub(c) == a);

        UFixed e = UFixed.wrap(0);
        assertTrue(a.sub(a) == e);
        assertTrue(a.sub(e) == a);
        assertTrue(e.sub(e) == e);

        vm.expectRevert("ERROR:UFM-010:NEGATIVE_RESULT");
        a.sub(c);
    }
}