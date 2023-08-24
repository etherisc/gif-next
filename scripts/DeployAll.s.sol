// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

import {Registry} from "../contracts/registry/Registry.sol";
import {Instance} from "../contracts/instance/Instance.sol";
import {IComponentOwnerService} from "../contracts/instance/component/IComponent.sol";
import {ComponentOwnerService} from "../contracts/instance/component/ComponentModule.sol";
import {ProductService} from "../contracts/instance/product/ProductService.sol";
import {TestProduct} from "../test_forge/mock/TestProduct.sol";
import {TestPool} from "../test_forge/mock/TestPool.sol";

contract DeployAll is Script {

    function run(
        address instanceOwner,
        address productOwner,
        address poolOwner
    )
        external
        returns (
            Registry,
            Instance,
            TestProduct,
            TestPool
        )
    {

        // HelperConfig helperConfig = new HelperConfig();
        // HelperConfig.NetworkConfig memory config = HelperConfig.NetworkConfig(helperConfig.activeNetworkConfig());
        // address dipAddress = config.dipAddress;

        console.log("tx origin", tx.origin);

        vm.startBroadcast();
        Registry registry = _deployRegistry();
        Instance instance = _deployInstance(registry);
        TestPool pool = _deployPool(registry, instance);
        TestProduct product = _deployProduct(registry, instance, pool);
        _registerAndTransfer(registry, instance, product, pool, instanceOwner, productOwner, poolOwner);
        vm.stopBroadcast();

        return (
            registry,
            instance,
            product,
            pool
        );
    }

    function _deployRegistry() internal returns(Registry registry) {
        registry = new Registry();
        console.log("registry deployed at", address(registry));
    }

    function _deployInstance(Registry registry) internal returns(Instance instance) {
        ComponentOwnerService componentOwnerService = new ComponentOwnerService(
            address(registry));

        ProductService productService = new ProductService(
            address(registry));

        instance = new Instance(
            address(registry),
            address(componentOwnerService),
            address(productService));

        console.log("instance deployed at", address(instance));
    }

    function _deployPool(Registry registry, Instance instance) internal returns(TestPool pool) {
        pool = new TestPool(address(registry), address(instance));
        console.log("pool deployed at", address(pool));
    }

    function _deployProduct(Registry registry, Instance instance, TestPool pool) internal returns(TestProduct product) {
        product = new TestProduct(address(registry), address(instance), address(pool));
        console.log("product deployed at", address(product));
    }

    function _registerAndTransfer(
        Registry registry,
        Instance instance, 
        TestProduct product, 
        TestPool pool, 
        address instanceOwner,
        address productOwner,
        address poolOwner
    )
        internal
    {
        uint256 instanceNftId = instance.register();
        IComponentOwnerService componentOwnerService = instance.getComponentOwnerService();

        // register pool
        bytes32 poolOwnerRole = instance.getRoleForName("PoolOwner");
        instance.grantRole(poolOwnerRole, address(tx.origin));
        instance.grantRole(poolOwnerRole, poolOwner);

        uint256 poolNftId = componentOwnerService.register(pool);

        // register product
        bytes32 productOwnerRole = instance.getRoleForName("ProductOwner");
        instance.grantRole(productOwnerRole, address(tx.origin));
        instance.grantRole(productOwnerRole, productOwner);

        uint256 productNftId = componentOwnerService.register(product);

        // transfer ownerships
        registry.transfer(instanceNftId, instanceOwner);
        registry.transfer(productNftId, productOwner);
        registry.transfer(poolNftId, poolOwner);
    }

}