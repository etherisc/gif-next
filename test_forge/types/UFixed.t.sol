// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../contracts/types/UFixed.sol";

contract UFixedTest is Test {
    using UFixedMathLib for UFixed;

    function test_testDecimals() public {
        assertEq(UFixedMathLib.decimals(), 18);
    }
    
    function test_op_equal() public {
        UFixed a = UFixed.wrap(1 * 10 ** 18);
        UFixed b = UFixed.wrap(1 * 10 ** 18);
        assertTrue(a == b);

        UFixed c = UFixed.wrap(2 * 10 ** 18);
        assertFalse(a == c);
    }

    function test_UFixedMathLib() public {
        UFixed a = UFixed.wrap(1 * 10 ** 18);
        UFixed b = UFixed.wrap(1 * 10 ** 18);
        assertTrue(a.eq(b));

        UFixed c = UFixed.wrap(2 * 10 ** 18);
        assertFalse(a.eq(c));
    }

    function test_itof() public {
        UFixed a = UFixed.wrap(1 * 10 ** 18);
        assertTrue(a == UFixedMathLib.itof(1));
    }

    function test_ftoi() public {
        UFixed a = UFixed.wrap(1 * 10 ** 18);
        assertTrue(a.ftoi() == 1);
    }
    

    // TODO: use proper UFixed
    function test_op_add() public {
        UFixed a = UFixed.wrap(1 * 10 ** 18);
        UFixed b = UFixed.wrap(1 * 10 ** 18);
        UFixed c = UFixed.wrap(2 * 10 ** 18);
        UFixed d = UFixed.wrap(3 * 10 ** 18);
        assertTrue((a + b) == c);
        assertFalse((a + b) == d);

        assertTrue((a + c) == d);

        UFixed e = UFixed.wrap(0 * 10 ** 18);
        assertTrue((a + e) == a);
        assertTrue((e + e) == e);
    }

    function test_UFixedMathLib_add() public {
        UFixed a = UFixed.wrap(1 * 10 ** 18);
        UFixed b = UFixed.wrap(1 * 10 ** 18);
        UFixed c = UFixed.wrap(2 * 10 ** 18);
        UFixed d = UFixed.wrap(3 * 10 ** 18);
        assertTrue(a.add(b) == c);
        assertFalse(a.add(b) == d);

        assertTrue(a.add(c) == d);

        UFixed e = UFixed.wrap(0 * 10 ** 18);
        assertTrue(a.add(e) == a);
        assertTrue(e.add(e) == e);
    }

    function test_op_sub() public {
        UFixed a = UFixed.wrap(1 * 10 ** 18);
        UFixed b = UFixed.wrap(1 * 10 ** 18);
        UFixed c = UFixed.wrap(2 * 10 ** 18);
        UFixed d = UFixed.wrap(3 * 10 ** 18);
        assertTrue((c - b) == a);
        
        assertTrue((d - c) == a);
        assertFalse((d - b) == b);

        UFixed e = UFixed.wrap(0 * 10 ** 18);
        assertTrue((a - a) == e);
        assertTrue((a - e) == a);
        assertTrue((e - e) == e);

        vm.expectRevert("ERROR:UFM-010:NEGATIVE_RESULT");
        a - c;
    }

    function test_UFixedMathLib_sub() public {
        UFixed a = UFixed.wrap(1 * 10 ** 18);
        UFixed b = UFixed.wrap(1 * 10 ** 18);
        UFixed c = UFixed.wrap(2 * 10 ** 18);
        UFixed d = UFixed.wrap(3 * 10 ** 18);
        assertTrue(c.sub(b) == a);

        assertTrue(d.sub(c) == a);
        assertFalse(d.sub(b) == b);

        UFixed e = UFixed.wrap(0 * 10 ** 18);
        assertTrue(a.sub(a) == e);
        assertTrue(a.sub(e) == a);
        assertTrue(e.sub(e) == e);

        vm.expectRevert("ERROR:UFM-010:NEGATIVE_RESULT");
        a.sub(c);
    }

    function test_op_mul() public {
        // 1 * 1 = 1
        UFixed a = UFixed.wrap(1 * 10 ** 18);
        UFixed b = UFixed.wrap(1 * 10 ** 18);
        UFixed c = UFixed.wrap(1 * 10 ** 18);
        assertTrue((a * b) == c);

        // 1 * 2 = 2
        UFixed d = UFixed.wrap(2 * 10 ** 18);
        assertTrue((a * d) == d);

        // 2 * 2 = 4
        UFixed e = UFixed.wrap(4 * 10 ** 18);
        assertTrue((d * d) == e);
        assertFalse((a * d) == e);

        // 2 * 21 = 42
        UFixed f = UFixed.wrap(21 * 10 ** 18);
        UFixed g = UFixed.wrap(42 * 10 ** 18);
        assertTrue((d * f) == g);
    }

    function test_op_mul_frac() public {
        // 1 * 0.5 = 0.5
        UFixed a = UFixed.wrap(1 * 10 ** 18);
        UFixed b = UFixed.wrap(5 * 10 ** 17);

        assertTrue((a * b) == b);
        assertTrue((b * a) == b);

        // 0.5 * 0.5 = 0.25
        UFixed c = UFixed.wrap(25 * 10 ** 16);
        assertTrue((b * b) == c);
    }

    function test_op_mul_big() public {
        UFixed a = UFixed.wrap(1 * 10 ** 18);
        UFixed d = UFixed.wrap(2 * 10 ** 18);

        // BIG * 1 = BIG
        // BIG = 1 * 10 ** 31
        UFixed BIG = UFixed.wrap(1 * 10 ** 32 - 1);
        assertTrue((BIG * a) == BIG);
        assertTrue((BIG * d) == (BIG + BIG));
    }

    function test_op_mul_zero() public {
        UFixed a = UFixed.wrap(1 * 10 ** 18);
    
        // 1 * 0 = 0
        UFixed z = UFixed.wrap(0 * 10 ** 18);
        assertTrue((a * z) == z);

        // 0 * 0 = 0
        assertTrue((z * z) == z);

        // 0 * 1 = 0
        assertTrue((z * a) == z);
    }

    function test_op_div() public {
        // 1 / 1 = 1
        UFixed a = UFixed.wrap(1 * 10 ** 18);
        UFixed b = UFixed.wrap(1 * 10 ** 18);
        UFixed c = UFixed.wrap(1 * 10 ** 18);
        assertTrue((a / b) == c);

        // 2 / 1 = 2
        UFixed d = UFixed.wrap(2 * 10 ** 18);
        assertTrue((d / a) == d);

        // 2 / 2 = 1
        assertTrue((d / d) == b);

        // 4 / 2 = 2
        UFixed e = UFixed.wrap(4 * 10 ** 18);
        assertTrue((e / d) == d);

        // 42 / 2 = 21
        UFixed f = UFixed.wrap(21 * 10 ** 18);
        UFixed g = UFixed.wrap(42 * 10 ** 18);
        assertTrue((g / d) == f);
    }

    function test_op_div_frac() public {
        UFixed d = UFixed.wrap(2 * 10 ** 18);

        // 5 / 2 = 2.5
        UFixed f1 = UFixed.wrap(5 * 10 ** 18);
        UFixed ex1 = UFixed.wrap(2.5 * 10 ** 18);
        assertTrue((f1 / d) == ex1);

        // 2 / 5 = 0.4
        UFixed ex2 = UFixed.wrap(0.4 * 10 ** 18);
        assertTrue((d / f1) == ex2);

        // 2 / 0.5 = 4
        UFixed f2 = UFixed.wrap(5 * 10 ** 17);
        UFixed ex3 = UFixed.wrap(4 * 10 ** 18);
        assertTrue((d / f2) == ex3);

        // 0.5 / 2 = 0.25
        UFixed ex4 = UFixed.wrap(25 * 10 ** 16);
        assertTrue((f2 / d) == ex4);
    }

    function test_op_div_big() public {
        UFixed a = UFixed.wrap(1 * 10 ** 18);
        UFixed d = UFixed.wrap(2 * 10 ** 18);

        // BIG / 1 = BIG
        // BIG = 1 * 10 ** 31
        UFixed BIG = UFixed.wrap(1 * 10 ** 32 - 1);
        assertTrue((BIG / a) == BIG);
        // (2 * BIG) / 2 = BIG
        assertTrue(((d * BIG) / d) == (BIG));
        assertTrue((BIG / BIG) == a);
    }

    function test_op_div_zero() public {
        UFixed a = UFixed.wrap(1 * 10 ** 18);

        // 0 / 1 = 0
        UFixed z = UFixed.wrap(0 * 10 ** 18);
        assertTrue((z / a) == z);

        // 0 / 0 = 0
        vm.expectRevert("ERROR:UFM-020:DIVISOR_ZERO");
        assertTrue((z / z) == z);

        // 1 / 0 = 0
        vm.expectRevert("ERROR:UFM-020:DIVISOR_ZERO");
        assertTrue((a / z) == z);
    }
}