// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

import {Registry} from "../contracts/registry/Registry.sol";
import {Instance} from "../contracts/instance/Instance.sol";
import {ComponentOwnerService} from "../contracts/instance/component/ComponentModule.sol";
import {TestProduct} from "../test_forge/mock/TestProduct.sol";

contract DeployAll is Script {

    function run(
        address instanceOwner,
        address productOwner
    )
        external
        returns (
            Registry,
            Instance,
            TestProduct
        )
    {

        // HelperConfig helperConfig = new HelperConfig();
        // HelperConfig.NetworkConfig memory config = HelperConfig.NetworkConfig(helperConfig.activeNetworkConfig());
        // address dipAddress = config.dipAddress;

        console.log("tx origin", tx.origin);

        vm.startBroadcast();
        Registry registry = new Registry();
        console.log("registry deployed at", address(registry));

        ComponentOwnerService componentOwnerService = new ComponentOwnerService();
        Instance instance = new Instance(
            address(registry), 
            address(componentOwnerService));
        console.log("instance deployed at", address(instance));

        TestProduct product = new TestProduct(address(instance));
        console.log("product deployed at", address(product));

        bytes32 productOwnerRole = instance.getRoleForName("ProductOwner");
        instance.grantRole(productOwnerRole, address(tx.origin));
        instance.grantRole(productOwnerRole, productOwner);

        uint256 instanceNftId = instance.register();
        uint256 productNftId = componentOwnerService.register(product);

        registry.transfer(instanceNftId, instanceOwner);
        registry.transfer(productNftId, productOwner);
        vm.stopBroadcast();

        return (
            registry,
            instance,
            product
        );
    }

}