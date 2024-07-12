// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import {Test, Vm, console} from "../../lib/forge-std/src/Test.sol";
import {VersionLib, Version, VersionPart, VersionPartLib} from "../../contracts/type/Version.sol";
import {NftId} from "../../contracts/type/NftId.sol";

import {Usdc} from "../mock/Usdc.sol";
import {Dip} from "../../contracts/mock/Dip.sol";
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

        assertEq(address(core.tokenRegistry.getRegistry()), address(core.registry), "unexpected registry address");
        assertEq(core.registry.getTokenRegistryAddress(), address(core.tokenRegistry), "unexpected token registry address");

        assertEq(core.tokenRegistry.tokens(), 2, "unexpected number of registered tokens");

        assertTrue(core.tokenRegistry.isRegistered(chainId, address(core.dip)), "dip not registered");
        assertTrue(core.tokenRegistry.isRegistered(chainId, address(token)), "token (usdc) not registered");
        assertFalse(core.tokenRegistry.isRegistered(chainId, address(usdc2)), "usdc2 registered");

        TokenRegistry.TokenInfo memory dipInfo = core.tokenRegistry.getTokenInfo(0);
        assertEq(dipInfo.token, address(core.dip), "unexpected dip token address (1)");
        assertEq(dipInfo.token, core.tokenRegistry.getTokenInfo(chainId, address(core.dip)).token, "unexpected tip token address (2)");
        assertEq(dipInfo.chainId, block.chainid, "unexpected dip chainid");
        assertEq(dipInfo.decimals, core.dip.decimals(), "unexpected dip decimals");
        assertEq(dipInfo.symbol, core.dip.symbol(), "unexpected dip symbol");
        assertTrue(dipInfo.active, "unexpected dip active");

        TokenRegistry.TokenInfo memory tokenInfo = core.tokenRegistry.getTokenInfo(1);
        assertEq(tokenInfo.token, address(token), "unexpected token (usdc) address (1)");
        assertEq(tokenInfo.token, core.tokenRegistry.getTokenInfo(chainId, address(token)).token, "unexpected token (usdc) address (2)");
        assertEq(tokenInfo.chainId, block.chainid, "unexpected token (usdc) chainid");
        assertEq(tokenInfo.decimals, token.decimals(), "unexpected token (usdc) decimals");
        assertEq(tokenInfo.symbol, token.symbol(), "unexpected token (usdc) symbol");
        assertTrue(tokenInfo.active, "unexpected token (usdc) active");

        assertTrue(core.tokenRegistry.isActive(chainId, address(core.dip), core.releaseRegistry.getLatestVersion()), "dip not active in current relase");
        assertTrue(core.tokenRegistry.isActive(chainId, address(token), core.releaseRegistry.getLatestVersion()), "token (usdc) not active in current relase");
        assertFalse(core.tokenRegistry.isActive(chainId, address(usdc2), core.releaseRegistry.getLatestVersion()), "usdc2 active in current relase");
    }


    function test_tokenRegistrySetGlobalState() public {

        assertTrue(core.tokenRegistry.isActive(chainId, address(core.dip), core.releaseRegistry.getLatestVersion()), "dip active in current relase (1)");
        assertTrue(core.tokenRegistry.getTokenInfo(chainId, address(core.dip)).active, "dip not active (1a)");
        assertFalse(core.tokenRegistry.isActive(chainId, address(usdc2), core.releaseRegistry.getLatestVersion()), "usdc2 active in current relase (1)");

        vm.startPrank(registryOwner);
        core.tokenRegistry.setActive(chainId, address(core.dip), false);
        vm.stopPrank();

        assertFalse(core.tokenRegistry.isActive(chainId, address(core.dip), core.releaseRegistry.getLatestVersion()), "dip active in current relase (2)");
        assertFalse(core.tokenRegistry.getTokenInfo(chainId, address(core.dip)).active, "dip active (2a)");
        assertFalse(core.tokenRegistry.isActive(chainId, address(usdc2), core.releaseRegistry.getLatestVersion()), "usdc2 active in current relase (2)");

        vm.startPrank(registryOwner);
        core.tokenRegistry.setActive(chainId, address(core.dip), true);
        vm.stopPrank();

        assertTrue(core.tokenRegistry.isActive(chainId, address(core.dip), core.releaseRegistry.getLatestVersion()), "dip not active in current relase (3)");
        assertTrue(core.tokenRegistry.getTokenInfo(chainId, address(core.dip)).active, "dip not active (3a)");
        assertFalse(core.tokenRegistry.isActive(chainId, address(usdc2), core.releaseRegistry.getLatestVersion()), "usdc2 active in current relase (3)");
    }


    function test_tokenRegistryWhitelistHappyCase() public {

        vm.startPrank(address(registryOwner));
        core.tokenRegistry.registerToken(address(usdc2));
        core.tokenRegistry.setActiveForVersion(chainId, address(usdc2), majorVersion3, whitelist);
        vm.stopPrank();

        assertTrue(core.tokenRegistry.isRegistered(chainId, address(core.dip)), "dip not registered");
        assertTrue(core.tokenRegistry.isRegistered(chainId, address(usdc2)), "usdc2 not registered");

        assertTrue(core.tokenRegistry.isActive(chainId, address(core.dip), core.releaseRegistry.getLatestVersion()), "dip not whitelisted in current relase");
        assertTrue(core.tokenRegistry.isActive(chainId, address(usdc2), core.releaseRegistry.getLatestVersion()), "usdc2 not whitelisted in current relase");
        assertFalse(core.tokenRegistry.isActive(chainId, address(registryService), core.releaseRegistry.getLatestVersion()), "registry service active in current relase");
    }


    function test_tokenRegistryWhitelistTwoReleasesHappyCase() public {

        vm.startPrank(address(registryOwner));
        core.tokenRegistry.registerToken(address(usdc2));
        core.tokenRegistry.setActiveForVersion(chainId, address(usdc2), majorVersion3, whitelist);
        vm.stopPrank();

        assertTrue(core.tokenRegistry.isRegistered(chainId, address(core.dip)), "dip is registered");
        assertTrue(core.tokenRegistry.isRegistered(chainId, address(usdc2)), "usdc2 not registered");

        assertTrue(core.tokenRegistry.isActive(chainId, address(usdc2), majorVersion3), "usdc2 not whitelisted in version 3");
        assertFalse(core.tokenRegistry.isActive(chainId, address(usdc2), majorVersion4), "usdc2 whitelisted in version 4");

        vm.startPrank(registryOwner);
        bool enforceVersionCheck = false;
        core.tokenRegistry.setActiveWithVersionCheck(chainId, address(usdc2), majorVersion4, whitelist, enforceVersionCheck);
        vm.stopPrank();

        assertTrue(core.tokenRegistry.isActive(chainId, address(usdc2), majorVersion3), "usdc2 not whitelisted in version 3");
        assertTrue(core.tokenRegistry.isActive(chainId, address(usdc2), majorVersion4), "usdc2 not whitelisted in version 4");
    }


    function test_tokenRegistryWhitelistRemoteTokenHappyCase() public {

        uint256 quakChainId = 123;
        address quakAddress = address(123);
        uint8 quakDecimals = 3;
        string memory quakSymbol = "QUAK123";

        vm.startPrank(address(registryOwner));
        core.tokenRegistry.registerRemoteToken(quakChainId, quakAddress, quakDecimals, quakSymbol);
        vm.stopPrank();

        // check token info
        TokenRegistry.TokenInfo memory quakInfo = core.tokenRegistry.getTokenInfo(quakChainId, quakAddress);
        assertEq(quakInfo.chainId, quakChainId, "unexpected chainId for quakToken");
        assertEq(quakInfo.token, quakAddress, "unexpected token address for quakToken");
        assertEq(quakInfo.decimals, quakDecimals, "unexpected decimals for quakToken");
        assertEq(quakInfo.symbol, quakSymbol, "unexpected symbol for quakToken");
        assertTrue(quakInfo.active, "quakToken not active");

        // check is registered
        assertTrue(core.tokenRegistry.isRegistered(quakChainId, quakAddress), "quack not registered");
        assertFalse(core.tokenRegistry.isRegistered(chainId, quakAddress), "quack registered on local chain");

        // check is active
        assertFalse(core.tokenRegistry.isActive(quakChainId, quakAddress, majorVersion3), "quack active for version 3");

        vm.startPrank(address(registryOwner));
        core.tokenRegistry.setActiveForVersion(quakChainId, quakAddress, majorVersion3, whitelist);
        vm.stopPrank();

        assertTrue(core.tokenRegistry.isActive(quakChainId, quakAddress, majorVersion3), "quack not active for version 3");
    }


    function test_tokenRegistryWhitelistRemoteTokenOnchain() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                TokenRegistry.ErrorTokenRegistryNotRemoteToken.selector,
                chainId,
                address(usdc2)));

        vm.startPrank(address(registryOwner));
        core.tokenRegistry.registerRemoteToken(chainId, address(usdc2), 3, "dummy");
        vm.stopPrank();
    }


    function test_tokenRegistryWhitelistRemoteTokenBadChainIdTokenAddress() public {

        uint256 quakChainId = 123;
        address quakAddress = address(123);
        uint8 quakDecimals = 3;
        string memory quakSymbol = "QUAK123";

        vm.startPrank(address(registryOwner));
        core.tokenRegistry.registerRemoteToken(quakChainId, quakAddress, quakDecimals, quakSymbol);

        // attempt to register quak token 2nd time
        vm.expectRevert(
            abi.encodeWithSelector(
                TokenRegistry.ErrorTokenRegistryTokenAlreadyRegistered.selector,
                quakChainId,
                address(quakAddress)));

        core.tokenRegistry.registerRemoteToken(quakChainId, quakAddress, quakDecimals, quakSymbol);

        // attempt to register quak token for chainId 0
        vm.expectRevert(TokenRegistry.ErrorTokenRegistryChainIdZero.selector);
        core.tokenRegistry.registerRemoteToken(0, quakAddress, quakDecimals, quakSymbol);

        // attempt to register quak token for chainId 0
        vm.expectRevert(TokenRegistry.ErrorTokenRegistryTokenAddressZero.selector);
        core.tokenRegistry.registerRemoteToken(quakChainId, address(0), quakDecimals, quakSymbol);

        vm.stopPrank();
    }


    function test_tokenRegistryBlacklistHappyCase() public {
        vm.startPrank(address(registryOwner));

        core.tokenRegistry.registerToken(address(usdc2));
        core.tokenRegistry.setActiveForVersion(chainId, address(usdc2), majorVersion3, whitelist);

        assertTrue(core.tokenRegistry.isActive(chainId, address(usdc2), majorVersion3), "usdc2 not whitelisted in version 3");

        core.tokenRegistry.setActiveForVersion(chainId, address(usdc2), majorVersion3, blacklist);

        assertFalse(core.tokenRegistry.isActive(chainId, address(usdc2), majorVersion3), "usdc2 not blacklisted in version 3");

        vm.stopPrank();
    }


    function test_tokenRegistryWhitelistNotToken() public {
        vm.expectRevert(
            abi.encodeWithSelector(TokenRegistry.ErrorTokenRegistryTokenNotErc20.selector,
                chainId,
                address(registryService)));

        vm.startPrank(address(registryOwner));
        core.tokenRegistry.registerToken(address(registryService));
        vm.stopPrank();
    }


    function test_tokenRegistryWhitelistNotRegistered() public {
        vm.expectRevert(
            abi.encodeWithSelector(TokenRegistry.ErrorTokenRegistryTokenNotRegistered.selector,
                chainId,
                address(usdc2)));

        vm.startPrank(address(registryOwner));
        core.tokenRegistry.setActiveForVersion(chainId, address(usdc2), majorVersion4, whitelist);
        vm.stopPrank();
    }


    function test_tokenRegistryWhitelistNotContract() public {
        vm.expectRevert(
            abi.encodeWithSelector(TokenRegistry.ErrorTokenRegistryTokenNotContract.selector,
                chainId,
                address(outsider)));

        vm.prank(address(registryOwner));
        core.tokenRegistry.registerToken(outsider);
    }


    function test_tokenRegistryWhitelistInvalidRelease() public {

        // attempt to whitelist for version 2 (too low)
        vm.expectRevert(
            abi.encodeWithSelector(
                TokenRegistry.ErrorTokenRegistryMajorVersionInvalid.selector,
                majorVersion2));

        vm.prank(registryOwner);
        core.tokenRegistry.setActiveForVersion(chainId, address(core.dip), majorVersion2, whitelist);

        // attempt to whitelist for version 4 (too high)
        vm.expectRevert(
            abi.encodeWithSelector(
                TokenRegistry.ErrorTokenRegistryMajorVersionInvalid.selector,
                majorVersion4));
        vm.prank(registryOwner);
        core.tokenRegistry.setActiveForVersion(chainId, address(core.dip), majorVersion4, whitelist);

    }

    function test_tokenRegistryWhitelistingNotOwner() public {

        vm.startPrank(outsider);

        // check restricted for register
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessManaged.AccessManagedUnauthorized.selector, 
                outsider));

        core.tokenRegistry.registerToken(address(usdc2));

        // check restricted for setActive
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessManaged.AccessManagedUnauthorized.selector, 
                outsider));

        core.tokenRegistry.setActiveForVersion(chainId, address(core.dip), majorVersion4, whitelist);

        // check restricted for setActive
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessManaged.AccessManagedUnauthorized.selector, 
                outsider));

        core.tokenRegistry.setActiveWithVersionCheck(chainId, address(core.dip), majorVersion4, whitelist, false);

        vm.stopPrank();
    }

}

