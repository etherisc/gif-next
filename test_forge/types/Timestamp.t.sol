// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import { Test } from  "../../lib/forge-std/src/Test.sol";
import "../../contracts/types/Timestamp.sol";

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
        assertEq(blockTimestamp().toInt(), ts);

        vm.warp(100);

        ts = block.timestamp;
        assertEq(blockTimestamp().toInt(), ts);

        vm.warp(200);

        assertGt(blockTimestamp().toInt(), ts);
    }

}
