// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {UFixedMathLib, UFixed} from "../../contracts/types/UFixed.sol";

contract UFixedTest is Test {
    using UFixedMathLib for UFixed;

    function testTestDecimals() public {
        assertEq(UFixedMathLib.decimals(), 18);
    }

    function testOpEqual() public {
        UFixed a = UFixed.wrap(1 * 10 ** 18);
        UFixed b = UFixed.wrap(1 * 10 ** 18);
        assertTrue(a == b);

        UFixed c = UFixed.wrap(2 * 10 ** 18);
        assertFalse(a == c);
    }

    function testUFixedMathLib() public {
        UFixed a = UFixed.wrap(1 * 10 ** 18);
        UFixed b = UFixed.wrap(1 * 10 ** 18);
        assertTrue(a.eq(b));

        UFixed c = UFixed.wrap(2 * 10 ** 18);
        assertFalse(a.eq(c));
    }

    function testItof() public {
        UFixed a = UFixed.wrap(1 * 10 ** 18);
        assertTrue(a == UFixedMathLib.toUFixed(1));
    }

    function testItofExp() public {
        UFixed a = UFixedMathLib.toUFixed(1, 2);
        assertTrue(a.toInt() == 100);

        // 0.01 * 100
        UFixed b = UFixedMathLib.toUFixed(1, -2).mul(UFixedMathLib.toUFixed(1, 2));
        assertTrue(b.toInt() == 1);

        // smalltest possible value
        UFixedMathLib.toUFixed(1, -18);
        // one order of magnitude smaller reverts
        vm.expectRevert("ERROR:FM-010:EXPONENT_TOO_SMALL");
        UFixedMathLib.toUFixed(1, -19);

        // largest possible value -- 10 ** 46 (64 - EXP(18))
        assertTrue(
            UFixedMathLib.toUFixed(1, 46) == UFixedMathLib.toUFixed(1 * 10 ** 46)
        );
        // one order of magnitude larger reverts
        vm.expectRevert("ERROR:FM-011:EXPONENT_TOO_LARGE");
        UFixedMathLib.toUFixed(1, 64 - 18 + 1);
    }

    function testFtoi() public {
        UFixed a = UFixed.wrap(1 * 10 ** 18);
        assertTrue(a.toInt() == 1);
    }

    function testFtoiRounding() public {
        UFixed a = UFixed.wrap(4 * 10 ** 17);
        assertTrue(a.ftoi(UFixedMathLib.ROUNDING_UP()) == 1);
        assertTrue(a.ftoi(UFixedMathLib.ROUNDING_DOWN()) == 0);
        assertTrue(a.ftoi(UFixedMathLib.ROUNDING_HALF_UP()) == 0);

        UFixed b = UFixed.wrap(5 * 10 ** 17);
        assertTrue(b.ftoi(UFixedMathLib.ROUNDING_UP()) == 1);
        assertTrue(b.ftoi(UFixedMathLib.ROUNDING_DOWN()) == 0);
        assertTrue(b.ftoi(UFixedMathLib.ROUNDING_HALF_UP()) == 1);

        UFixed c = UFixed.wrap(6 * 10 ** 17);
        assertTrue(c.ftoi(UFixedMathLib.ROUNDING_UP()) == 1);
        assertTrue(c.ftoi(UFixedMathLib.ROUNDING_DOWN()) == 0);
        assertTrue(c.ftoi(UFixedMathLib.ROUNDING_HALF_UP()) == 1);
    }

    function testOpAdd() public {
        UFixed a = UFixed.wrap(1 * 10 ** 18);
        UFixed b = UFixed.wrap(1 * 10 ** 18);
        UFixed c = UFixed.wrap(2 * 10 ** 18);
        UFixed d = UFixed.wrap(3 * 10 ** 18);
        assertTrue((a + b) == c);
        assertTrue(a.add(b) == c);
        assertFalse((a + b) == d);
        assertFalse(a.add(b) == d);

        assertTrue((a + c) == d);
        assertTrue(a.add(c) == d);

        UFixed e = UFixed.wrap(0 * 10 ** 18);
        assertTrue((a + e) == a);
        assertTrue(a.add(e) == a);
        assertTrue((e + e) == e);
        assertTrue(e.add(e) == e);
    }

    function testOpSub() public {
        UFixed a = UFixed.wrap(1 * 10 ** 18);
        UFixed b = UFixed.wrap(1 * 10 ** 18);
        UFixed c = UFixed.wrap(2 * 10 ** 18);
        UFixed d = UFixed.wrap(3 * 10 ** 18);
        assertTrue((c - b) == a);
        assertTrue(c.sub(b) == a);

        assertTrue((d - c) == a);
        assertTrue(d.sub(c) == a);
        assertFalse((d - b) == b);
        assertFalse(d.sub(b) == b);

        UFixed e = UFixed.wrap(0 * 10 ** 18);
        assertTrue((a - a) == e);
        assertTrue(a.sub(a) == e);
        assertTrue((a - e) == a);
        assertTrue(a.sub(e) == a);
        assertTrue((e - e) == e);
        assertTrue(e.sub(e) == e);

        vm.expectRevert("ERROR:UFM-010:NEGATIVE_RESULT");
        a - c;
        vm.expectRevert("ERROR:UFM-010:NEGATIVE_RESULT");
        a.sub(c);
    }

    function testOpMul() public {
        // 1 * 1 = 1
        UFixed a = UFixed.wrap(1 * 10 ** 18);
        UFixed b = UFixed.wrap(1 * 10 ** 18);
        UFixed c = UFixed.wrap(1 * 10 ** 18);
        assertTrue((a * b) == c);
        assertTrue(a.mul(b).eq(c));

        // 1 * 2 = 2
        UFixed d = UFixed.wrap(2 * 10 ** 18);
        assertTrue((a * d) == d);
        assertTrue(a.mul(d).eq(d));

        // 2 * 2 = 4
        UFixed e = UFixed.wrap(4 * 10 ** 18);
        assertTrue((d * d) == e);
        assertTrue(d.mul(d).eq(e));
        assertFalse((a * d) == e);
        assertFalse(a.mul(d).eq(e));

        // 2 * 21 = 42
        UFixed f = UFixed.wrap(21 * 10 ** 18);
        UFixed g = UFixed.wrap(42 * 10 ** 18);
        assertTrue((d * f) == g);
        assertTrue(d.mul(f).eq(g));
    }

    function testOpMulFrac() public {
        // 1 * 0.5 = 0.5
        UFixed a = UFixed.wrap(1 * 10 ** 18);
        UFixed b = UFixed.wrap(5 * 10 ** 17);

        assertTrue((a * b) == b);
        assertTrue((a.mul(b)).eq(b));
        assertTrue((b * a) == b);
        assertTrue((b.mul(a)).eq(b));

        // 0.5 * 0.5 = 0.25
        UFixed c = UFixed.wrap(25 * 10 ** 16);
        assertTrue((b * b) == c);
        assertTrue((b.mul(b)).eq(c));
    }

    function testOpMulBig() public {
        UFixed a = UFixed.wrap(1 * 10 ** 18);
        UFixed d = UFixed.wrap(2 * 10 ** 18);

        // bigUFixed * 1 = bigUFixed
        // bigUFixed = 1 * 10 ** 31
        UFixed bigUFixed = UFixed.wrap(1 * 10 ** 32 - 1);
        assertTrue((bigUFixed * a) == bigUFixed);
        assertTrue((bigUFixed.mul(a)).eq(bigUFixed));

        assertTrue((bigUFixed * d) == (bigUFixed + bigUFixed));
        assertTrue((bigUFixed.mul(d)).eq(bigUFixed + bigUFixed));
    }

    function testOpMulZero() public {
        UFixed a = UFixed.wrap(1 * 10 ** 18);
        UFixed b = UFixed.wrap(1 * 10 ** 18);

        // 1 * 0 = 0
        UFixed z = UFixed.wrap(0 * 10 ** 18);
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
        UFixed a = UFixed.wrap(1 * 10 ** 18);
        UFixed b = UFixed.wrap(1 * 10 ** 18);
        UFixed c = UFixed.wrap(1 * 10 ** 18);
        assertTrue((a / b) == c);
        assertTrue(a.div(b).eq(c));

        // 2 / 1 = 2
        UFixed d = UFixed.wrap(2 * 10 ** 18);
        assertTrue((d / a) == d);
        assertTrue(d.div(a).eq(d));

        // 2 / 2 = 1
        assertTrue((d / d) == b);
        assertTrue(d.div(d).eq(b));

        // 4 / 2 = 2
        UFixed e = UFixed.wrap(4 * 10 ** 18);
        assertTrue((e / d) == d);
        assertTrue(e.div(d).eq(d));

        // 42 / 2 = 21
        UFixed f = UFixed.wrap(21 * 10 ** 18);
        UFixed g = UFixed.wrap(42 * 10 ** 18);
        assertTrue((g / d) == f);
        assertTrue(g.div(d).eq(f));
    }

    function testOpDivFrac() public {
        UFixed d = UFixed.wrap(2 * 10 ** 18);

        // 5 / 2 = 2.5
        UFixed f1 = UFixed.wrap(5 * 10 ** 18);
        UFixed ex1 = UFixed.wrap(2.5 * 10 ** 18);
        assertTrue((f1 / d) == ex1);
        assertTrue(f1.div(d).eq(ex1));

        // 2 / 5 = 0.4
        UFixed ex2 = UFixed.wrap(0.4 * 10 ** 18);
        assertTrue((d / f1) == ex2);
        assertTrue(d.div(f1).eq(ex2));

        // 2 / 0.5 = 4
        UFixed f2 = UFixed.wrap(5 * 10 ** 17);
        UFixed ex3 = UFixed.wrap(4 * 10 ** 18);
        assertTrue((d / f2) == ex3);
        assertTrue(d.div(f2).eq(ex3));

        // 0.5 / 2 = 0.25
        UFixed ex4 = UFixed.wrap(25 * 10 ** 16);
        assertTrue((f2 / d) == ex4);
        assertTrue(f2.div(d).eq(ex4));
    }

    function testOpDivBig() public {
        UFixed a = UFixed.wrap(1 * 10 ** 18);
        UFixed d = UFixed.wrap(2 * 10 ** 18);

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
        UFixed a = UFixed.wrap(1 * 10 ** 18);

        // 0 / 1 = 0
        UFixed z = UFixed.wrap(0 * 10 ** 18);
        assertTrue((z / a) == z);
        assertTrue(z.div(a).eq(z));

        // 0 / 0 = 0
        vm.expectRevert("ERROR:UFM-020:DIVISOR_ZERO");
        assertTrue((z / z) == z);
        vm.expectRevert("ERROR:UFM-020:DIVISOR_ZERO");
        assertTrue(z.div(z).eq(z));

        // 1 / 0 = 0
        vm.expectRevert("ERROR:UFM-020:DIVISOR_ZERO");
        assertTrue((a / z) == z);
        vm.expectRevert("ERROR:UFM-020:DIVISOR_ZERO");
        assertTrue(a.div(z).eq(z));
    }

    function testOpGt() public {
        UFixed a = UFixed.wrap(1 * 10 ** 18);
        UFixed b = UFixed.wrap(1 * 10 ** 18);
        UFixed c = UFixed.wrap(2 * 10 ** 18);
        assertTrue(c > b);
        assertTrue(c.gt(b));
        assertFalse(a > b);
        assertFalse(a.gt(b));
    }

    function testOpGte() public {
        UFixed a = UFixed.wrap(1 * 10 ** 18);
        UFixed b = UFixed.wrap(1 * 10 ** 18);
        UFixed c = UFixed.wrap(2 * 10 ** 18);
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
        UFixed a = UFixed.wrap(1 * 10 ** 18);
        UFixed b = UFixed.wrap(1 * 10 ** 18);
        UFixed c = UFixed.wrap(2 * 10 ** 18);
        assertTrue(a < c);
        assertTrue(a.lt(c));
        assertFalse(b < a);
        assertFalse(b.lt(a));
    }

    function testOpLte() public {
        UFixed a = UFixed.wrap(1 * 10 ** 18);
        UFixed b = UFixed.wrap(1 * 10 ** 18);
        UFixed c = UFixed.wrap(2 * 10 ** 18);
        assertTrue(a <= c);
        assertTrue(a.lte(c));
        assertTrue(b <= a);
        assertTrue(b.lte(a));
        assertFalse(c <= b);
        assertFalse(c.lte(b));
    }

    function testGtz() public {
        UFixed a = UFixed.wrap(1 * 10 ** 18);
        UFixed b = UFixed.wrap(0 * 10 ** 18);
        assertTrue(a.gtz());
        assertFalse(b.gtz());
    }

    function testEqz() public {
        UFixed a = UFixed.wrap(1 * 10 ** 18);
        UFixed b = UFixed.wrap(0 * 10 ** 18);
        assertFalse(a.eqz());
        assertTrue(b.eqz());
    }

    function testDelta() public {
        UFixed a = UFixed.wrap(1 * 10 ** 18);
        UFixed b = UFixed.wrap(0 * 10 ** 18);
        assertTrue(a.delta(b).eq(UFixedMathLib.toUFixed(1)));
        assertTrue(b.delta(a).eq(UFixedMathLib.toUFixed(1)));

        UFixed c = UFixed.wrap(2 * 10 ** 18);
        assertTrue(c.delta(a).eq(UFixedMathLib.toUFixed(1)));
        assertTrue(a.delta(c).eq(UFixedMathLib.toUFixed(1)));

        assertTrue(c.delta(b).eq(UFixedMathLib.toUFixed(2)));
        assertTrue(b.delta(c).eq(UFixedMathLib.toUFixed(2)));
    }
}
