// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {UFixed, UFixedLib} from "../../contracts/type/UFixed.sol";

contract UFixedTest is Test {
    using UFixedLib for UFixed;

    function testTestDecimals() public {
        assertEq(UFixedLib.decimals(), 15);
    }

    function testOpEqual() public {
        UFixed a = UFixed.wrap(1 * 10 ** 15);
        UFixed b = UFixed.wrap(1 * 10 ** 15);
        assertTrue(a == b);

        UFixed c = UFixed.wrap(2 * 10 ** 15);
        assertFalse(a == c);
    }

    function testUFixedMathLib() public {
        UFixed a = UFixed.wrap(1 * 10 ** 15);
        UFixed b = UFixed.wrap(1 * 10 ** 15);
        assertTrue(UFixedLib.eq(a, b));

        UFixed c = UFixed.wrap(2 * 10 ** 15);
        assertFalse(UFixedLib.eq(a, c));
    }

    function testItof() public {
        UFixed a = UFixed.wrap(1 * 10 ** 15);
        assertTrue(a == UFixedLib.toUFixed(1));
    }

    function testItof_max() public {
        uint256 n = UFixedLib.max().toInt() + 1;
        vm.expectRevert(abi.encodeWithSelector(
            UFixedLib.UFixedLibNumberTooLarge.selector, 
            n));
        UFixedLib.toUFixed(n);
    }

    function testItofExp() public {
        UFixed a = UFixedLib.toUFixed(1, 2);
        assertTrue(a.toInt() == 100);

        // 0.01 * 100
        UFixed b = UFixedLib.toUFixed(1, -2) *  (UFixedLib.toUFixed(1, 2));
        assertTrue(b.toInt() == 1);

        // smalltest possible value
        UFixedLib.toUFixed(1, -15);
        // one order of magnitude smaller reverts
        vm.expectRevert(abi.encodeWithSelector(UFixedLib.UFixedLibExponentTooSmall.selector, -16));
        UFixedLib.toUFixed(1, -16);

        // largest possible value -- 10 ** 33 (48 - EXP(15))
        assertTrue(
            UFixedLib.toUFixed(1, 33) == UFixedLib.toUFixed(1 * 10 ** 33)
        );
        // one order of magnitude larger reverts
        vm.expectRevert(abi.encodeWithSelector(UFixedLib.UFixedLibExponentTooLarge.selector, 34));
        UFixedLib.toUFixed(1, 48 - 15 + 1);

        // resulting number is too large
        vm.expectRevert(abi.encodeWithSelector(UFixedLib.UFixedLibNumberTooLarge.selector, (1 * 10 ** 30 + 1) * 10 ** (15 + 4)));
        UFixedLib.toUFixed(1 * 10 ** 30 + 1, 4);
    }

    function testFtoi() public {
        UFixed a = UFixed.wrap(1 * 10 ** 15);
        assertTrue(a.toInt() == 1);
    }

    function testFtoiRounding() public {
        UFixed a = UFixed.wrap(4 * 10 ** 14);
        assertTrue(UFixedLib.toIntWithRounding(a, UFixedLib.ROUNDING_UP()) == 1);
        assertTrue(UFixedLib.toIntWithRounding(a, UFixedLib.ROUNDING_DOWN()) == 0);
        assertTrue(UFixedLib.toIntWithRounding(a, UFixedLib.ROUNDING_HALF_UP()) == 0);

        UFixed b = UFixed.wrap(5 * 10 ** 14);
        assertTrue(UFixedLib.toIntWithRounding(b, UFixedLib.ROUNDING_UP()) == 1);
        assertTrue(UFixedLib.toIntWithRounding(b, UFixedLib.ROUNDING_DOWN()) == 0);
        assertTrue(UFixedLib.toIntWithRounding(b, UFixedLib.ROUNDING_HALF_UP()) == 1);

        UFixed c = UFixed.wrap(6 * 10 ** 14);
        assertTrue(UFixedLib.toIntWithRounding(c, UFixedLib.ROUNDING_UP()) == 1);
        assertTrue(UFixedLib.toIntWithRounding(c, UFixedLib.ROUNDING_DOWN()) == 0);
        assertTrue(UFixedLib.toIntWithRounding(c, UFixedLib.ROUNDING_HALF_UP()) == 1);
    }

    function testOpAdd() public {
        UFixed a = UFixed.wrap(1 * 10 ** 15);
        UFixed b = UFixed.wrap(1 * 10 ** 15);
        UFixed c = UFixed.wrap(2 * 10 ** 15);
        UFixed d = UFixed.wrap(3 * 10 ** 15);
        assertTrue((a + b) == c);
        assertTrue(UFixedLib.add(a, b) == c);
        assertFalse((a + b) == d);
        assertFalse(UFixedLib.add(a, b) == d);

        assertTrue((a + c) == d);
        assertTrue(UFixedLib.add(a, c) == d);

        UFixed e = UFixed.wrap(0 * 10 ** 15);
        assertTrue((a + e) == a);
        assertTrue(UFixedLib.add(a, e) == a);
        assertTrue((e + e) == e);
        assertTrue(UFixedLib.add(e, e) == e);
    }

    function testOpSub() public {
        UFixed a = UFixed.wrap(1 * 10 ** 15);
        UFixed b = UFixed.wrap(1 * 10 ** 15);
        UFixed c = UFixed.wrap(2 * 10 ** 15);
        UFixed d = UFixed.wrap(3 * 10 ** 15);
        assertTrue((c - b) == a);
        assertTrue(UFixedLib.sub(c, b) == a);

        assertTrue((d - c) == a);
        assertTrue(UFixedLib.sub(d, c) == a);
        assertFalse((d - b) == b);
        assertFalse(UFixedLib.sub(d, b) == b);

        UFixed e = UFixed.wrap(0 * 10 ** 15);
        assertTrue((a - a) == e);
        assertTrue(UFixedLib.sub(a, a) == e);
        assertTrue((a - e) == a);
        assertTrue(UFixedLib.sub(a, e) == a);
        assertTrue((e - e) == e);
        assertTrue(UFixedLib.sub(e, e) == e);

        vm.expectRevert(abi.encodeWithSelector(UFixedLib.UFixedLibNegativeResult.selector));
        a - c;
        vm.expectRevert(abi.encodeWithSelector(UFixedLib.UFixedLibNegativeResult.selector));
        UFixedLib.sub(a, c);
    }

    function testOpMul() public {
        // 1 * 1 = 1
        UFixed a = UFixed.wrap(1 * 10 ** 15);
        UFixed b = UFixed.wrap(1 * 10 ** 15);
        UFixed c = UFixed.wrap(1 * 10 ** 15);
        assertTrue((a * b) == c);
        assertTrue(a.mul(b).eq(c));

        // 1 * 2 = 2
        UFixed d = UFixed.wrap(2 * 10 ** 15);
        assertTrue((a * d) == d);
        assertTrue(a.mul(d).eq(d));

        // 2 * 2 = 4
        UFixed e = UFixed.wrap(4 * 10 ** 15);
        assertTrue((d * d) == e);
        assertTrue(d.mul(d).eq(e));
        assertFalse((a * d) == e);
        assertFalse(a.mul(d).eq(e));

        // 2 * 21 = 42
        UFixed f = UFixed.wrap(21 * 10 ** 15);
        UFixed g = UFixed.wrap(42 * 10 ** 15);
        assertTrue((d * f) == g);
        assertTrue(d.mul(f).eq(g));
    }

    function testOpMulFrac() public {
        // 1 * 0.5 = 0.5
        UFixed a = UFixed.wrap(1 * 10 ** 15);
        UFixed b = UFixed.wrap(5 * 10 ** 14);

        assertTrue((a * b) == b);
        assertTrue((a.mul(b)).eq(b));
        assertTrue((b * a) == b);
        assertTrue((b.mul(a)).eq(b));

        // 0.5 * 0.5 = 0.25
        UFixed c = UFixed.wrap(25 * 10 ** 13);
        assertTrue((b * b) == c);
        assertTrue((b.mul(b)).eq(c));
    }

    function testOpMulBig() public {
        UFixed one = UFixedLib.toUFixed(1);
        UFixed two = UFixedLib.toUFixed(2);

        // bigUFixed * 1 = bigUFixed
        // bigUFixed = 1 * 10 ** 31
        // UFixed bigUFixed = UFixed.wrap(1 * 10 ** 32 - 1);
        UFixed bigUFixed = UFixedLib.toUFixed(1, 6);
        assertTrue((bigUFixed * one) == bigUFixed, "unexpected outcome (1)");
        assertTrue((bigUFixed.mul(one)).eq(bigUFixed), "unexpected outcome (2)");

        assertTrue((bigUFixed * two) == (bigUFixed + bigUFixed), "unexpected outcome (3)");
        assertTrue((bigUFixed.mul(two)).eq(bigUFixed + bigUFixed), "unexpected outcome (4)");
    }

    function testOpMulZero() public {
        UFixed a = UFixed.wrap(1 * 10 ** 15);
        UFixed b = UFixed.wrap(1 * 10 ** 15);

        // 1 * 0 = 0
        UFixed z = UFixed.wrap(0 * 10 ** 15);
        assertTrue((a * z) == z);
        assertTrue((a.mul(z)).eq(z));

        // 0 * 0 = 0
        assertTrue((z * z) == z);
        assertTrue((z.mul(z)).eq(z));

        // 0 * 1 = 0
        assertTrue((z * a) == z);
        assertTrue((z.mul(a)).eq(z));
        assertTrue((a * b) == a);
        assertTrue((a.mul(b)).eq(a));
    }

    function testOpDiv() public {
        // 1 / 1 = 1
        UFixed a = UFixed.wrap(1 * 10 ** 15);
        UFixed b = UFixed.wrap(1 * 10 ** 15);
        UFixed c = UFixed.wrap(1 * 10 ** 15);
        assertTrue((a / b) == c);
        assertTrue(a.div(b).eq(c));

        // 2 / 1 = 2
        UFixed d = UFixed.wrap(2 * 10 ** 15);
        assertTrue((d / a) == d);
        assertTrue(d.div(a).eq(d));

        // 2 / 2 = 1
        assertTrue((d / d) == b);
        assertTrue(d.div(d).eq(b));

        // 4 / 2 = 2
        UFixed e = UFixed.wrap(4 * 10 ** 15);
        assertTrue((e / d) == d);
        assertTrue(e.div(d).eq(d));

        // 42 / 2 = 21
        UFixed f = UFixed.wrap(21 * 10 ** 15);
        UFixed g = UFixed.wrap(42 * 10 ** 15);
        assertTrue((g / d) == f);
        assertTrue(g.div(d).eq(f));
    }

    function testOpDivFrac() public {
        UFixed d = UFixed.wrap(2 * 10 ** 15);

        // 5 / 2 = 2.5
        UFixed f1 = UFixed.wrap(5 * 10 ** 15);
        UFixed ex1 = UFixed.wrap(2.5 * 10 ** 15);
        assertTrue((f1 / d) == ex1);
        assertTrue(f1.div(d).eq(ex1));

        // 2 / 5 = 0.4
        UFixed ex2 = UFixed.wrap(0.4 * 10 ** 15);
        assertTrue((d / f1) == ex2);
        assertTrue(d.div(f1).eq(ex2));

        // 2 / 0.5 = 4
        UFixed f2 = UFixed.wrap(5 * 10 ** 14);
        UFixed ex3 = UFixed.wrap(4 * 10 ** 15);
        assertTrue((d / f2) == ex3);
        assertTrue(d.div(f2).eq(ex3));

        // 0.5 / 2 = 0.25
        UFixed ex4 = UFixed.wrap(25 * 10 ** 13);
        assertTrue((f2 / d) == ex4);
        assertTrue(f2.div(d).eq(ex4));
    }

    function testOpDivBig() public {
        UFixed a = UFixed.wrap(1 * 10 ** 15);
        UFixed d = UFixed.wrap(2 * 10 ** 15);

        // bigUFixed / 1 = bigUFixed
        // bigUFixed = 1 * 10 ** 31
        UFixed bigUFixed = UFixed.wrap(1 * 10 ** 32 - 1);
        assertTrue((bigUFixed / a) == bigUFixed);
        assertTrue((bigUFixed.div(a)).eq(bigUFixed));

        // (2 * bigUFixed) / 2 = bigUFixed
        assertTrue(((d * bigUFixed) / d) == (bigUFixed));
        assertTrue(((d.mul(bigUFixed)).div(d)).eq(bigUFixed));
        assertTrue((bigUFixed / bigUFixed) == a);
        assertTrue((bigUFixed.div(bigUFixed)).eq(a));
    }

    function testOpDivZero() public {
        UFixed a = UFixed.wrap(1 * 10 ** 15);

        // 0 / 1 = 0
        UFixed z = UFixed.wrap(0 * 10 ** 15);
        assertTrue((z / a) == z);
        assertTrue(z.div(a).eq(z));

        // 0 / 0 = 0
        vm.expectRevert(abi.encodeWithSelector(UFixedLib.UFixedLibDivisionByZero.selector));
        assertTrue((z / z) == z);
        vm.expectRevert(abi.encodeWithSelector(UFixedLib.UFixedLibDivisionByZero.selector));
        assertTrue(z.div(z).eq(z));

        // 1 / 0 = 0
        vm.expectRevert(abi.encodeWithSelector(UFixedLib.UFixedLibDivisionByZero.selector));
        assertTrue((a / z) == z);
        vm.expectRevert(abi.encodeWithSelector(UFixedLib.UFixedLibDivisionByZero.selector));
        assertTrue(a.div(z).eq(z));
    }

    function testOpGt() public {
        UFixed a = UFixed.wrap(1 * 10 ** 15);
        UFixed b = UFixed.wrap(1 * 10 ** 15);
        UFixed c = UFixed.wrap(2 * 10 ** 15);
        assertTrue(c > b);
        assertTrue(c.gt(b));
        assertFalse(a > b);
        assertFalse(a.gt(b));
    }

    function testOpGte() public {
        UFixed a = UFixed.wrap(1 * 10 ** 15);
        UFixed b = UFixed.wrap(1 * 10 ** 15);
        UFixed c = UFixed.wrap(2 * 10 ** 15);
        assertTrue(c >= b);
        assertTrue(c.gte(b));
        assertFalse(a >= c);
        assertFalse(a.gte(c));
        assertTrue(b >= a);
        assertTrue(b.gte(a));
        assertTrue(a >= b);
        assertTrue(a.gte(b));
    }

    function testOpLt() public {
        UFixed a = UFixed.wrap(1 * 10 ** 15);
        UFixed b = UFixed.wrap(1 * 10 ** 15);
        UFixed c = UFixed.wrap(2 * 10 ** 15);
        assertTrue(a < c);
        assertTrue(a.lt(c));
        assertFalse(b < a);
        assertFalse(b.lt(a));
    }

    function testOpLte() public {
        UFixed a = UFixed.wrap(1 * 10 ** 15);
        UFixed b = UFixed.wrap(1 * 10 ** 15);
        UFixed c = UFixed.wrap(2 * 10 ** 15);
        assertTrue(a <= c);
        assertTrue(a.lte(c));
        assertTrue(b <= a);
        assertTrue(b.lte(a));
        assertFalse(c <= b);
        assertFalse(c.lte(b));
    }

    function testGtz() public {
        UFixed a = UFixed.wrap(1 * 10 ** 15);
        UFixed b = UFixed.wrap(0 * 10 ** 15);
        assertTrue(a.gtz());
        assertFalse(b.gtz());
    }

    function testEqz() public {
        UFixed a = UFixed.wrap(1 * 10 ** 15);
        UFixed b = UFixed.wrap(0 * 10 ** 15);
        assertFalse(a.eqz());
        assertTrue(b.eqz());
    }

    function testDelta() public {
        UFixed a = UFixed.wrap(1 * 10 ** 15);
        UFixed b = UFixed.wrap(0 * 10 ** 15);
        assertTrue(a.delta(b).eq(UFixedLib.toUFixed(1)));
        assertTrue(b.delta(a).eq(UFixedLib.toUFixed(1)));

        UFixed c = UFixed.wrap(2 * 10 ** 15);
        assertTrue(c.delta(a).eq(UFixedLib.toUFixed(1)));
        assertTrue(a.delta(c).eq(UFixedLib.toUFixed(1)));

        assertTrue(c.delta(b).eq(UFixedLib.toUFixed(2)));
        assertTrue(b.delta(c).eq(UFixedLib.toUFixed(2)));
    }
}
