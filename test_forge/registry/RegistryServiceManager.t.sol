// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "../../lib/forge-std/src/Test.sol";

import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {IVersionable} from "../../contracts/shared/IVersionable.sol";

import {ChainNft} from "../../contracts/registry/ChainNft.sol";
import {NftId, toNftId} from "../../contracts/types/NftId.sol";
import {NftOwnable} from "../../contracts/shared/NftOwnable.sol";
import {ProxyManager} from "../../contracts/shared/ProxyManager.sol";
import {RegistryServiceManager} from "../../contracts/registry/RegistryServiceManager.sol";
import {RegistryService} from "../../contracts/registry/RegistryService.sol";
import {RegistryServiceMock} from "../mock/RegistryServiceMock.sol";
import {RegistryServiceUpgradeMock} from "../mock/RegistryServiceUpgradeMock.sol";
import {Version, VersionLib} from "../../contracts/types/Version.sol";

contract RegistryServiceManagerTest is Test {

    address public registryOwner = makeAddr("registryOwner");
    address public registryOwnerNew = makeAddr("registryOwnerNew");

    // ProxyManager public proxyManager;
    RegistryServiceManager public registryServiceManager;
    RegistryService public registryService;
    IRegistry public registry;
    ChainNft public chainNft;

    function setUp() public {

        vm.prank(registryOwner);
        registryServiceManager = new RegistryServiceManager();

        registryService = registryServiceManager.getRegistryService();
        registry = registryServiceManager.getRegistry();

        address chainNftAddress = address(registry.getChainNft());
        chainNft = ChainNft(chainNftAddress);
    }

    function test_deployedRegistryAndRegistryService() public {

        // solhint-disable no-console
        console.log("registry owner", address(registryOwner));
        console.log("registry service manager", address(registryServiceManager));
        console.log("registry service manager nft", registryServiceManager.getNftId().toInt());
        console.log("registry service manager owner", registryServiceManager.getOwner());
        console.log("registry service", address(registryService));
        console.log("registry service nft", registryService.getNftId().toInt());
        console.log("registry service owner", registryService.getOwner());
        console.log("registry", address(registry));
        console.log("registry nft", registry.getNftId(address(registry)).toInt());
        console.log("registry owner (opt 1)", registry.ownerOf(address(registry)));
        console.log("registry owner (opt 2)", registry.getOwner());
        // solhint-enable

        console.log("registered objects", registry.getObjectCount());
        _logObject("protocol", toNftId(1101));
        _logObject("globalRegistry", toNftId(2101));
        _logObject("chainRegistry", address(registry));
        _logObject("registryService", address(registryService));

        // check for zero addresses
        assertTrue(address(registryServiceManager) != address(0), "registry installer zero");
        assertTrue(address(registryService) != address(0), "registry service zero");
        assertTrue(address(registry) != address(0), "registry zero");
        assertTrue(address(chainNft) != address(0), "chain nft zero");

        // check contract links
        assertEq(address(registryService.getRegistry()), address(registry), "unexpected registry address");
        assertEq(address(registry.getChainNft()), address(chainNft), "unexpected chain nft address");

        // check ownership
        assertEq(registryServiceManager.getOwner(), registryOwner, "service manager owner not registry owner");
        assertEq(registry.getOwner(), registryOwner, "registry owner not owner of registry");
        assertEq(registry.getOwner(), registry.ownerOf(address(registry)), "non matching registry owners");

        // check registered objects
        assertTrue(registry.isRegistered(address(registry)), "registry itself not registered");
        assertTrue(registry.isRegistered(address(registryService)), "registry service not registered");
    }

    function test_attemptsToRedeployedRegistryService() public {
        address mockImplementation = address(new RegistryServiceMock());
        bytes memory emptyInitializationData;

        // check ownership
        assertEq(registryServiceManager.getOwner(), registryOwner, "service manager owner not registry owner");

        // attempt to redploy with non-owner account
        vm.expectRevert(
            abi.encodeWithSelector(
                NftOwnable.ErrorNftOwnableUnauthorized.selector,
                registryOwnerNew));
        vm.prank(registryOwnerNew);
        registryServiceManager.deploy(
            mockImplementation,
            emptyInitializationData);

        // attempt to redploy with owner account
        vm.expectRevert(
            abi.encodeWithSelector(
                ProxyManager.ErrorAlreadyDeployed.selector));
        vm.prank(registryOwner);
        registryServiceManager.deploy(
            mockImplementation,
            emptyInitializationData);
    }

    function test_attemptsToUpgradeRegistryService() public {
        address upgradeMockImplementation = address(new RegistryServiceUpgradeMock());
        bytes memory emptyUpgradeData;

        // check ownership
        assertEq(registryServiceManager.getOwner(), registryOwner, "service manager owner not registry owner");

        // attempt to redploy with non-owner account
        vm.expectRevert(
            abi.encodeWithSelector(
                NftOwnable.ErrorNftOwnableUnauthorized.selector,
                registryOwnerNew));
        vm.prank(registryOwnerNew);
        registryServiceManager.upgrade(
            upgradeMockImplementation,
            emptyUpgradeData);

        assertEq(registryService.getVersion().toInt(), VersionLib.toVersion(3, 0, 0).toInt(), "unexpected registry service before upgrad");
        assertEq(registryService.getVersionCount(), 1, "version count not 1 before upgrade");

        // attempt to redploy with owner account
        vm.prank(registryOwner);
        registryServiceManager.upgrade(
            upgradeMockImplementation,
            emptyUpgradeData);

        RegistryServiceUpgradeMock registryServiceUpgraded = RegistryServiceUpgradeMock(
            address(registryService));

        assertEq(registryServiceUpgraded.getVersion().toInt(), VersionLib.toVersion(3, 0, 1).toInt(), "unexpected registry service after upgrad");
        assertEq(registryServiceUpgraded.getVersionCount(), 2, "version count not 2 after upgrade");

        assertEq(registryServiceUpgraded.getMessage(), "hi from upgrade mock", "unexpected message from upgraded registry service");
    }


    function test_transferAndUpgradeRegistryService() public {
        address upgradeMockImplementation = address(new RegistryServiceUpgradeMock());
        address registryServiceAddress = address(registryService);
        bytes memory emptyUpgradeData;

        // check initial ownership
        assertEq(registry.ownerOf(registryServiceAddress), registryOwner, "registry service owner not registry owner");
        assertEq(registryServiceManager.getOwner(), registryOwner, "registry service manager owner not registry owner");

        // transfer ownership by transferring nft
        NftId registryServiceNft = registry.getNftId(registryServiceAddress);

        vm.startPrank(registryOwner);
        chainNft.approve(registryOwnerNew, registryServiceNft.toInt());
        chainNft.safeTransferFrom(registryOwner, registryOwnerNew, registryServiceNft.toInt(), "");
        vm.stopPrank();

        // check ownership after transfer
        assertEq(registry.ownerOf(registryServiceAddress), registryOwnerNew, "registry service owner not registry owner");
        assertEq(registryServiceManager.getOwner(), registryOwnerNew, "registry service manager owner not registry owner");

        // attempt to upgrade with old owner
        vm.expectRevert(
            abi.encodeWithSelector(
                NftOwnable.ErrorNftOwnableUnauthorized.selector,
                registryOwner));
        vm.prank(registryOwner);
        registryServiceManager.upgrade(
            upgradeMockImplementation,
            emptyUpgradeData);

        // attempt to upgrade with new owner
        vm.prank(registryOwnerNew);
        registryServiceManager.upgrade(
            upgradeMockImplementation,
            emptyUpgradeData);

        RegistryServiceUpgradeMock registryServiceUpgraded = RegistryServiceUpgradeMock(
            address(registryService));

        assertEq(registryServiceUpgraded.getVersion().toInt(), VersionLib.toVersion(3, 0, 1).toInt(), "unexpected registry service after upgrad");
        assertEq(registryServiceUpgraded.getVersionCount(), 2, "version count not 2 after upgrade");

        assertEq(registryServiceUpgraded.getMessage(), "hi from upgrade mock", "unexpected message from upgraded registry service");
    }


    function _logObject(string memory prefix, address object) internal view {
        NftId nftId = registry.getNftId(object);
        _logObject(prefix, nftId);
    }

    function _logObject(string memory prefix, NftId nftId) internal view {
        IRegistry.ObjectInfo memory info = registry.getObjectInfo(nftId);

        // solhint-disable no-console
        console.log(prefix, "nftId", nftId.toInt());
        console.log(prefix, "parentNftId", info.parentNftId.toInt());
        console.log(prefix, "type", info.objectType.toInt());
        console.log(prefix, "address", info.objectAddress);
        console.log(prefix, "owner", registry.ownerOf(nftId));
        // solhint-enable
    }

}