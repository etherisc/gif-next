// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import {Test, Vm, console} from "../../lib/forge-std/src/Test.sol";
import {VersionLib, Version, VersionPart, VersionPartLib} from "../../contracts/type/Version.sol";
import {NftId} from "../../contracts/type/NftId.sol";

import {Usdc} from "../mock/Usdc.sol";
import {Dip} from "../mock/Dip.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {IRegisterable} from "../../contracts/shared/IRegisterable.sol";
import {IService} from "../../contracts/shared/IService.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {INftOwnable} from "../../contracts/shared/INftOwnable.sol";
import {GifTest} from "../base/GifTest.sol";
import {TokenRegistry} from "../../contracts/registry/TokenRegistry.sol";

contract RegistryTokenWhitelisting is GifTest {

    uint256 public chainId = block.chainid;
    Usdc public usdc2 = new Usdc();

    VersionPart public majorVersion2 = VersionPartLib.toVersionPart(2);
    VersionPart public majorVersion3 = VersionPartLib.toVersionPart(3);
    VersionPart public majorVersion4 = VersionPartLib.toVersionPart(4);
    VersionPart public majorVersion5 = VersionPartLib.toVersionPart(5);
    VersionPart public majorVersion6 = VersionPartLib.toVersionPart(6);

    bool whitelist = true;
    bool blacklist = false;

    function test_tokenRegistrySetup() public {

        assertEq(tokenRegistry.getOwner(), registryOwner, "unexpected owner for token registry");
        assertEq(address(tokenRegistry.getRegistry()), address(registry), "unexpected registry address");
        assertEq(registry.getTokenRegistryAddress(), address(tokenRegistry), "unexpected token registry address");

        assertEq(tokenRegistry.tokens(), 2, "unexpected number of registered tokens");

        assertTrue(tokenRegistry.isRegistered(chainId, address(dip)), "dip not registered");
        assertFalse(tokenRegistry.isRegistered(chainId, address(usdc2)), "usdc2 registered");

        assertTrue(tokenRegistry.isActive(chainId, address(dip), releaseManager.getLatestVersion()), "dip active in current relase");
        assertFalse(tokenRegistry.isActive(chainId, address(usdc2), releaseManager.getLatestVersion()), "usdc2 active in current relase");
    }


    function test_tokenRegistryWhitelistHappyCase() public {

        vm.startPrank(address(registryOwner));
        tokenRegistry.registerToken(address(usdc2));
        tokenRegistry.setActive(chainId, address(usdc2), majorVersion3, whitelist);
        vm.stopPrank();

        assertTrue(tokenRegistry.isRegistered(chainId, address(dip)), "dip not registered");
        assertTrue(tokenRegistry.isRegistered(chainId, address(usdc2)), "usdc2 not registered");

        assertTrue(tokenRegistry.isActive(chainId, address(dip), releaseManager.getLatestVersion()), "dip not whitelisted in current relase");
        assertTrue(tokenRegistry.isActive(chainId, address(usdc2), releaseManager.getLatestVersion()), "usdc2 not whitelisted in current relase");
        assertFalse(tokenRegistry.isActive(chainId, address(registryService), releaseManager.getLatestVersion()), "registry service active in current relase");
    }


    function test_tokenRegistryWhitelistTwoReleasesHappyCase() public {

        vm.startPrank(address(registryOwner));
        tokenRegistry.registerToken(address(usdc2));
        tokenRegistry.setActive(chainId, address(usdc2), majorVersion3, whitelist);
        vm.stopPrank();

        assertTrue(tokenRegistry.isRegistered(chainId, address(dip)), "dip is registered");
        assertTrue(tokenRegistry.isRegistered(chainId, address(usdc2)), "usdc2 not registered");

        assertTrue(tokenRegistry.isActive(chainId, address(usdc2), majorVersion3), "usdc2 not whitelisted in version 3");
        assertFalse(tokenRegistry.isActive(chainId, address(usdc2), majorVersion4), "usdc2 whitelisted in version 4");

        vm.startPrank(registryOwner);
        bool enforceVersionCheck = false;
        tokenRegistry.setActiveWithVersionCheck(chainId, address(usdc2), majorVersion4, whitelist, enforceVersionCheck);
        vm.stopPrank();

        assertTrue(tokenRegistry.isActive(chainId, address(usdc2), majorVersion3), "usdc2 not whitelisted in version 3");
        assertTrue(tokenRegistry.isActive(chainId, address(usdc2), majorVersion4), "usdc2 not whitelisted in version 4");
    }


    function test_tokenRegistryBlacklistHappyCase() public {
        vm.startPrank(address(registryOwner));

        tokenRegistry.registerToken(address(usdc2));
        tokenRegistry.setActive(chainId, address(usdc2), majorVersion3, whitelist);

        assertTrue(tokenRegistry.isActive(chainId, address(usdc2), majorVersion3), "usdc2 not whitelisted in version 3");

        tokenRegistry.setActive(chainId, address(usdc2), majorVersion3, blacklist);

        assertFalse(tokenRegistry.isActive(chainId, address(usdc2), majorVersion3), "usdc2 not blacklisted in version 3");

        vm.stopPrank();
    }


    function test_tokenRegistryWhitelistNotToken() public {
        vm.expectRevert(
            abi.encodeWithSelector(TokenRegistry.ErrorTokenRegistryTokenNotErc20.selector,
                chainId,
                address(registryService)));

        vm.startPrank(address(registryOwner));
        tokenRegistry.registerToken(address(registryService));
        vm.stopPrank();
    }


    function test_tokenRegistryWhitelistNotRegistered() public {
        vm.expectRevert(
            abi.encodeWithSelector(TokenRegistry.ErrorTokenRegistryTokenNotRegistered.selector,
                chainId,
                address(usdc2)));

        vm.startPrank(address(registryOwner));
        tokenRegistry.setActive(chainId, address(usdc2), majorVersion4, whitelist);
        vm.stopPrank();
    }


    function test_tokenRegistryWhitelistNotContract() public {
        vm.expectRevert(
            abi.encodeWithSelector(TokenRegistry.ErrorTokenRegistryTokenNotContract.selector,
                chainId,
                address(outsider)));

        vm.prank(address(registryOwner));
        tokenRegistry.registerToken(outsider);
    }


    function test_tokenRegistryWhitelistInvalidRelease() public {

        // attempt to whitelist for version 2 (too low)
        vm.expectRevert(
            abi.encodeWithSelector(
                TokenRegistry.ErrorTokenRegistryMajorVersionInvalid.selector,
                majorVersion2));

        vm.prank(registryOwner);
        tokenRegistry.setActive(chainId, address(dip), majorVersion2, whitelist);

        // attempt to whitelist for version 4 (too high)
        vm.expectRevert(
            abi.encodeWithSelector(
                TokenRegistry.ErrorTokenRegistryMajorVersionInvalid.selector,
                majorVersion4));
        vm.prank(registryOwner);
        tokenRegistry.setActive(chainId, address(dip), majorVersion4, whitelist);

    }

    function test_tokenRegistryWhitelistingNotOwner() public {

        vm.startPrank(outsider);

        // check onlyOwner for register
        vm.expectRevert(
            abi.encodeWithSelector(
                INftOwnable.ErrorNftOwnableNotOwner.selector, 
                outsider));

        tokenRegistry.registerToken(address(usdc2));

        // check onlyOwner for setActive
        vm.expectRevert(
            abi.encodeWithSelector(
                INftOwnable.ErrorNftOwnableNotOwner.selector, 
                outsider));

        tokenRegistry.setActive(chainId, address(dip), majorVersion4, whitelist);

        // check onlyOwner for setActive
        vm.expectRevert(
            abi.encodeWithSelector(
                INftOwnable.ErrorNftOwnableNotOwner.selector, 
                outsider));

        tokenRegistry.setActiveWithVersionCheck(chainId, address(dip), majorVersion4, whitelist, false);

        vm.stopPrank();
    }

}

