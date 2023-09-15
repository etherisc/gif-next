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
import {TestInstanceModuleBundle, TestInstanceModuleComponent, TestInstanceModulePolicy, TestInstanceModuleProduct, TestInstanceModulePool, TestInstanceModuleTreasury} from "./modules/TestInstanceModules.sol";


contract TestDeployModules is Test {

    ChainNft public chainNft;
    Registry public registry;

    ComponentOwnerService public componentOwnerService;
    ProductService public productService;
    PoolService public poolService;

    address public instanceOwner = makeAddr("instanceOwner");

    function setUp() public virtual {
        registry = new Registry();
        chainNft = new ChainNft(address(registry));
        registry.initialize(address(chainNft));

        componentOwnerService = new ComponentOwnerService(address(registry));
        productService = new ProductService(address(registry));
        poolService = new PoolService(address(registry));
    }

    function testInstanceBase() public {
        vm.prank(instanceOwner);
        TestInstanceBase instance = new TestInstanceBase(address(registry), address(componentOwnerService), address(productService), address(poolService));
        instance.register();
    }

    function testInstanceModuleBundle() public {
        vm.prank(instanceOwner);
        TestInstanceModuleBundle instance = new TestInstanceModuleBundle(address(registry), address(componentOwnerService), address(productService), address(poolService));
        instance.register();
    }

    function testInstanceModuleComponent() public {
        vm.prank(instanceOwner);
        TestInstanceModuleComponent instance = new TestInstanceModuleComponent(address(registry), address(componentOwnerService), address(productService), address(poolService));
        instance.register();
    }

    function testInstanceModulePolicy() public {
        vm.prank(instanceOwner);
        TestInstanceModulePolicy instance = new TestInstanceModulePolicy(address(registry), address(componentOwnerService), address(productService), address(poolService));
        instance.register();
    }

    function testInstanceModuleProduct() public {
        vm.prank(instanceOwner);
        TestInstanceModuleProduct instance = new TestInstanceModuleProduct(address(registry), address(componentOwnerService), address(productService), address(poolService));
        instance.register();
    }

    function testInstanceModulePool() public {
        vm.prank(instanceOwner);
        TestInstanceModulePool instance = new TestInstanceModulePool(address(registry), address(componentOwnerService), address(productService), address(poolService));
        instance.register();
    }

    function testInstanceModuleTreasury() public {
        vm.prank(instanceOwner);
        TestInstanceModuleTreasury instance = new TestInstanceModuleTreasury(address(registry), address(componentOwnerService), address(productService), address(poolService));
        instance.register();
    }
}
