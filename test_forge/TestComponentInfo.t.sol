// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import "../lib/forge-std/src/Test.sol";
import {console} from "../lib/forge-std/src/Script.sol";

import {DeployAll} from "../scripts/DeployAll.s.sol";

import {Registry} from "../contracts/registry/Registry.sol";
import {Instance} from "../contracts/instance/Instance.sol";
import {IComponent} from "../contracts/instance/component/IComponent.sol";
import {TestProduct} from "./mock/TestProduct.sol";
import {TestPool} from "./mock/TestPool.sol";

contract TestComponentInfo is Test {

    Registry registry;
    Instance instance;
    TestProduct product;
    TestPool pool;

    address instanceOwner = makeAddr("instanceOwner");
    address productOwner = makeAddr("productOwner");
    address poolOwner = makeAddr("poolOwner");

    function setUp() external {
        DeployAll deployer = new DeployAll();
        (
            registry, 
            instance, 
            product,
            pool
        ) = deployer.run(
            instanceOwner,
            productOwner,
            poolOwner);
    }

    function testProductInfo() public {
        IComponent.ComponentInfo memory info = instance.getComponentInfo(product.getNftId());
        console.log("product (nftId, state)");
        console.log(info.nftId, uint(info.state));

        assertEq(info.nftId, 2, "product id not 2");
        assertEq(uint256(info.state), uint256(IComponent.CState.Active), "component state not active");
    }

    function testPoolInfo() public {
        IComponent.ComponentInfo memory info = instance.getComponentInfo(pool.getNftId());
        console.log("pool (nftId, state)");
        console.log(info.nftId, uint(info.state));

        assertEq(info.nftId, 3, "pool id not 3");
        assertEq(uint256(info.state), uint256(IComponent.CState.Active), "component state not active");
    }
}
