// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {console} from "../lib/forge-std/src/Script.sol";
import {TestGifBase} from "./base/TestGifBase.sol";
import {NftId, toNftId} from "../contracts/types/NftId.sol";

contract TestDeployAll is TestGifBase {
    function testDeployAllRegistryCountWithProduct() public {
        assertEq(registry.getObjectCount(), 9, "getObjectCount not 9");
    }

    function testDeployAllInstanceOwner() public {
        NftId nftId = registry.getNftId(address(instance));
        assertEq(
            registry.getOwner(nftId),
            instanceOwner,
            "unexpected instance owner"
        );
    }

    function testDeployAllInstanceNftId() public {
        NftId nftId = registry.getNftId(address(instance));
        assertNftId(
            nftId,
            instance.getNftId(),
            "registry and instance nft id differ"
        );
        assertNftId(nftId, toNftId(63133705), "instance getNftId not 63133705");
    }

    function testDeployAllProductOwner() public {
        NftId nftId = registry.getNftId(address(product));
        assertEq(
            registry.getOwner(nftId),
            productOwner,
            "unexpected product owner"
        );
    }

    function testDeployAllHasProductOwnerRole() public {
        bytes32 productOwnerRole = instance.getRoleForName("ProductOwner");
        assertTrue(
            instance.hasRole(productOwnerRole, productOwner),
            "product owner not assigned to product owner"
        );
        assertFalse(
            instance.hasRole(productOwnerRole, instanceOwner),
            "product owner is assigned to instance owner"
        );
    }

    function testDeployAllProductNftId() public {
        NftId nftId = registry.getNftId(address(product));
        assertNftId(
            nftId,
            product.getNftId(),
            "registry and product nft id differ"
        );
        assertNftId(nftId, toNftId(83133705), "product getNftId not 83133705");
    }

    function testDeployAllProductPoolLink() public {
        NftId poolNftId = product.getPoolNftId();
        assertNftId(
            pool.getNftId(),
            poolNftId,
            "pool nft id does not match with linked product"
        );
    }

    function testDeployAllPoolNftId() public {
        NftId nftId = registry.getNftId(address(pool));
        assertNftId(nftId, pool.getNftId(), "registry and pool nft id differ");
        assertNftId(nftId, toNftId(73133705), "pool getNftId not 73133705");
    }
}
