// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import {Test, Vm, console} from "../../lib/forge-std/src/Test.sol";

import {INftOwnable} from "../../contracts/shared/INftOwnable.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {IRegisterable} from "../../contracts/shared/IRegisterable.sol";
import {IService} from "../../contracts/shared/IService.sol";

import {ChainId, ChainIdLib} from "../../contracts/type/ChainId.sol";
import {Dip} from "../../contracts/mock/Dip.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {GifTest} from "../base/GifTest.sol";
import {NftId} from "../../contracts/type/NftId.sol";
import {TokenRegistry} from "../../contracts/registry/TokenRegistry.sol";
import {Usdc} from "../mock/Usdc.sol";
import {VersionLib, Version, VersionPart, VersionPartLib} from "../../contracts/type/Version.sol";


contract RegistryTokenWhitelisting is GifTest {

    // uint256 public currentChainId = block.chainid;
    Usdc public usdc2 = new Usdc();

    VersionPart public majorVersion2 = VersionPartLib.toVersionPart(2);
    VersionPart public majorVersion3 = VersionPartLib.toVersionPart(3);
    VersionPart public majorVersion4 = VersionPartLib.toVersionPart(4);
    VersionPart public majorVersion5 = VersionPartLib.toVersionPart(5);
    VersionPart public majorVersion6 = VersionPartLib.toVersionPart(6);

    bool whitelist = true;
    bool blacklist = false;

    function test_tokenRegistrySetup() public {

        assertEq(address(tokenRegistry.getRegistry()), address(registry), "unexpected registry address");
        assertEq(registry.getTokenRegistryAddress(), address(tokenRegistry), "unexpected token registry address");

        assertEq(tokenRegistry.tokens(), 2, "unexpected number of registered tokens");

        assertTrue(tokenRegistry.isRegistered(currentChainId, address(dip)), "dip not registered");
        assertTrue(tokenRegistry.isRegistered(currentChainId, address(token)), "token (usdc) not registered");
        assertFalse(tokenRegistry.isRegistered(currentChainId, address(usdc2)), "usdc2 registered");

        TokenRegistry.TokenInfo memory dipInfo = tokenRegistry.getTokenInfo(0);
        assertEq(dipInfo.token, address(dip), "unexpected dip token address (1)");
        assertEq(dipInfo.token, tokenRegistry.getTokenInfo(currentChainId, address(dip)).token, "unexpected tip token address (2)");
        assertEq(dipInfo.chainId.toInt(), block.chainid, "unexpected dip chainid");
        assertEq(dipInfo.decimals, dip.decimals(), "unexpected dip decimals");
        assertEq(dipInfo.symbol, dip.symbol(), "unexpected dip symbol");
        assertTrue(dipInfo.active, "unexpected dip active");

        TokenRegistry.TokenInfo memory tokenInfo = tokenRegistry.getTokenInfo(1);
        assertEq(tokenInfo.token, address(token), "unexpected token (usdc) address (1)");
        assertEq(tokenInfo.token, tokenRegistry.getTokenInfo(currentChainId, address(token)).token, "unexpected token (usdc) address (2)");
        assertEq(tokenInfo.chainId.toInt(), block.chainid, "unexpected token (usdc) chainid");
        assertEq(tokenInfo.decimals, token.decimals(), "unexpected token (usdc) decimals");
        assertEq(tokenInfo.symbol, token.symbol(), "unexpected token (usdc) symbol");
        assertTrue(tokenInfo.active, "unexpected token (usdc) active");

        assertTrue(tokenRegistry.isActive(currentChainId, address(dip), releaseRegistry.getLatestVersion()), "dip not active in current relase");
        assertTrue(tokenRegistry.isActive(currentChainId, address(token), releaseRegistry.getLatestVersion()), "token (usdc) not active in current relase");
        assertFalse(tokenRegistry.isActive(currentChainId, address(usdc2), releaseRegistry.getLatestVersion()), "usdc2 active in current relase");
    }


    function test_tokenRegistrySetGlobalState() public {

        assertTrue(tokenRegistry.isActive(currentChainId, address(dip), releaseRegistry.getLatestVersion()), "dip active in current relase (1)");
        assertTrue(tokenRegistry.getTokenInfo(currentChainId, address(dip)).active, "dip not active (1a)");
        assertFalse(tokenRegistry.isActive(currentChainId, address(usdc2), releaseRegistry.getLatestVersion()), "usdc2 active in current relase (1)");

        vm.startPrank(registryOwner);
        tokenRegistry.setActive(currentChainId, address(dip), false);
        vm.stopPrank();

        assertFalse(tokenRegistry.isActive(currentChainId, address(dip), releaseRegistry.getLatestVersion()), "dip active in current relase (2)");
        assertFalse(tokenRegistry.getTokenInfo(currentChainId, address(dip)).active, "dip active (2a)");
        assertFalse(tokenRegistry.isActive(currentChainId, address(usdc2), releaseRegistry.getLatestVersion()), "usdc2 active in current relase (2)");

        vm.startPrank(registryOwner);
        tokenRegistry.setActive(currentChainId, address(dip), true);
        vm.stopPrank();

        assertTrue(tokenRegistry.isActive(currentChainId, address(dip), releaseRegistry.getLatestVersion()), "dip not active in current relase (3)");
        assertTrue(tokenRegistry.getTokenInfo(currentChainId, address(dip)).active, "dip not active (3a)");
        assertFalse(tokenRegistry.isActive(currentChainId, address(usdc2), releaseRegistry.getLatestVersion()), "usdc2 active in current relase (3)");
    }


    function test_tokenRegistryWhitelistHappyCase() public {

        vm.startPrank(address(registryOwner));
        tokenRegistry.registerToken(address(usdc2));
        tokenRegistry.setActiveForVersion(currentChainId, address(usdc2), majorVersion3, whitelist);
        vm.stopPrank();

        assertTrue(tokenRegistry.isRegistered(currentChainId, address(dip)), "dip not registered");
        assertTrue(tokenRegistry.isRegistered(currentChainId, address(usdc2)), "usdc2 not registered");

        assertTrue(tokenRegistry.isActive(currentChainId, address(dip), releaseRegistry.getLatestVersion()), "dip not whitelisted in current relase");
        assertTrue(tokenRegistry.isActive(currentChainId, address(usdc2), releaseRegistry.getLatestVersion()), "usdc2 not whitelisted in current relase");
        assertFalse(tokenRegistry.isActive(currentChainId, address(registryService), releaseRegistry.getLatestVersion()), "registry service active in current relase");
    }


    function test_tokenRegistryWhitelistTwoReleasesHappyCase() public {

        vm.startPrank(address(registryOwner));
        tokenRegistry.registerToken(address(usdc2));
        tokenRegistry.setActiveForVersion(currentChainId, address(usdc2), majorVersion3, whitelist);
        vm.stopPrank();

        assertTrue(tokenRegistry.isRegistered(currentChainId, address(dip)), "dip is registered");
        assertTrue(tokenRegistry.isRegistered(currentChainId, address(usdc2)), "usdc2 not registered");

        assertTrue(tokenRegistry.isActive(currentChainId, address(usdc2), majorVersion3), "usdc2 not whitelisted in version 3");
        assertFalse(tokenRegistry.isActive(currentChainId, address(usdc2), majorVersion4), "usdc2 whitelisted in version 4");

        vm.startPrank(registryOwner);
        bool enforceVersionCheck = false;
        tokenRegistry.setActiveWithVersionCheck(currentChainId, address(usdc2), majorVersion4, whitelist, enforceVersionCheck);
        vm.stopPrank();

        assertTrue(tokenRegistry.isActive(currentChainId, address(usdc2), majorVersion3), "usdc2 not whitelisted in version 3");
        assertTrue(tokenRegistry.isActive(currentChainId, address(usdc2), majorVersion4), "usdc2 not whitelisted in version 4");
    }


    function test_tokenRegistryWhitelistRemoteTokenHappyCase() public {

        ChainId quakChainId = ChainIdLib.toChainId(123);
        address quakAddress = address(123);
        uint8 quakDecimals = 3;
        string memory quakSymbol = "QUAK123";

        vm.startPrank(address(registryOwner));
        tokenRegistry.registerRemoteToken(quakChainId, quakAddress, quakDecimals, quakSymbol);
        vm.stopPrank();

        // check token info
        TokenRegistry.TokenInfo memory quakInfo = tokenRegistry.getTokenInfo(quakChainId, quakAddress);
        assertEq(quakInfo.chainId.toInt(), quakChainId.toInt(), "unexpected currentChainId for quakToken");
        assertEq(quakInfo.token, quakAddress, "unexpected token address for quakToken");
        assertEq(quakInfo.decimals, quakDecimals, "unexpected decimals for quakToken");
        assertEq(quakInfo.symbol, quakSymbol, "unexpected symbol for quakToken");
        assertTrue(quakInfo.active, "quakToken not active");

        // check is registered
        assertTrue(tokenRegistry.isRegistered(quakChainId, quakAddress), "quack not registered");
        assertFalse(tokenRegistry.isRegistered(currentChainId, quakAddress), "quack registered on local chain");

        // check is active
        assertFalse(tokenRegistry.isActive(quakChainId, quakAddress, majorVersion3), "quack active for version 3");

        vm.startPrank(address(registryOwner));
        tokenRegistry.setActiveForVersion(quakChainId, quakAddress, majorVersion3, whitelist);
        vm.stopPrank();

        assertTrue(tokenRegistry.isActive(quakChainId, quakAddress, majorVersion3), "quack not active for version 3");
    }


    function test_tokenRegistryWhitelistRemoteTokenOnchain() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                TokenRegistry.ErrorTokenRegistryNotRemoteToken.selector,
                currentChainId,
                address(usdc2)));

        vm.startPrank(address(registryOwner));
        tokenRegistry.registerRemoteToken(currentChainId, address(usdc2), 3, "dummy");
        vm.stopPrank();
    }


    function test_tokenRegistryWhitelistRemoteTokenBadChainIdTokenAddress() public {

        ChainId quakChainId = ChainIdLib.toChainId(123);
        address quakAddress = address(123);
        uint8 quakDecimals = 3;
        string memory quakSymbol = "QUAK123";

        vm.startPrank(address(registryOwner));
        tokenRegistry.registerRemoteToken(quakChainId, quakAddress, quakDecimals, quakSymbol);

        // attempt to register quak token 2nd time
        vm.expectRevert(
            abi.encodeWithSelector(
                TokenRegistry.ErrorTokenRegistryTokenAlreadyRegistered.selector,
                quakChainId,
                address(quakAddress)));

        tokenRegistry.registerRemoteToken(quakChainId, quakAddress, quakDecimals, quakSymbol);

        // attempt to register quak token for currentChainId 0
        ChainId zeroChainId = ChainIdLib.zero();
        vm.expectRevert(TokenRegistry.ErrorTokenRegistryChainIdZero.selector);
        tokenRegistry.registerRemoteToken(zeroChainId, quakAddress, quakDecimals, quakSymbol);

        // attempt to register quak token for currentChainId 0
        vm.expectRevert(TokenRegistry.ErrorTokenRegistryTokenAddressZero.selector);
        tokenRegistry.registerRemoteToken(quakChainId, address(0), quakDecimals, quakSymbol);

        vm.stopPrank();
    }


    function test_tokenRegistryBlacklistHappyCase() public {
        vm.startPrank(address(registryOwner));

        tokenRegistry.registerToken(address(usdc2));
        tokenRegistry.setActiveForVersion(currentChainId, address(usdc2), majorVersion3, whitelist);

        assertTrue(tokenRegistry.isActive(currentChainId, address(usdc2), majorVersion3), "usdc2 not whitelisted in version 3");

        tokenRegistry.setActiveForVersion(currentChainId, address(usdc2), majorVersion3, blacklist);

        assertFalse(tokenRegistry.isActive(currentChainId, address(usdc2), majorVersion3), "usdc2 not blacklisted in version 3");

        vm.stopPrank();
    }


    function test_tokenRegistryWhitelistNotToken() public {
        vm.expectRevert(
            abi.encodeWithSelector(TokenRegistry.ErrorTokenRegistryTokenNotErc20.selector,
                currentChainId,
                address(registryService)));

        vm.startPrank(address(registryOwner));
        tokenRegistry.registerToken(address(registryService));
        vm.stopPrank();
    }


    function test_tokenRegistryWhitelistNotRegistered() public {
        vm.expectRevert(
            abi.encodeWithSelector(TokenRegistry.ErrorTokenRegistryTokenNotRegistered.selector,
                currentChainId,
                address(usdc2)));

        vm.startPrank(address(registryOwner));
        tokenRegistry.setActiveForVersion(currentChainId, address(usdc2), majorVersion4, whitelist);
        vm.stopPrank();
    }


    function test_tokenRegistryWhitelistNotContract() public {
        vm.expectRevert(
            abi.encodeWithSelector(TokenRegistry.ErrorTokenRegistryTokenNotContract.selector,
                currentChainId,
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
        tokenRegistry.setActiveForVersion(currentChainId, address(dip), majorVersion2, whitelist);

        // attempt to whitelist for version 4 (too high)
        vm.expectRevert(
            abi.encodeWithSelector(
                TokenRegistry.ErrorTokenRegistryMajorVersionInvalid.selector,
                majorVersion4));
        vm.prank(registryOwner);
        tokenRegistry.setActiveForVersion(currentChainId, address(dip), majorVersion4, whitelist);

    }

    function test_tokenRegistryWhitelistingNotOwner() public {

        vm.startPrank(outsider);

        // check restricted for register
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessManaged.AccessManagedUnauthorized.selector, 
                outsider));

        tokenRegistry.registerToken(address(usdc2));

        // check restricted for setActive
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessManaged.AccessManagedUnauthorized.selector, 
                outsider));

        tokenRegistry.setActiveForVersion(currentChainId, address(dip), majorVersion4, whitelist);

        // check restricted for setActive
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessManaged.AccessManagedUnauthorized.selector, 
                outsider));

        tokenRegistry.setActiveWithVersionCheck(currentChainId, address(dip), majorVersion4, whitelist, false);

        vm.stopPrank();
    }

}

