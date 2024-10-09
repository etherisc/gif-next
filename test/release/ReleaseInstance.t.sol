// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {Vm, console} from "../../lib/forge-std/src/Test.sol";

import {GifTest} from "../base/GifTest.sol";
import {GIF_INITIAL_RELEASE} from "../../contracts/registry/Registry.sol";
import {IInstance} from "../../contracts/instance/IInstance.sol";
import {NftId} from "../../contracts/type/NftId.sol";


contract ReleaseInstanceTest is GifTest {

    function setUp() public override {
        super.setUp();
    }

    function test_releaseInstanceSetUp() public {
        assertTrue(true, "setup failed");
    }

    function test_releaseInstanceCreateActiveInactive() public {
        // GIVEN release active

        vm.startPrank(instanceOwner);
        (
            IInstance newInstance, 
            NftId newInstanceNftId
        ) = instanceService.createInstance(false);
        vm.stopPrank();

        assertTrue(address(newInstance) != address(0), "instance creation failed");
        assertTrue(newInstanceNftId.gtz(), "new instance nft zero");

        // WHEN release is locked
        vm.startPrank(gifAdmin);
        releaseRegistry.setActive(GIF_INITIAL_RELEASE(), false);
        vm.stopPrank();

        // THEN instance creation fails
        // instanceOwner -[X]-> instanceService.craeteInstance()
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessManaged.AccessManagedUnauthorized.selector, 
                address(instanceOwner)));

        vm.startPrank(instanceOwner);
        (
            IInstance newInstance2, 
            NftId newInstanceNftId2
        ) = instanceService.createInstance(false);
        vm.stopPrank();
    }
}