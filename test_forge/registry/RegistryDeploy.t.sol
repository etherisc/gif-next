// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "../../lib/forge-std/src/Test.sol";

import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {IVersionable} from "../../contracts/shared/IVersionable.sol";

import {ChainNft} from "../../contracts/registry/ChainNft.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {RegistryService} from "../../contracts/registry/RegistryService.sol";
import {RegistryServiceManager} from "../../contracts/registry/RegistryServiceManager.sol";

contract RegistryDeploy is Test {

    address public registryOwner = makeAddr("registryOwner");

    RegistryServiceManager public registryServiceManager;
    RegistryService public registryService;
    Registry public registry;
    ChainNft public chainNft;

    function setUp() public virtual {

        vm.startPrank(registryOwner);
        RegistryService implementation = new RegistryService();
        registryServiceManager = new RegistryServiceManager(address(implementation));
        registryService = registryServiceManager.deployRegistryService();
        vm.stopPrank();

        address registryAddress = address(registryService.getRegistry());
        registry = Registry(registryAddress);

        address chainNftAddress = address(registry.getChainNft());
        chainNft = ChainNft(chainNftAddress);
    }

    function test_registryIsDeployed() public {
        // check for zero addresses
        assertTrue(address(registryServiceManager) != address(0), "proxy manager zero");
        assertTrue(address(registryService) != address(0), "registry service zero");
        assertTrue(address(registry) != address(0), "registry zero");
        assertTrue(address(chainNft) != address(0), "chain nft zero");

        // check contract links
        assertEq(address(registryService.getRegistry()), address(registry), "unexpected registry address");
        assertEq(address(registry.getChainNft()), address(chainNft), "unexpected chain nft address");

        // check ownership
        assertEq(registryServiceManager.owner(), registryOwner, "service manager owner not registry owner");
        assertEq(registry.getOwner(), registryOwner, "registry owner not owner of registry");

        // check registered objects
        assertTrue(registry.isRegistered(address(registry)), "registry itself not registered");
        assertTrue(registry.isRegistered(address(registryService)), "registry service not registered");

        console.log("registry owner", address(registryOwner));
        console.log("registry service manager", address(registryServiceManager));
        console.log("registry service manager owner", registryServiceManager.owner());
        console.log("registry service", address(registryService));
        console.log("registry service owner", registryService.getOwner());
        console.log("registry", address(registry));
        console.log("registry owner", registry.getOwner());

        console.log("registered objects", registry.getObjectCount());
    }

}