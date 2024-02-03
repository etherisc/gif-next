// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import {Test, Vm, console} from "../../lib/forge-std/src/Test.sol";
import {VersionLib, Version, VersionPart, VersionPartLib} from "../../contracts/types/Version.sol";
import {NftId, toNftId, zeroNftId} from "../../contracts/types/NftId.sol";

import {UsdcMock} from "../mock/UsdcMock.sol";
import {DIP} from "../mock/Dip.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {IRegisterable} from "../../contracts/shared/IRegisterable.sol";
import {IService} from "../../contracts/shared/IService.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {INftOwnable} from "../../contracts/shared/INftOwnable.sol";
import {RegistryTestBase} from "./RegistryTestBase.sol";
import {TokenRegistry} from "../../contracts/registry/TokenRegistry.sol";

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
    
        vm.prank(address(registryOwner));
        tokenRegistry.setActive(address(usdc), majorVersion3, blacklist);
    }

    function test_registryTokenInitial() public {
        assertFalse(tokenRegistry.isRegistered(address(dip)), "dip is registered");
        assertTrue(tokenRegistry.isRegistered(address(usdc)), "usdc not registered");

        assertFalse(tokenRegistry.isActive(address(dip), registry.getMajorVersion()), "dip active in current relase");
        assertFalse(tokenRegistry.isActive(address(usdc), registry.getMajorVersion()), "usdc active in current relase");
    }
// TODO refactor
/*
    function test_registryTokenWhitelistHappyCase() public {

        vm.prank(address(releaseManager));
        tokenRegistry.setActive(address(usdc), majorVersion3, whitelist);

        assertFalse(tokenRegistry.isRegistered(address(dip)), "dip is registered");
        assertTrue(tokenRegistry.isRegistered(address(usdc)), "usdc not registered");

        assertTrue(tokenRegistry.isActive(address(usdc), registry.getMajorVersion()), "usdc not whitelisted in current relase");
        assertFalse(tokenRegistry.isActive(address(registryService), registry.getMajorVersion()), "registry service active in current relase");
        assertFalse(tokenRegistry.isActive(address(dip), registry.getMajorVersion()), "dip whitelisted in current relase");
    }

    function test_registryTokenWhitelistTwoReleasesHappyCase() public {

        vm.prank(registryOwner);
        tokenRegistry.setActive(address(usdc), majorVersion3, whitelist);

        assertFalse(tokenRegistry.isRegistered(address(dip)), "dip is registered");
        assertTrue(tokenRegistry.isRegistered(address(usdc)), "usdc not registered");

        assertTrue(tokenRegistry.isActive(address(usdc), majorVersion3), "usdc not whitelisted in version 3");
        assertFalse(tokenRegistry.isActive(address(usdc), majorVersion4), "usdc whitelisted in version 4");

        vm.startPrank(registryOwner);
        registry.setMajorVersion(majorVersion4);
        tokenRegistry.setActive(address(usdc), majorVersion4, whitelist);
        vm.stopPrank();

        assertTrue(tokenRegistry.isActive(address(usdc), majorVersion3), "usdc not whitelisted in version 3");
        assertTrue(tokenRegistry.isActive(address(usdc), majorVersion4), "usdc not whitelisted in version 4");
    }
*/
    function test_registryTokenWhitelistNotToken() public {
        vm.expectRevert(
            abi.encodeWithSelector(TokenRegistry.NotToken.selector,
                address(registryService)));

        vm.prank(address(registryOwner));
        tokenRegistry.setActive(address(registryService), majorVersion3, whitelist);
    }

    function test_registryTokenWhitelistNotContract() public {
        vm.expectRevert(
            abi.encodeWithSelector(TokenRegistry.NotContract.selector,
                address(outsider)));

        vm.prank(address(registryOwner));
        tokenRegistry.setActive(outsider, majorVersion3, whitelist);
    }
/* TODO refactor
    function test_registryTokenWhitelistInvalidRelease() public {

        // attempt to whitelist for version 2 (too low)
        vm.expectRevert(
            abi.encodeWithSelector(TokenRegistry.TokenMajorVersionInvalid.selector,
                majorVersion2));
        vm.prank(registryOwner);
        tokenRegistry.setActive(address(usdc), majorVersion2, whitelist);

        // attempt to whitelist for version 4 (too high)
        vm.expectRevert(
            abi.encodeWithSelector(TokenRegistry.TokenMajorVersionInvalid.selector,
                majorVersion4));
        vm.prank(registryOwner);
        tokenRegistry.setActive(address(usdc), majorVersion4, whitelist);

        // increase max version from 3 to 4
        vm.prank(registryOwner);
        registry.setMajorVersion(majorVersion4);

        assertEq(registry.getMajorVersionMax().toInt(), 4, "unexpected max version");

        // redo all checks from above

        // attempt to whitelist for version 2 (too low)
        vm.expectRevert(
            abi.encodeWithSelector(TokenRegistry.TokenMajorVersionInvalid.selector,
                majorVersion2));
        vm.prank(registryOwner);
        tokenRegistry.setActive(address(usdc), majorVersion2, whitelist);


        // attempt to whitelist for version 4 (now ok)
        vm.prank(registryOwner);
        tokenRegistry.setActive(address(usdc), majorVersion4, whitelist);

        // attempt to whitelist for version 5 (too high)
        vm.expectRevert(
            abi.encodeWithSelector(TokenRegistry.TokenMajorVersionInvalid.selector,
                majorVersion5));
        vm.prank(registryOwner);
        tokenRegistry.setActive(address(usdc), majorVersion5, whitelist);
    }
*/
    function test_registryTokenBlacklistHappyCase() public {

        vm.prank(address(registryOwner));
        tokenRegistry.setActive(address(usdc), majorVersion3, whitelist);

        assertTrue(tokenRegistry.isActive(address(usdc), majorVersion3), "usdc not whitelisted in version 3");

        vm.prank(address(registryOwner));
        tokenRegistry.setActive(address(usdc), majorVersion3, blacklist);

        assertFalse(tokenRegistry.isActive(address(usdc), majorVersion3), "usdc not blacklisted in version 3");
    }

    function test_registryTokenWhitelistingNotOwner() public {

        vm.expectRevert(
            abi.encodeWithSelector(INftOwnable.ErrorNotOwner.selector, 
                outsider));
        vm.prank(outsider);
        tokenRegistry.setActive(address(usdc), majorVersion3, blacklist);
    }
}

