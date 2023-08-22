// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import "../lib/forge-std/src/Test.sol";
import {console} from "../lib/forge-std/src/Script.sol";

import {DeployAll} from "../scripts/DeployAll.s.sol";

import {Registry} from "../contracts/registry/Registry.sol";
import {Instance} from "../contracts/instance/Instance.sol";
import {IComponent} from "../contracts/instance/component/IComponent.sol";
import {TestProduct} from "./mock/TestProduct.sol";

contract TestComponentInfo is Test {

    Registry registry;
    Instance instance;
    TestProduct product;

    address instanceOwner = makeAddr("instanceOwner");
    address productOwner = makeAddr("productOwner");

    function setUp() external {
        DeployAll deployer = new DeployAll();
        (
            registry, 
            instance, 
            product
        ) = deployer.run(
            instanceOwner,
            productOwner);
    }

    function testComponentInfo() public {
        IComponent.ComponentInfo memory info = instance.getComponentInfo(product.getNftId());
        console.log("info(id, address, type, state");
        console.log(info.id, info.cAddress, info.cType, uint(info.state));

        assertEq(info.id, 2, "product id not 2");
        assertEq(info.cAddress, address(product), "product address wrong");
        assertEq(info.cType, registry.PRODUCT(), "component type not product");
        assertEq(uint256(info.state), uint256(IComponent.CState.Active), "component state not active");
    }
}
