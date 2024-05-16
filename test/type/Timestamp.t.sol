// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Test} from "../../lib/forge-std/src/Test.sol";
import "../../contracts/type/Timestamp.sol";

contract TimestampTest is Test {
    using TimestampLib for Timestamp;

    Timestamp ts1;
    Timestamp ts2;
    Timestamp ts3;

    function setUp() public {
        ts1 = toTimestamp(1691321541); // before ts2
        ts2 = toTimestamp(1696321541); // after ts1 and before ts3
        ts3 = toTimestamp(1699321541); // after ts2
    }

    function test_toTimestamp_toInt() public {
        uint40 ts = 1691321541;
        assertEq(toTimestamp(ts).toInt(), ts);
    }

    function test_zeroTimestamp() public {
        assertEq(zeroTimestamp().toInt(), 0);
    }

    function test_blockTimestamp() public {
        uint256 ts = block.timestamp;
        assertEq(TimestampLib.blockTimestamp().toInt(), ts);

        vm.warp(100);

        ts = block.timestamp;
        assertEq(TimestampLib.blockTimestamp().toInt(), ts);

        vm.warp(200);

        assertGt(TimestampLib.blockTimestamp().toInt(), ts);
    }

    function test_op_gt() public {
        assertTrue(ts2 > ts1);
        assertTrue(ts3 > ts2);

        assertFalse(ts1 > ts2);
        assertFalse(ts2 > ts3);
    }

    function test_gtTimestamp() public {
        assertTrue(gtTimestamp(ts2, ts1));
        assertTrue(gtTimestamp(ts3, ts2));

        assertFalse(gtTimestamp(ts1, ts2));
        assertFalse(gtTimestamp(ts2, ts3));
    }

    function test_TimestampLib_gt() public {
        assertTrue(ts2.gt(ts1));
        assertTrue(ts3.gt(ts2));

        assertFalse(ts1.gt(ts2));
        assertFalse(ts2.gt(ts3));
    }

    function test_op_gte() public {
        assertTrue(ts2 >= ts1);
        assertTrue(ts3 >= ts2);

        assertFalse(ts1 >= ts2);
        assertFalse(ts2 >= ts3);
    }

    function test_gteTimestamp() public {
        assertTrue(gteTimestamp(ts2, ts1));
        assertTrue(gteTimestamp(ts3, ts2));

        assertFalse(gteTimestamp(ts1, ts2));
        assertFalse(gteTimestamp(ts2, ts3));
    }

    function test_TimestampLib_gte() public {
        assertTrue(ts2.gte(ts1));
        assertTrue(ts3.gte(ts2));

        assertFalse(ts1.gte(ts2));
        assertFalse(ts2.gte(ts3));
    }

    function test_op_lt() public {
        assertTrue(ts1 < ts2);
        assertTrue(ts2 < ts3);

        assertFalse(ts2 < ts1);
        assertFalse(ts3 < ts2);
    }

    function test_ltTimestamp() public {
        assertTrue(ltTimestamp(ts1, ts2));
        assertTrue(ltTimestamp(ts2, ts3));

        assertFalse(ltTimestamp(ts2, ts1));
        assertFalse(ltTimestamp(ts3, ts2));
    }

    function test_TimestampLib_lt() public {
        assertTrue(ts1.lt(ts2));
        assertTrue(ts2.lt(ts3));

        assertFalse(ts2.lt(ts1));
        assertFalse(ts3.lt(ts2));
    }

    function test_op_lte() public {
        assertTrue(ts1 <= ts2);
        assertTrue(ts2 <= ts3);

        assertFalse(ts2 <= ts1);
        assertFalse(ts3 <= ts2);
    }

    function test_lteTimestamp() public {
        assertTrue(lteTimestamp(ts1, ts2));
        assertTrue(lteTimestamp(ts2, ts3));

        assertFalse(lteTimestamp(ts2, ts1));
        assertFalse(lteTimestamp(ts3, ts2));
    }

    function test_TimestampLib_lte() public {
        assertTrue(ts1.lte(ts2));
        assertTrue(ts2.lte(ts3));

        assertFalse(ts2.lte(ts1));
        assertFalse(ts3.lte(ts2));
    }

    function test_op_eq() public {
        assertTrue(ts1 == ts1);
        assertTrue(ts2 == ts2);
        assertTrue(ts3 == ts3);

        assertFalse(ts1 == ts2);
        assertFalse(ts2 == ts3);
        assertFalse(ts3 == ts1);
    }

    function test_eqTimestamp() public {
        assertTrue(eqTimestamp(ts1, ts1));
        assertTrue(eqTimestamp(ts2, ts2));
        assertTrue(eqTimestamp(ts3, ts3));

        assertFalse(eqTimestamp(ts1, ts2));
        assertFalse(eqTimestamp(ts2, ts3));
        assertFalse(eqTimestamp(ts3, ts1));
    }

    function test_TimestampLib_eq() public {
        assertTrue(ts1.eq(ts1));
        assertTrue(ts2.eq(ts2));
        assertTrue(ts3.eq(ts3));

        assertFalse(ts1.eq(ts2));
        assertFalse(ts2.eq(ts3));
        assertFalse(ts3.eq(ts1));
    }

    function test_op_ne() public {
        assertTrue(ts1 != ts2);
        assertTrue(ts2 != ts3);
        assertTrue(ts3 != ts1);

        assertFalse(ts1 != ts1);
        assertFalse(ts2 != ts2);
        assertFalse(ts3 != ts3);
    }

    function test_neTimestamp() public {
        assertTrue(neTimestamp(ts1, ts2));
        assertTrue(neTimestamp(ts2, ts3));
        assertTrue(neTimestamp(ts3, ts1));

        assertFalse(neTimestamp(ts1, ts1));
        assertFalse(neTimestamp(ts2, ts2));
        assertFalse(neTimestamp(ts3, ts3));
    }

    function test_TimestampLib_ne() public {
        assertTrue(ts1.ne(ts2));
        assertTrue(ts2.ne(ts3));
        assertTrue(ts3.ne(ts1));

        assertFalse(ts1.ne(ts1));
        assertFalse(ts2.ne(ts2));
        assertFalse(ts3.ne(ts3));
    }
}
