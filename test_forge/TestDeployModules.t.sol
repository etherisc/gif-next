// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {Test} from "../lib/forge-std/src/Test.sol";
import {console} from "../lib/forge-std/src/Script.sol";
import {NftId, toNftId} from "../contracts/types/NftId.sol";

import {ChainNft} from "../contracts/registry/ChainNft.sol";
import {Registry} from "../contracts/registry/Registry.sol";

import {ComponentOwnerService} from "../contracts/instance/service/ComponentOwnerService.sol";
import {ProductService} from "../contracts/instance/service/ProductService.sol";
import {PoolService} from "../contracts/instance/service/PoolService.sol";

import {TestInstanceBase} from "./modules/TestInstanceBase.sol";
import {TestInstanceModuleAccess, TestInstanceModuleBundle, TestInstanceModuleComponent, TestInstanceModulePolicy, TestInstanceModulePool, TestInstanceModuleTreasury} from "./modules/TestInstanceModules.sol";


contract TestDeployModules is Test {

    ChainNft public chainNft;
    Registry public registry;
    address public registryAddress;
    NftId public registryNftId;

    ComponentOwnerService public componentOwnerService;
    ProductService public productService;
    PoolService public poolService;

    address public instanceOwner = makeAddr("instanceOwner");

    function setUp() public virtual {
        registry = new Registry();
        registryAddress = address(registry);
        registryNftId = registry.getNftId();

        chainNft = new ChainNft(registryAddress);
        registry.initialize(address(chainNft));

        componentOwnerService = new ComponentOwnerService(registryAddress, registryNftId);
        productService = new ProductService(registryAddress, registryNftId);
        poolService = new PoolService(registryAddress, registryNftId);
    }

    function testInstanceBase() public {
        vm.prank(instanceOwner);
        TestInstanceBase instance = new TestInstanceBase(
            registryAddress, 
            registryNftId);
        instance.register();
    }

    function testInstanceAccess() public {
        vm.prank(instanceOwner);
        TestInstanceModuleAccess instance = new TestInstanceModuleAccess(
            registryAddress, 
            registryNftId);
        instance.register();
    }

    function testInstanceModuleBundle() public {
        vm.prank(instanceOwner);
        TestInstanceModuleBundle instance = new TestInstanceModuleBundle(registryAddress, registryNftId);
        instance.register();
    }

    function testInstanceModuleComponent() public {
        vm.prank(instanceOwner);
        TestInstanceModuleComponent instance = new TestInstanceModuleComponent(registryAddress, registryNftId);
        instance.register();
    }

    function testInstanceModulePolicy() public {
        vm.prank(instanceOwner);
        TestInstanceModulePolicy instance = new TestInstanceModulePolicy(registryAddress, registryNftId);
        instance.register();
    }

    function testInstanceModulePool() public {
        vm.prank(instanceOwner);
        TestInstanceModulePool instance = new TestInstanceModulePool(registryAddress, registryNftId);
        instance.register();
    }

    function testInstanceModuleTreasury() public {
        vm.prank(instanceOwner);
        TestInstanceModuleTreasury instance = new TestInstanceModuleTreasury(registryAddress, registryNftId);
        instance.register();
    }
}
