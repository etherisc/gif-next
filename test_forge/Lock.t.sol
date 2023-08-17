// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import "../lib/forge-std/src/Test.sol";
import "../contracts/Lock.sol";

contract LockTest is Test {
    Lock lock;
    uint ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60;
    uint ONE_GWEI = 1000000000;
    address alice; 
    address bob;

    function setUp() public {
        alice = makeAddr("alice"); 
        bob = makeAddr("bob");
    }

    function test_withdraw_not_allowed() public {
        lock = new Lock(block.timestamp + ONE_YEAR_IN_SECS);

        vm.expectRevert("You can't withdraw yet");
        lock.withdraw();
    }

    function test_withdraw_success() public {
        // deploy with 100 eth and lock for one year
        hoax(alice, 100 ether);
        lock = new Lock(block.timestamp + ONE_YEAR_IN_SECS);

        // skip one year and 7 seconds, then withdraw
        skip(ONE_YEAR_IN_SECS + 7);
        vm.prank(alice);
        lock.withdraw();
    }

    function test_withdraw_invalid_sender() public {
        // deploy with 100 eth and lock for one year
        hoax(alice, 100 ether);
        lock = new Lock(block.timestamp + ONE_YEAR_IN_SECS);

        // skip one year and 7 seconds, then withdraw
        skip(ONE_YEAR_IN_SECS + 7);
        vm.prank(bob);

        vm.expectRevert("You aren't the owner");
        lock.withdraw();
    }

}
