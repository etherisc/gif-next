// SPDX-License-Identifier: APACHE-2.0
pragma solidity ^0.8.20;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {console} from "../../lib/forge-std/src/Test.sol";

import {IAccessAdmin} from "../../contracts/authorization/IAccessAdmin.sol";
import {IComponentService} from "../../contracts/shared/IComponentService.sol";
import {IInstance} from "../../contracts/instance/IInstance.sol";
import {IInstanceService} from "../../contracts/instance/IInstanceService.sol";
import {INftOwnable} from "../../contracts/shared/INftOwnable.sol";

import {Amount, AmountLib} from "../../contracts/type/Amount.sol";
import {Fee, FeeLib} from "../../contracts/type/Fee.sol";
import {GifTest} from "../base/GifTest.sol";
import {InstanceAdmin} from "../../contracts/instance/InstanceAdmin.sol";
import {InstanceReader} from "../../contracts/instance/InstanceReader.sol";
import {NftId} from "../../contracts/type/NftId.sol";
import {UFixed, UFixedLib} from "../../contracts/type/UFixed.sol";

contract TestInstance is GifTest {


    Amount public MAX_AMOUNT;


    function setUp() public override {
        super.setUp();
        _prepareProduct(); // also deploys and registers distribution

        MAX_AMOUNT = AmountLib.max();
    }


    function test_instanceSetSetUp() public {
        // GIVEN setup

        assertEq(masterInstance.getRelease().toInt(), 3, "unexpected master instance release");
        assertEq(instance.getRelease().toInt(), 3, "unexpected instance release");

        assertEq(instance.getOwner(), instanceOwner, "unexpected instance owner");

        assertFalse(instance.isInstanceLocked(), "instance is locked");
        assertFalse(instance.isTargetLocked(address(pool)), "pool is locked");
        assertFalse(instance.isTargetLocked(address(distribution)), "distribution is locked");

        _printAuthz(instance.getInstanceAdmin(), "instance");
    }


    function test_instanceSetInstanceLockedInvalidCaller() public { 
        // GIVEN just setup

        // WHEN + THEN
        vm.expectRevert(abi.encodeWithSelector(INftOwnable.ErrorNftOwnableNotOwner.selector, poolOwner));

        vm.prank(poolOwner);
        instance.setInstanceLocked(true);
    }


    function test_instanceSetInstanceLockedLock() public { 
        // GIVEN just setup

        // WHEN 
        vm.prank(instanceOwner);
        instance.setInstanceLocked(true);

        // THEN
        assertTrue(instance.isInstanceLocked(), "instance is not locked");
        assertFalse(instance.isTargetLocked(address(pool)), "pool is locked");
        assertFalse(instance.isTargetLocked(address(distribution)), "distribution is locked");

        // WHEN + THEN
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(poolOwner)));
        
        vm.prank(poolOwner);
        pool.withdrawFees(MAX_AMOUNT);
    }


    function test_instanceSetInstanceLockedUnlock() public { 
        // GIVEN just setup

        // WHEN 
        vm.startPrank(instanceOwner);
        instance.setInstanceLocked(true);
        instance.setInstanceLocked(false);
        vm.stopPrank();

        // THEN
        assertFalse(instance.isInstanceLocked(), "instance is locked");
        assertFalse(instance.isTargetLocked(address(pool)), "pool is locked");
        assertFalse(instance.isTargetLocked(address(distribution)), "distribution is locked");

        // WHEN + THEN
        vm.expectRevert(abi.encodeWithSelector(IComponentService.ErrorComponentServiceWithdrawAmountIsZero.selector));
        
        vm.startPrank(poolOwner);
        pool.withdrawFees(MAX_AMOUNT);
    }


    function test_instanceSetTargetLockedWhileInstanceIsLocked() public {
        // GIVEN locked instance

        vm.prank(instanceOwner);
        instance.setInstanceLocked(true);

        assertTrue(instance.isInstanceLocked(), "instance is not locked (before)");
        assertFalse(instance.isTargetLocked(address(pool)), "pool is locked (before)");

        // WHEN  lock pool while instance is locked
        vm.prank(instanceOwner);
        instance.setTargetLocked(address(pool), true);

        // THEN
        assertTrue(instance.isInstanceLocked(), "instance is not locked (after 1)");
        assertTrue(instance.isTargetLocked(address(pool)), "pool is not locked (after 1)");

        // WHEN  unlock pool while instance is locked
        vm.prank(instanceOwner);
        instance.setTargetLocked(address(pool), false);

        // THEN
        assertTrue(instance.isInstanceLocked(), "instance is not locked (after 2)");
        assertFalse(instance.isTargetLocked(address(pool)), "pool is locked (after 2)");
    }


    function test_instanceSetTargetLockedInvalidCaller() public {
        // GIVEN

        vm.startPrank(address(this));

        // THEN
        vm.expectRevert(abi.encodeWithSelector(INftOwnable.ErrorNftOwnableNotOwner.selector, address(this)));

        // WHEN
        instance.setTargetLocked(address(distribution), true);
    }



    function test_instanceSetTargetLockedLock() public {
        // GIVEN
        Fee memory newDistributionFee = FeeLib.toFee(UFixedLib.toUFixed(123,0), 456);
        Fee memory newMinDistributionOwnerFee = FeeLib.toFee(UFixedLib.toUFixed(124,0), 457);

        vm.startPrank(instanceOwner);
        instance.setTargetLocked(address(distribution), true);
        vm.stopPrank();

        assertFalse(instance.isInstanceLocked(), "instance is locked");
        assertTrue(instance.isTargetLocked(address(distribution)), "distribution is not locked");

        // WHEN + THEN
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(distributionOwner)));
        
        vm.startPrank(distributionOwner);
        distribution.setFees(newMinDistributionOwnerFee, newDistributionFee);        
    }


    function test_instanceSetTargetLockedUnlock() public {
        // GIVEN
        Fee memory newDistributionFee = FeeLib.toFee(UFixedLib.toUFixed(123,0), 456);
        Fee memory newMinDistributionOwnerFee = FeeLib.toFee(UFixedLib.toUFixed(124,0), 457);

        vm.startPrank(instanceOwner);
        instance.setTargetLocked(address(distribution), true);
        instance.setTargetLocked(address(distribution), false);
        vm.stopPrank();

        assertFalse(instance.isInstanceLocked(), "instance is locked");
        assertFalse(instance.isTargetLocked(address(distribution)), "distribution is not locked");

        // THEN - WHEN - make sure no revert
        vm.startPrank(distributionOwner);
        distribution.setFees(newMinDistributionOwnerFee, newDistributionFee);        
    }

    function test_instanceSetTargetLockedInvalidTarget() public {
        // GIVEN

        // THEN
        vm.expectRevert(abi.encodeWithSelector(IAccessAdmin.ErrorAccessAdminTargetNotCreated.selector, address(this)));

        // WHEN
        vm.startPrank(instanceOwner);
        instance.setTargetLocked(address(this), true);
    }
}
