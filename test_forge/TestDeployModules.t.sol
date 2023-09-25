// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {Test} from "../lib/forge-std/src/Test.sol";
import {console} from "../lib/forge-std/src/Script.sol";
import {NftId, toNftId} from "../contracts/types/NftId.sol";

import {DeployInstance} from "../scripts/DeployInstance.s.sol";

import {ChainNft} from "../contracts/registry/ChainNft.sol";
import {IRegistry} from "../contracts/registry/IRegistry.sol";
import {Registry} from "../contracts/registry/Registry.sol";
import {Instance} from "../contracts/instance/Instance.sol";

import {ComponentOwnerService} from "../contracts/instance/service/ComponentOwnerService.sol";
import {ProductService} from "../contracts/instance/service/ProductService.sol";
import {PoolService} from "../contracts/instance/service/PoolService.sol";

import {TestInstanceBase} from "./modules/TestInstanceBase.sol";
import {TestInstanceModuleAccess, TestInstanceModuleBundle, TestInstanceModuleComponent, TestInstanceModulePolicy, TestInstanceModulePool, TestInstanceModuleTreasury} from "./modules/TestInstanceModules.sol";


contract TestDeployModules is Test {
    IRegistry public registry;
    address public registryAddress;
    NftId public registryNftId;

    address public registryOwner = makeAddr("registryOwner");
    address public instanceOwner = makeAddr("instanceOwner");

    function setUp() external {
        DeployInstance di = new DeployInstance();
        Instance instanceFull = di.run(registryOwner, instanceOwner);
        registry = instanceFull.getRegistry();

        registryAddress = address(registry);
        registryNftId = registry.getNftId();
    }

    function testInstanceBase() public {
        vm.prank(instanceOwner);
        TestInstanceBase instance = new TestInstanceBase(
            registryAddress, 
            registryNftId);

        vm.prank(instanceOwner);
        instance.register();
    }

    function testInstanceAccess() public {
        vm.prank(instanceOwner);
        TestInstanceModuleAccess instance = new TestInstanceModuleAccess(
            registryAddress, 
            registryNftId);

        vm.prank(instanceOwner);
        instance.register();
    }

    function testInstanceModuleBundle() public {
        vm.prank(instanceOwner);
        TestInstanceModuleBundle instance = new TestInstanceModuleBundle(registryAddress, registryNftId);

        vm.prank(instanceOwner);
        instance.register();
    }

    function testInstanceModuleComponent() public {
        vm.prank(instanceOwner);
        TestInstanceModuleComponent instance = new TestInstanceModuleComponent(registryAddress, registryNftId);

        vm.prank(instanceOwner);
        instance.register();
    }

    function testInstanceModulePolicy() public {
        vm.prank(instanceOwner);
        TestInstanceModulePolicy instance = new TestInstanceModulePolicy(registryAddress, registryNftId);

        vm.prank(instanceOwner);
        instance.register();
    }

    function testInstanceModulePool() public {
        vm.prank(instanceOwner);
        TestInstanceModulePool instance = new TestInstanceModulePool(registryAddress, registryNftId);

        vm.prank(instanceOwner);
        instance.register();
    }

    function testInstanceModuleTreasury() public {
        vm.prank(instanceOwner);
        TestInstanceModuleTreasury instance = new TestInstanceModuleTreasury(registryAddress, registryNftId);

        vm.prank(instanceOwner);
        instance.register();
    }
}
