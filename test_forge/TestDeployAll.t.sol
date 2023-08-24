// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import "../lib/forge-std/src/Test.sol";
import {console} from "../lib/forge-std/src/Script.sol";

import {DeployAll} from "../scripts/DeployAll.s.sol";

import {Registry} from "../contracts/registry/Registry.sol";
import {Instance} from "../contracts/instance/Instance.sol";
import {TestProduct} from "./mock/TestProduct.sol";
import {TestPool} from "./mock/TestPool.sol";

contract TestDeployAll is Test {

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

    function testDeployAllRegistryCountWithProduct() public {
        assertEq(registry.getObjectCount(), 3, "getObjectCount not 3");
    }

    function testDeployAllInstanceOwner() public {
        uint256 nftId = registry.getNftId(address(instance));
        assertEq(registry.getOwner(nftId), instanceOwner, "unexpected instance owner");
    }

    function testDeployAllInstanceNftId() public {
        uint256 nftId = registry.getNftId(address(instance));
        assertEq(nftId, 1, "getNftId not 1");
        assertEq(nftId, instance.getNftId(), "registry and instance nft id differ");
    }

    function testDeployAllProductOwner() public {
        uint256 nftId = registry.getNftId(address(product));
        assertEq(registry.getOwner(nftId), productOwner, "unexpected product owner");
    }

    function testDeployAllHasProductOwnerRole() public {
        bytes32 productOwnerRole = instance.getRoleForName("ProductOwner");
        assertTrue(instance.hasRole(productOwnerRole, productOwner), "product owner not assigned to product owner");
        assertFalse(instance.hasRole(productOwnerRole, instanceOwner), "product owner is assigned to instance owner");
    }

    function testDeployAllProductNftId() public {
        uint256 nftId = registry.getNftId(address(product));
        assertEq(nftId, 3, "product getNftId not 3");
        assertEq(nftId, product.getNftId(), "registry and product nft id differ");
    }

    function testDeployAllProductPoolLink() public {
        uint256 poolNftId = product.getPoolNftId();
        assertEq(pool.getNftId(), poolNftId, "pool nft id does not match with linked product");
    }

    function testDeployAllPoolNftId() public {
        uint256 nftId = registry.getNftId(address(pool));
        assertEq(nftId, 2, "pool getNftId not 2");
        assertEq(nftId, pool.getNftId(), "registry and pool nft id differ");
    }
}
