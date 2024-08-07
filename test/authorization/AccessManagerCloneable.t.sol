// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccessManaged} from "../../lib/openzeppelin-contracts/contracts/access/manager/IAccessManaged.sol";
import {Test, console} from "../../lib/forge-std/src/Test.sol";

import {VersionPart, VersionPartLib} from "../../contracts/type/Version.sol";

import {AccessManagerCloneable} from "../../contracts/authorization/AccessManagerCloneable.sol";

import {RegistryAdmin} from "../../contracts/registry/RegistryAdmin.sol";
import {Registry} from "../../contracts/registry/Registry.sol";

import {AccessManagedMock} from "../mock/AccessManagedMock.sol";

contract AccessManagerCloneableTest is Test {
    
    address globalRegistry = makeAddr("globalRegistry");
    address admin = makeAddr("accessManagerAdmin");
    address accessManagedCaller = makeAddr("accessManagedCaller");
    address outsider = makeAddr("outsider");


    RegistryAdmin registryAdmin;
    Registry registry;
    AccessManagerCloneable accessManager;
    AccessManagedMock accessManaged;

    function setUp() public 
    {
        registryAdmin = new RegistryAdmin();
        registry = new Registry(registryAdmin, globalRegistry);

        accessManager = new AccessManagerCloneable();
        accessManager.initialize(admin);

        VersionPart version = VersionPartLib.toVersionPart(3);
        vm.prank(admin);
        accessManager.completeSetup(address(registry), version);

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

    function test_accessManagerCloneable_lockRelease_byUnauthorizedCaller() public {
        assertFalse(accessManager.isLocked(), "Release should be unlocked");

        vm.expectRevert(abi.encodeWithSelector(AccessManagerCloneable.ErrorAccessManagerCallerNotAdmin.selector, accessManagedCaller));
        vm.prank(accessManagedCaller);
        accessManager.setLocked(true);


        vm.expectRevert(abi.encodeWithSelector(AccessManagerCloneable.ErrorAccessManagerCallerNotAdmin.selector, outsider));
        vm.prank(accessManagedCaller);
        accessManager.setLocked(true);
    }

    function test_accessManagerCloneable_unlockRelease_byUnauthorizedCaller() public {
        assertFalse(accessManager.isLocked(), "Release should be unlocked");

        vm.expectRevert(abi.encodeWithSelector(AccessManagerCloneable.ErrorAccessManagerCallerNotAdmin.selector, accessManagedCaller));
        vm.prank(accessManagedCaller);
        accessManager.setLocked(false);

        vm.expectRevert(abi.encodeWithSelector(AccessManagerCloneable.ErrorAccessManagerCallerNotAdmin.selector, outsider));
        vm.prank(accessManagedCaller);
        accessManager.setLocked(false);
    }

    function test_accessManagerCloneable_lockRelease_whenReleaseUnlockedHappyCase() public {
        assertFalse(accessManager.isLocked(), "Release should be unlocked");

        vm.prank(admin);
        accessManager.setLocked(true);

        assertTrue(accessManager.isLocked(), "Release should be locked");
    }

    function test_accessManagerCloneable_lockRelease_whenReleaseLockedHappyCase() public {
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

    function test_accessManagerCloneable_unlockRelease_whenReleaseLockedHappyCase() public {
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

    function test_accessManagerCloneable_unlockRelease_whenReleaseUnlockedHappyCase() public {
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

    function test_accessManagerCloneable_callAccessManaged_whenReleaseUnlockedHappyCase() public {
        assertFalse(accessManager.isLocked(), "Release should be unlocked");

        vm.prank(accessManagedCaller);
        accessManaged.increaseCounter1();
        assertEq(accessManaged.counter1(), 1);
    }

    function test_accessManagerCloneable_callAccessManaged_whenReleaseLocked() public {
        assertFalse(accessManager.isLocked(), "Release should be unlocked");

        // call before lock
        vm.prank(accessManagedCaller);
        accessManaged.increaseCounter1();

        // lock
        vm.prank(admin);
        accessManager.setLocked(true);

        // call after lock
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, accessManagedCaller));
        vm.prank(accessManagedCaller);
        accessManaged.increaseCounter1();
    }

    function test_accessManagerCloneable_callAccessManaged_whenReleaseUnlocked_byUnauthorizedCaller() public {
        assertFalse(accessManager.isLocked(), "Release should be unlocked");

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, admin));
        accessManaged.increaseCounter1();

        vm.prank(outsider);
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, outsider));
        accessManaged.increaseCounter1();
    }
}