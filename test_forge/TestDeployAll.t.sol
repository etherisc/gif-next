// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {console} from "../lib/forge-std/src/Script.sol";
import {TestGifBase} from "./TestGifBase.sol";

contract TestDeployAll is TestGifBase {

    function testDeployAllRegistryCountWithProduct() public {
        assertEq(registry.getObjectCount(), 3, "getObjectCount not 3");
    }

    function testDeployAllInstanceOwner() public {
        uint256 nftId = registry.getNftId(address(instance));
        assertEq(registry.getOwner(nftId), instanceOwner, "unexpected instance owner");
    }

    function testDeployAllInstanceNftId() public {
        uint256 nftId = registry.getNftId(address(instance));
        assertEq(nftId, instance.getNftId(), "registry and instance nft id differ");
        assertNftId(nftId, 23133705, "instance getNftId not 23133705");
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
        assertEq(nftId, product.getNftId(), "registry and product nft id differ");
        assertNftId(nftId, 43133705, "product getNftId not 43133705");
    }

    function testDeployAllProductPoolLink() public {
        uint256 poolNftId = product.getPoolNftId();
        assertEq(pool.getNftId(), poolNftId, "pool nft id does not match with linked product");
    }

    function testDeployAllPoolNftId() public {
        uint256 nftId = registry.getNftId(address(pool));
        assertEq(nftId, pool.getNftId(), "registry and pool nft id differ");
        assertNftId(nftId, 33133705, "pool getNftId not 33133705");
    }
}
