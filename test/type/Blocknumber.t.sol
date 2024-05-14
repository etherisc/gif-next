// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Test} from "../../lib/forge-std/src/Test.sol";
import "../../contracts/type/Blocknumber.sol";

contract BlocknumberTest is Test {
    using BlocknumberLib for Blocknumber;

    Blocknumber bn1;
    Blocknumber bn2;
    Blocknumber bnZero;

    function setUp() public {
        bn1 = toBlocknumber(42);
        bn2 = toBlocknumber(742);
        bnZero = toBlocknumber(0);
    }

    function test_toBlocknumber_toInt() public {
        uint32 bn = 42;
        assertEq(toBlocknumber(bn).toInt(), bn);
    }

    function test_zeroBlocknumber() public {
        assertEq(zeroBlocknumber().toInt(), 0);
    }

    function test_blockBlocknumber() public {
        uint256 bn = block.number;
        assertEq(blockBlocknumber().toInt(), bn);

        vm.warp(100);

        bn = block.number;
        assertEq(blockBlocknumber().toInt(), bn);
    }

    function test_op_gt() public {
        assertTrue(bn2 > bn1);

        assertFalse(bn1 > bn2);
    }

    function test_gtBlocknumber() public {
        assertTrue(gtBlocknumber(bn2, bn1));

        assertFalse(gtBlocknumber(bn1, bn2));
    }

    function test_BlocknumberLib_gt() public {
        assertTrue(bn2.gt(bn1));
        assertTrue(bn2.gte(bn1));

        assertFalse(bn1.gt(bn2));
        assertFalse(bn1.gte(bn2));
    }

    function test_op_lt() public {
        assertTrue(bn1 < bn2);

        assertFalse(bn2 < bn1);
    }

    function test_ltBlocknumber() public {
        assertTrue(ltBlocknumber(bn1, bn2));

        assertFalse(ltBlocknumber(bn2, bn1));
    }

    function test_BlocknumberLib_lt() public {
        assertTrue(bn1.lt(bn2));
        assertTrue(bn1.lte(bn2));

        assertFalse(bn2.lt(bn1));
        assertFalse(bn2.lte(bn1));
    }

    function test_op_gte() public {
        assertTrue(bn2 >= bn1);

        assertFalse(bn1 >= bn2);
    }

    function test_gteBlocknumber() public {
        assertTrue(gteBlocknumber(bn2, bn1));

        assertFalse(gteBlocknumber(bn1, bn2));
    }

    function test_BlocknumberLib_gte() public {
        assertTrue(bn2.gte(bn1));

        assertFalse(bn1.gte(bn2));
    }

    function test_op_lte() public {
        assertTrue(bn1 <= bn2);

        assertFalse(bn2 <= bn1);
    }

    function test_lteBlocknumber() public {
        assertTrue(lteBlocknumber(bn1, bn2));

        assertFalse(lteBlocknumber(bn2, bn1));
    }

    function test_BlocknumberLib_lte() public {
        assertTrue(bn1.lte(bn2));

        assertFalse(bn2.lte(bn1));
    }

    function test_op_eq() public {
        assertTrue(bn1 == bn1);
        assertTrue(bn2 == bn2);

        assertTrue(bnZero == bnZero);

        assertFalse(bn1 == bn2);
        assertFalse(bn2 == bn1);

        assertFalse(bn1 == bnZero);
        assertFalse(bn2 == bnZero);

        assertFalse(bnZero == bn1);
        assertFalse(bnZero == bn2);
    }

    function test_eqBlocknumber() public {
        assertTrue(eqBlocknumber(bn1, bn1));
        assertTrue(eqBlocknumber(bn2, bn2));

        assertTrue(eqBlocknumber(bnZero, bnZero));

        assertFalse(eqBlocknumber(bn1, bn2));
        assertFalse(eqBlocknumber(bn2, bn1));

        assertFalse(eqBlocknumber(bn1, bnZero));
        assertFalse(eqBlocknumber(bn2, bnZero));

        assertFalse(eqBlocknumber(bnZero, bn1));
        assertFalse(eqBlocknumber(bnZero, bn2));
    }

    function test_BlocknumberLib_eq() public {
        assertTrue(bn1.eq(bn1));
        assertTrue(bn2.eq(bn2));

        assertTrue(bnZero.eq(bnZero));

        assertFalse(bn1.eq(bn2));
        assertFalse(bn2.eq(bn1));

        assertFalse(bn1.eq(bnZero));
        assertFalse(bn2.eq(bnZero));

        assertFalse(bnZero.eq(bn1));
        assertFalse(bnZero.eq(bn2));
    }

    function test_op_ne() public {
        assertTrue(bn1 != bn2);
        assertTrue(bn2 != bn1);

        assertTrue(bn1 != bnZero);
        assertTrue(bn2 != bnZero);

        assertTrue(bnZero != bn1);
        assertTrue(bnZero != bn2);

        assertFalse(bn1 != bn1);
        assertFalse(bn2 != bn2);

        assertFalse(bnZero != bnZero);
    }

    function test_neBlocknumber() public {
        assertTrue(neBlocknumber(bn1, bn2));
        assertTrue(neBlocknumber(bn2, bn1));

        assertTrue(neBlocknumber(bn1, bnZero));
        assertTrue(neBlocknumber(bn2, bnZero));

        assertTrue(neBlocknumber(bnZero, bn1));
        assertTrue(neBlocknumber(bnZero, bn2));

        assertFalse(neBlocknumber(bn1, bn1));
        assertFalse(neBlocknumber(bn2, bn2));

        assertFalse(neBlocknumber(bnZero, bnZero));
    }

    function test_BlocknumberLib_ne() public {
        assertTrue(bn1.ne(bn2));
        assertTrue(bn2.ne(bn1));

        assertTrue(bn1.ne(bnZero));
        assertTrue(bn2.ne(bnZero));

        assertTrue(bnZero.ne(bn1));
        assertTrue(bnZero.ne(bn2));

        assertFalse(bn1.ne(bn1));
        assertFalse(bn2.ne(bn2));

        assertFalse(bnZero.ne(bnZero));
    }

    function test_BlocknumberLib_toInt() public {
        assertEq(bn1.toInt(), 42);
        assertEq(bn2.toInt(), 742);
    }
}
