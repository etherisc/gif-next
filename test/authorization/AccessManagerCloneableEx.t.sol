// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccessManaged} from "../../lib/openzeppelin-contracts/contracts/access/manager/IAccessManaged.sol";
import {Test, console} from "../../lib/forge-std/src/Test.sol";


import {AccessManagerCloneable} from "../../contracts/authorization/AccessManagerCloneable.sol";
import {AccessManagedMock} from "../mock/AccessManagedMock.sol";
import {VersionPart, VersionPartLib} from "../../contracts/type/Version.sol";


contract AccessManagerCloneableExtendedTest is Test {
    
    address public globalRegistry = makeAddr("globalRegistry");
    address public accessManagedCaller = makeAddr("accessManagedCaller");
    address public outsider = makeAddr("outsider");

    address public admin = makeAddr("accessManagerAdmin");
    AccessManagerCloneable public accessManager;

    AccessManagedMock accessManaged;

    function setUp() public {
        VersionPart release = VersionPartLib.toVersionPart(3);
        accessManager = new AccessManagerCloneable();
        accessManager.initialize(admin, release);

        //vm.prank(admin);
        //accessManager.completeSetup(address(registry));

        accessManaged = new AccessManagedMock(address(accessManager));

        // set role 1 for accessManaged.incrementCounter1()
        bytes4[] memory selector = new bytes4[](1);
        selector[0] = AccessManagedMock.increaseCounter1.selector;
        vm.prank(admin);
        accessManager.setTargetFunctionRole(address(accessManaged), selector, 1);

        // grant role 1 to accessManagedCaller
        vm.prank(admin);
        accessManager.grantRole(1, accessManagedCaller, 0);
    }

    function test_accessManagerCloneableLockReleaseByUnauthorizedCaller() public {
        assertFalse(accessManager.isLocked(), "Release should be unlocked");

        vm.expectRevert(abi.encodeWithSelector(AccessManagerCloneable.ErrorAccessManagerCallerNotAdmin.selector, accessManagedCaller));
        vm.prank(accessManagedCaller);
        accessManager.setLocked(true);

        vm.expectRevert(abi.encodeWithSelector(AccessManagerCloneable.ErrorAccessManagerCallerNotAdmin.selector, outsider));
        vm.prank(outsider);
        accessManager.setLocked(true);
    }

    function test_accessManagerCloneableUnlockReleaseByUnauthorizedCaller() public {
        assertFalse(accessManager.isLocked(), "Release should be unlocked");

        vm.expectRevert(abi.encodeWithSelector(AccessManagerCloneable.ErrorAccessManagerCallerNotAdmin.selector, accessManagedCaller));
        vm.prank(accessManagedCaller);
        accessManager.setLocked(false);

        vm.expectRevert(abi.encodeWithSelector(AccessManagerCloneable.ErrorAccessManagerCallerNotAdmin.selector, outsider));
        vm.prank(outsider);
        accessManager.setLocked(false);
    }

    function test_accessManagerCloneableLockReleaseWhenReleaseUnlockedHappyCase() public {
        assertFalse(accessManager.isLocked(), "Release should be unlocked");

        vm.prank(admin);
        accessManager.setLocked(true);

        assertTrue(accessManager.isLocked(), "Release should be locked");

        assertEq(accessManaged.counter1(), 0, "unexpected counter value (before)");

        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, accessManagedCaller));
        vm.prank(accessManagedCaller);
        accessManaged.increaseCounter1();

        assertEq(accessManaged.counter1(), 0, "unexpected counter value (after)");
    }

    function test_accessManagerCloneableLockReleaseWhenReleaseLockedHappyCase() public {
        assertFalse(accessManager.isLocked(), "Release should be unlocked");

        // first lock
        vm.prank(admin);
        accessManager.setLocked(true);

        assertTrue(accessManager.isLocked(), "Release should be locked");

        // second lock
        vm.prank(admin);
        accessManager.setLocked(true);

        assertTrue(accessManager.isLocked(), "Release should be locked");

        // call after second lock
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, accessManagedCaller));
        vm.prank(accessManagedCaller);
        accessManaged.increaseCounter1();
    }

    function test_accessManagerCloneableUnlockReleaseWhenReleaseLockedHappyCase() public {
        assertFalse(accessManager.isLocked(), "Release should be unlocked");

        // lock
        vm.prank(admin);
        accessManager.setLocked(true);

        assertTrue(accessManager.isLocked(), "Release should be locked");

        // unlock
        vm.prank(admin);
        accessManager.setLocked(false);

        assertFalse(accessManager.isLocked(), "Release should be unlocked");

        // call after unlock
        vm.prank(accessManagedCaller);
        accessManaged.increaseCounter1();
        assertEq(accessManaged.counter1(), 1);
    }

    function test_accessManagerCloneableUnlockReleaseWhenReleaseUnlockedHappyCase() public {
        assertFalse(accessManager.isLocked(), "Release should be unlocked");

        // lock
        vm.prank(admin);
        accessManager.setLocked(true);

        // first unlock
        vm.prank(admin);
        accessManager.setLocked(false);

        // second unlock
        vm.prank(admin);
        accessManager.setLocked(false);

        assertFalse(accessManager.isLocked(), "Release should be unlocked");

        // call after second unlock
        vm.prank(accessManagedCaller);
        accessManaged.increaseCounter1();
        assertEq(accessManaged.counter1(), 1);
    }

    function test_accessManagerCloneableCallAccessManagedWhenReleaseUnlockedHappyCase() public {
        assertFalse(accessManager.isLocked(), "Release should be unlocked");

        vm.prank(accessManagedCaller);
        accessManaged.increaseCounter1();
        assertEq(accessManaged.counter1(), 1);
    }

    function test_accessManagerCloneableCallAccessManagedWhenReleaseLocked() public {
        assertFalse(accessManager.isLocked(), "Release should be unlocked");

        assertEq(accessManaged.counter1(), 0, "unexpected counter value (before)");

        // call before lock
        vm.prank(accessManagedCaller);
        accessManaged.increaseCounter1();

        assertEq(accessManaged.counter1(), 1, "unexpected counter value (after)");

        // lock
        vm.prank(admin);
        accessManager.setLocked(true);

        // call after lock
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessManaged.AccessManagedUnauthorized.selector, 
                accessManagedCaller));

        vm.prank(accessManagedCaller);
        accessManaged.increaseCounter1();
    }

    function test_accessManagerCloneableCallAccessManagedWhenReleaseUnlocked_byUnauthorizedCaller() public {
        assertFalse(accessManager.isLocked(), "Release should be unlocked");

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, admin));
        accessManaged.increaseCounter1();

        vm.prank(outsider);
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, outsider));
        accessManaged.increaseCounter1();
    }
}