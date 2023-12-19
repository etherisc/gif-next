// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "../../lib/forge-std/src/Test.sol";

import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {IVersionable} from "../../contracts/shared/IVersionable.sol";

import {ChainNft} from "../../contracts/registry/ChainNft.sol";
import {NftId, toNftId} from "../../contracts/types/NftId.sol";
import {ProxyManager} from "../../contracts/shared/ProxyManager.sol";
// import {Registry} from "../../contracts/registry/Registry.sol";
import {RegistryInstaller} from "../../contracts/registry/RegistryInstaller.sol";
import {RegistryService} from "../../contracts/registry/RegistryService.sol";

contract RegistryInstallerTest is Test {

    address public registryOwner = makeAddr("registryOwner");

    // ProxyManager public proxyManager;
    RegistryInstaller public registryInstaller;
    RegistryService public registryService;
    IRegistry public registry;
    ChainNft public chainNft;

    function setUp() public {

        vm.prank(registryOwner);
        registryInstaller = new RegistryInstaller();

        registryService = registryInstaller.getRegistryService();
        registry = registryInstaller.getRegistry();

        address chainNftAddress = address(registry.getChainNft());
        chainNft = ChainNft(chainNftAddress);
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

    function test_registryIsDeployed() public {

        // solhint-disable no-console
        console.log("registry owner", address(registryOwner));
        console.log("registry installer", address(registryInstaller));
        console.log("registry installer owner", registryInstaller.owner());
        console.log("registry service", address(registryService));
        console.log("registry service owner", registryService.getOwner());
        console.log("registry", address(registry));
        console.log("registry owner", registry.getOwner());
        // solhint-enable

        console.log("registered objects", registry.getObjectCount());
        _logObject("protocol", toNftId(1101));
        _logObject("globalRegistry", toNftId(2101));
        _logObject("chainRegistry", address(registry));
        _logObject("registryService", address(registryService));

        // check for zero addresses
        assertTrue(address(registryInstaller) != address(0), "registry installer zero");
        assertTrue(address(registryService) != address(0), "registry service zero");
        assertTrue(address(registry) != address(0), "registry zero");
        assertTrue(address(chainNft) != address(0), "chain nft zero");

        // check contract links
        assertEq(address(registryService.getRegistry()), address(registry), "unexpected registry address");
        assertEq(address(registry.getChainNft()), address(chainNft), "unexpected chain nft address");

        // check ownership
        assertEq(registryInstaller.owner(), registryOwner, "service manager owner not registry owner");
        assertEq(registry.getOwner(), registryOwner, "registry owner not owner of registry");

        // check registered objects
        assertTrue(registry.isRegistered(address(registry)), "registry itself not registered");
        assertTrue(registry.isRegistered(address(registryService)), "registry service not registered");
    }

}