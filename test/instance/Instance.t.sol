// SPDX-License-Identifier: APACHE-2.0
pragma solidity ^0.8.20;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {Fee, FeeLib} from "../../contracts/type/Fee.sol";
import {GifTest} from "../base/GifTest.sol";
import {IAccessAdmin} from "../../contracts/authorization/IAccessAdmin.sol";
import {IInstance} from "../../contracts/instance/IInstance.sol";
import {IInstanceService} from "../../contracts/instance/IInstanceService.sol";
import {InstanceAdmin} from "../../contracts/instance/InstanceAdmin.sol";
import {InstanceReader} from "../../contracts/instance/InstanceReader.sol";
import {NftId} from "../../contracts/type/NftId.sol";
import {UFixed, UFixedLib} from "../../contracts/type/UFixed.sol";
import {INftOwnable} from "../../contracts/shared/INftOwnable.sol";

contract TestInstance is GifTest {

    function setUp() public override {
        super.setUp();
        _prepareProduct(); // also deploys and registers distribution
    }

    function test_Instance_setLocked_invalidCaller() public {
        // GIVEN
        Fee memory newDistributionFee = FeeLib.toFee(UFixedLib.toUFixed(123,0), 456);
        Fee memory newMinDistributionOwnerFee = FeeLib.toFee(UFixedLib.toUFixed(124,0), 457);

        vm.startPrank(address(this));

        // THEN
        vm.expectRevert(abi.encodeWithSelector(INftOwnable.ErrorNftOwnableNotOwner.selector, address(this)));

        // WHEN
        instance.setLocked(address(distribution), true);
    }
    
    function test_Instance_setLocked_lock() public {
        // GIVEN
        Fee memory newDistributionFee = FeeLib.toFee(UFixedLib.toUFixed(123,0), 456);
        Fee memory newMinDistributionOwnerFee = FeeLib.toFee(UFixedLib.toUFixed(124,0), 457);

        vm.startPrank(instanceOwner);
        instance.setLocked(address(distribution), true);
        vm.stopPrank();

        vm.startPrank(distributionOwner);

        // THEN
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(distributionOwner)));
        
        // WHEN
        distribution.setFees(newMinDistributionOwnerFee, newDistributionFee);        
    }

    function test_Instance_setLocked_unlock() public {
        // GIVEN
        Fee memory newDistributionFee = FeeLib.toFee(UFixedLib.toUFixed(123,0), 456);
        Fee memory newMinDistributionOwnerFee = FeeLib.toFee(UFixedLib.toUFixed(124,0), 457);

        vm.startPrank(instanceOwner);
        instance.setLocked(address(distribution), true);
        instance.setLocked(address(distribution), false);
        vm.stopPrank();

        vm.startPrank(distributionOwner);

        // THEN - WHEN - make sure no revert
        distribution.setFees(newMinDistributionOwnerFee, newDistributionFee);        
    }

    function test_Instance_setLocked_invalidTarget() public {
        // GIVEN
        Fee memory newDistributionFee = FeeLib.toFee(UFixedLib.toUFixed(123,0), 456);
        Fee memory newMinDistributionOwnerFee = FeeLib.toFee(UFixedLib.toUFixed(124,0), 457);

        vm.startPrank(instanceOwner);

        // THEN
        vm.expectRevert(abi.encodeWithSelector(IAccessAdmin.ErrorTargetUnknown.selector, address(this)));

        // WHEN
        instance.setLocked(address(this), true);
    }

    function test_Instance_setLocked_alreadyLocked() public {
        // GIVEN
        Fee memory newDistributionFee = FeeLib.toFee(UFixedLib.toUFixed(123,0), 456);
        Fee memory newMinDistributionOwnerFee = FeeLib.toFee(UFixedLib.toUFixed(124,0), 457);

        vm.startPrank(instanceOwner);
        instance.setLocked(address(distribution), true);

        // THEN
        vm.expectRevert(abi.encodeWithSelector(IAccessAdmin.ErrorTargetAlreadyLocked.selector, address(distribution), true));

        // WHEN
        instance.setLocked(address(distribution), true);
    }

    function test_Instance_setLocked_alreadyUnlocked() public {
        // GIVEN
        Fee memory newDistributionFee = FeeLib.toFee(UFixedLib.toUFixed(123,0), 456);
        Fee memory newMinDistributionOwnerFee = FeeLib.toFee(UFixedLib.toUFixed(124,0), 457);

        vm.startPrank(instanceOwner);
        
        // THEN
        vm.expectRevert(abi.encodeWithSelector(IAccessAdmin.ErrorTargetAlreadyLocked.selector, address(distribution), false));

        // WHEN
        instance.setLocked(address(distribution), false);
    }



    function test_Instance_setLockedFromService_invalidCaller() public {
        // GIVEN
        Fee memory newDistributionFee = FeeLib.toFee(UFixedLib.toUFixed(123,0), 456);
        Fee memory newMinDistributionOwnerFee = FeeLib.toFee(UFixedLib.toUFixed(124,0), 457);

        vm.startPrank(address(this));

        // THEN
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));

        // WHEN
        instance.setLockedFromService(address(distribution), true);
    }

    function test_Instance_setLockedFromService_lock() public {
        // GIVEN
        Fee memory newDistributionFee = FeeLib.toFee(UFixedLib.toUFixed(123,0), 456);
        Fee memory newMinDistributionOwnerFee = FeeLib.toFee(UFixedLib.toUFixed(124,0), 457);

        vm.startPrank(address(componentService));
        instance.setLockedFromService(address(distribution), true);
        vm.stopPrank();

        vm.startPrank(distributionOwner);

        // THEN
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(distributionOwner)));
        
        // WHEN
        distribution.setFees(newMinDistributionOwnerFee, newDistributionFee);        
    }

    function test_Instance_setLockedFromService_unlock() public {
        // GIVEN
        Fee memory newDistributionFee = FeeLib.toFee(UFixedLib.toUFixed(123,0), 456);
        Fee memory newMinDistributionOwnerFee = FeeLib.toFee(UFixedLib.toUFixed(124,0), 457);

        vm.startPrank(address(componentService));
        instance.setLockedFromService(address(distribution), true);
        instance.setLockedFromService(address(distribution), false);
        vm.stopPrank();

        vm.startPrank(distributionOwner);

        // THEN - WHEN - make sure no revert
        distribution.setFees(newMinDistributionOwnerFee, newDistributionFee);        
    }

    function test_Instance_setLockedFromService_invalidTarget() public {
        // GIVEN
        Fee memory newDistributionFee = FeeLib.toFee(UFixedLib.toUFixed(123,0), 456);
        Fee memory newMinDistributionOwnerFee = FeeLib.toFee(UFixedLib.toUFixed(124,0), 457);

        vm.startPrank(address(componentService));

        // THEN
        vm.expectRevert(abi.encodeWithSelector(IAccessAdmin.ErrorTargetUnknown.selector, address(this)));

        // WHEN
        instance.setLockedFromService(address(this), true);
    }

    function test_Instance_setLockedFromService_alreadyLocked() public {
        // GIVEN
        Fee memory newDistributionFee = FeeLib.toFee(UFixedLib.toUFixed(123,0), 456);
        Fee memory newMinDistributionOwnerFee = FeeLib.toFee(UFixedLib.toUFixed(124,0), 457);

        vm.startPrank(address(componentService));
        instance.setLockedFromService(address(distribution), true);

        // THEN
        vm.expectRevert(abi.encodeWithSelector(IAccessAdmin.ErrorTargetAlreadyLocked.selector, address(distribution), true));

        // WHEN
        instance.setLockedFromService(address(distribution), true);
    }

    function test_Instance_setLockedFromService_alreadyUnlocked() public {
        // GIVEN
        Fee memory newDistributionFee = FeeLib.toFee(UFixedLib.toUFixed(123,0), 456);
        Fee memory newMinDistributionOwnerFee = FeeLib.toFee(UFixedLib.toUFixed(124,0), 457);

        vm.startPrank(address(componentService));
        
        // THEN
        vm.expectRevert(abi.encodeWithSelector(IAccessAdmin.ErrorTargetAlreadyLocked.selector, address(distribution), false));

        // WHEN
        instance.setLockedFromService(address(distribution), false);
    }

}
