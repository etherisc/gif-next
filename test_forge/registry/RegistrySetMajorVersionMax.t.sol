// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, Vm, console} from "../../lib/forge-std/src/Test.sol";
import {VersionLib, Version, VersionPart, VersionPartLib} from "../../contracts/types/Version.sol";
import {NftId, toNftId, zeroNftId} from "../../contracts/types/NftId.sol";

import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {RegistryTestBase} from "./RegistryTestBase.sol";

contract RegistryMajorVersionTests is RegistryTestBase {

    VersionPart public majorVersion2 = VersionPartLib.toVersionPart(2);
    VersionPart public majorVersion3 = VersionPartLib.toVersionPart(3);
    VersionPart public majorVersion4 = VersionPartLib.toVersionPart(4);
    VersionPart public majorVersion5 = VersionPartLib.toVersionPart(5);
    VersionPart public majorVersion6 = VersionPartLib.toVersionPart(6);

    function test_registryInitialMajorVersions() public {
        assertEq(registry.getMajorVersionMin().toInt(), 3, "initial major version minimum not 3");
        assertEq(registry.getMajorVersionMax().toInt(), 3, "initial major version maximum not 3");
    }

    function test_registryIncreaseMajorVersionMaxHappyCase() public {

        vm.prank(registryOwner);
        registry.setMajorVersionMax(majorVersion4);

        assertEq(registry.getMajorVersionMin().toInt(), 3, "initial major version minimum not 3");
        assertEq(registry.getMajorVersionMax().toInt(), 4, "initial major version maximum not 4");

        vm.prank(registryOwner);
        registry.setMajorVersionMax(majorVersion5);

        assertEq(registry.getMajorVersionMin().toInt(), 3, "initial major version minimum not 3");
        assertEq(registry.getMajorVersionMax().toInt(), 5, "initial major version maximum not 4");
    }

    function test_registryIncreaseMajorVersionInvalid() public {

        // attempt to increase to version 2 (too low)
        vm.expectRevert(
            abi.encodeWithSelector(IRegistry.MajorVersionMaxIncreaseInvalid.selector,
                majorVersion2,
                registry.getMajorVersionMax()));
        vm.prank(registryOwner);
        registry.setMajorVersionMax(majorVersion2);

        // attempt to increase to current version (too low)
        vm.expectRevert(
            abi.encodeWithSelector(IRegistry.MajorVersionMaxIncreaseInvalid.selector,
                majorVersion3,
                registry.getMajorVersionMax()));
        vm.prank(registryOwner);
        registry.setMajorVersionMax(majorVersion3);

        // attempt to increase to too big version
        vm.expectRevert(
            abi.encodeWithSelector(IRegistry.MajorVersionMaxIncreaseInvalid.selector,
                majorVersion5,
                registry.getMajorVersionMax()));
        vm.prank(registryOwner);
        registry.setMajorVersionMax(majorVersion5);

        // increase max version from 3 to 4
        vm.prank(registryOwner);
        registry.setMajorVersionMax(majorVersion4);

        // redo all checks from above

        // attempt to increase to version 3 (too low)
        vm.expectRevert(
            abi.encodeWithSelector(IRegistry.MajorVersionMaxIncreaseInvalid.selector,
                majorVersion3,
                registry.getMajorVersionMax()));
        vm.prank(registryOwner);
        registry.setMajorVersionMax(majorVersion3);

        // attempt to increase to current version (too low)
        vm.expectRevert(
            abi.encodeWithSelector(IRegistry.MajorVersionMaxIncreaseInvalid.selector,
                majorVersion4,
                registry.getMajorVersionMax()));
        vm.prank(registryOwner);
        registry.setMajorVersionMax(majorVersion4);

        // attempt to increase to too big version
        vm.expectRevert(
            abi.encodeWithSelector(IRegistry.MajorVersionMaxIncreaseInvalid.selector,
                majorVersion6,
                registry.getMajorVersionMax()));
        vm.prank(registryOwner);
        registry.setMajorVersionMax(majorVersion6);
    }

    function test_registryIncreaseMajorVersionMaxNotOwner() public {

        vm.expectRevert(
            abi.encodeWithSelector(IRegistry.NotOwner.selector, 
                outsider));
        vm.prank(outsider);
        registry.setMajorVersionMax(majorVersion4);
    }
}

