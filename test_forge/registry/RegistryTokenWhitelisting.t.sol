// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, Vm, console} from "../../lib/forge-std/src/Test.sol";
import {VersionLib, Version, VersionPart, VersionPartLib} from "../../contracts/types/Version.sol";
import {NftId, toNftId, zeroNftId} from "../../contracts/types/NftId.sol";

import {UsdcMock} from "../mock/UsdcMock.sol";
import {DIP} from "../mock/Dip.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {RegistryTestBase} from "./RegistryTestBase.sol";

contract RegistryTokenWhitelisting is RegistryTestBase {

    DIP public dip = new DIP();
    UsdcMock public usdc = new UsdcMock();

    VersionPart public majorVersion2 = VersionPartLib.toVersionPart(2);
    VersionPart public majorVersion3 = VersionPartLib.toVersionPart(3);
    VersionPart public majorVersion4 = VersionPartLib.toVersionPart(4);
    VersionPart public majorVersion5 = VersionPartLib.toVersionPart(5);
    VersionPart public majorVersion6 = VersionPartLib.toVersionPart(6);

    bool whitelist = true;
    bool blacklist = false;

    function setUp() public virtual override {
        super.setUp();

        vm.prank(registryOwner);
        registryService.registerToken(address(usdc));
    }

    function test_registryTokenInitial() public {
        assertFalse(registry.isRegistered(address(dip)), "dip is registered");
        assertTrue(registry.isRegistered(address(usdc)), "usdc not registered");

        assertFalse(registry.isTokenActive(address(registryService), registry.getMajorVersionMax()), "registry service active in current relase");
        assertFalse(registry.isTokenActive(address(dip), registry.getMajorVersionMax()), "dip active in current relase");
        assertFalse(registry.isTokenActive(address(usdc), registry.getMajorVersionMax()), "usdc active in current relase");
    }

    function test_registryTokenWhitelistHappyCase() public {

        vm.prank(registryOwner);
        registry.setTokenActive(address(usdc), majorVersion3, whitelist);

        assertFalse(registry.isRegistered(address(dip)), "dip is registered");
        assertTrue(registry.isRegistered(address(usdc)), "usdc not registered");

        assertTrue(registry.isTokenActive(address(usdc), registry.getMajorVersionMax()), "usdc not whitelisted in current relase");
        assertFalse(registry.isTokenActive(address(registryService), registry.getMajorVersionMax()), "registry service active in current relase");
        assertFalse(registry.isTokenActive(address(dip), registry.getMajorVersionMax()), "dip whitelisted in current relase");
    }

    function test_registryTokenWhitelistTwoReleasesHappyCase() public {

        vm.prank(registryOwner);
        registry.setTokenActive(address(usdc), majorVersion3, whitelist);

        assertFalse(registry.isRegistered(address(dip)), "dip is registered");
        assertTrue(registry.isRegistered(address(usdc)), "usdc not registered");

        assertTrue(registry.isTokenActive(address(usdc), majorVersion3), "usdc not whitelisted in version 3");
        assertFalse(registry.isTokenActive(address(usdc), majorVersion4), "usdc whitelisted in version 4");

        vm.startPrank(registryOwner);
        registry.setMajorVersionMax(majorVersion4);
        registry.setTokenActive(address(usdc), majorVersion4, whitelist);
        vm.stopPrank();

        assertTrue(registry.isTokenActive(address(usdc), majorVersion3), "usdc not whitelisted in version 3");
        assertTrue(registry.isTokenActive(address(usdc), majorVersion4), "usdc not whitelisted in version 4");
    }

    function test_registryTokenWhitelistNotRegistered() public {
        vm.expectRevert(
            abi.encodeWithSelector(IRegistry.TokenNotRegistered.selector,
                address(dip)));
        vm.prank(registryOwner);
        registry.setTokenActive(address(dip), majorVersion3, whitelist);
    }

    function test_registryTokenWhitelistNotToken() public {
        vm.expectRevert(
            abi.encodeWithSelector(IRegistry.NotToken.selector,
                address(registryService)));
        vm.prank(registryOwner);
        registry.setTokenActive(address(registryService), majorVersion3, whitelist);
    }

    function test_registryTokenWhitelistInvalidRelease() public {

        // attempt to whitelist for version 2 (too low)
        vm.expectRevert(
            abi.encodeWithSelector(IRegistry.TokenMajorVersionInvalid.selector,
                majorVersion2));
        vm.prank(registryOwner);
        registry.setTokenActive(address(usdc), majorVersion2, whitelist);

        // attempt to whitelist for version 4 (too high)
        vm.expectRevert(
            abi.encodeWithSelector(IRegistry.TokenMajorVersionInvalid.selector,
                majorVersion4));
        vm.prank(registryOwner);
        registry.setTokenActive(address(usdc), majorVersion4, whitelist);

        // increase max version from 3 to 4
        vm.prank(registryOwner);
        registry.setMajorVersionMax(majorVersion4);

        // redo all checks from above

        // attempt to whitelist for version 2 (too low)
        vm.expectRevert(
            abi.encodeWithSelector(IRegistry.TokenMajorVersionInvalid.selector,
                majorVersion2));
        vm.prank(registryOwner);
        registry.setTokenActive(address(usdc), majorVersion2, whitelist);


        // attempt to whitelist for version 4 (now ok)
        vm.prank(registryOwner);
        registry.setTokenActive(address(usdc), majorVersion4, whitelist);

        // attempt to whitelist for version 5 (too high)
        vm.expectRevert(
            abi.encodeWithSelector(IRegistry.TokenMajorVersionInvalid.selector,
                majorVersion5));
        vm.prank(registryOwner);
        registry.setTokenActive(address(usdc), majorVersion5, whitelist);
    }

    function test_registryTokenBlacklistHappyCase() public {

        vm.prank(registryOwner);
        registry.setTokenActive(address(usdc), majorVersion3, whitelist);

        assertTrue(registry.isTokenActive(address(usdc), majorVersion3), "usdc not whitelisted in version 3");

        vm.prank(registryOwner);
        registry.setTokenActive(address(usdc), majorVersion3, blacklist);

        assertFalse(registry.isTokenActive(address(usdc), majorVersion3), "usdc not blacklisted in version 3");
    }

    function test_registryTokenWhitelistingNotOwner() public {

        vm.expectRevert(
            abi.encodeWithSelector(IRegistry.NotOwner.selector, 
                outsider));
        vm.prank(outsider);
        registry.setTokenActive(address(usdc), majorVersion3, blacklist);
    }
}

