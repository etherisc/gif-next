// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Test, Vm, console} from "../../lib/forge-std/src/Test.sol";
import {VersionLib, Version, VersionPart, VersionPartLib} from "../../contracts/type/Version.sol";
import {NftId} from "../../contracts/type/NftId.sol";

import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {RegistryTestBase} from "./RegistryTestBase.sol";

contract RegistryMajorVersionTests is RegistryTestBase {

    VersionPart public majorVersion2 = VersionPartLib.toVersionPart(2);
    VersionPart public majorVersion3 = VersionPartLib.toVersionPart(3);
    VersionPart public majorVersion4 = VersionPartLib.toVersionPart(4);
    VersionPart public majorVersion5 = VersionPartLib.toVersionPart(5);
    VersionPart public majorVersion6 = VersionPartLib.toVersionPart(6);

/* TODO refactor, GIF_MAJOR_VERSION -> GIF_RELEASE
    function test_registryInitialMajorVersions() public {
        assertEq(registry.getMajorVersion().toInt(), 3, "initial major version minimum not 3");
        assertEq(registry.GIF_MAJOR_VERSION_AT_DEPLOYMENT(), 3, "initial major version maximum not 3");
    }

    function test_registryNftId() public {
        assertEq(registry.getNftId().toInt(), registryNftId.toInt(), "unexpected registry nft id");
        assertEq(
            registry.getNftId().toInt(), 
            registry.getNftIdForAddress(address(registry)).toInt(), 
            "unexpected registry nft id (version 2)"
        );
    }

    function test_registryIncreaseMajorVersionHappyCase() public {

        vm.prank(registryOwner);
        registry.setMajorVersion(majorVersion4);

        assertEq(registry.getMajorVersion().toInt(), 4, "initial major version maximum not 4");

        vm.prank(registryOwner);
        registry.setMajorVersion(majorVersion5);

        assertEq(registry.getMajorVersion().toInt(), 5, "initial major version maximum not 4");
    }

    function test_registryIncreaseMajorVersionInvalid() public {

        // attempt to increase to version 2 (too low)
        vm.expectRevert(
            abi.encodeWithSelector(IRegistry.MajorVersionMaxIncreaseInvalid.selector,
                majorVersion2,
                registry.getMajorVersion()));
        vm.prank(registryOwner);
        registry.setMajorVersion(majorVersion2);

        // attempt to increase to current version (too low)
        vm.expectRevert(
            abi.encodeWithSelector(IRegistry.MajorVersionMaxIncreaseInvalid.selector,
                majorVersion3,
                registry.getMajorVersion()));
        vm.prank(registryOwner);
        registry.setMajorVersion(majorVersion3);

        // attempt to increase to too big version
        vm.expectRevert(
            abi.encodeWithSelector(IRegistry.MajorVersionMaxIncreaseInvalid.selector,
                majorVersion5,
                registry.getMajorVersion()));
        vm.prank(registryOwner);
        registry.setMajorVersion(majorVersion5);

        // increase max version from 3 to 4
        vm.prank(registryOwner);
        registry.setMajorVersion(majorVersion4);

        // redo all checks from above

        // attempt to increase to version 3 (too low)
        vm.expectRevert(
            abi.encodeWithSelector(IRegistry.MajorVersionMaxIncreaseInvalid.selector,
                majorVersion3,
                registry.getMajorVersion()));
        vm.prank(registryOwner);
        registry.setMajorVersion(majorVersion3);

        // attempt to increase to current version (too low)
        vm.expectRevert(
            abi.encodeWithSelector(IRegistry.MajorVersionMaxIncreaseInvalid.selector,
                majorVersion4,
                registry.getMajorVersion()));
        vm.prank(registryOwner);
        registry.setMajorVersion(majorVersion4);

        // attempt to increase to too big version
        vm.expectRevert(
            abi.encodeWithSelector(IRegistry.MajorVersionMaxIncreaseInvalid.selector,
                majorVersion6,
                registry.getMajorVersion()));
        vm.prank(registryOwner);
        registry.setMajorVersion(majorVersion6);
    }

    function test_registryIncreaseMajorVersionNotOwner() public {

        vm.expectRevert(
            abi.encodeWithSelector(IRegistry.NotOwner.selector, 
                outsider));
        vm.prank(outsider);
        registry.setMajorVersion(majorVersion4);
    }
*/  
}

