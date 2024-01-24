// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {console} from "../lib/forge-std/src/Script.sol";
import {TestGifBase} from "./base/TestGifBase.sol";
import {NftId, toNftId, NftIdLib} from "../contracts/types/NftId.sol";
import {PRODUCT_OWNER_ROLE, POOL_OWNER_ROLE} from "../contracts/types/RoleId.sol";

contract TestDeployAll is TestGifBase {
    using NftIdLib for NftId;

    function testDeployAllOverview() public {
        assertEq(registry.getObjectCount(), 9, "invalid object count for base setup");
        
        // validate instance service
        assertTrue(registry.getNftId(address(instanceService)).eq(instanceServiceNftId), "instance service nft does not match");
        assertTrue(address(instanceServiceManager) != address(0), "instance service manager is zero address");

        // validate distribution service
        assertTrue(registry.getNftId(address(distributionService)).eq(distributionServiceNftId), "distribution service nft does not match");
        assertTrue(address(distributionServiceManager) != address(0), "distribution service manager is zero address");

        // validate pool service
        assertTrue(registry.getNftId(address(poolService)).eq(poolServiceNftId), "pool service nft does not match");
        assertTrue(address(poolServiceManager) != address(0), "pool service manager is zero address");

        // validate master instance
        assertTrue(registry.getNftId(address(masterInstance)).eq(masterInstanceNftId), "master instance nft does not match");
        assertTrue(address(masterInstanceAccessManager) != address(0), "master instance access manager is zero address");
        assertTrue(address(masterInstanceReader) != address(0), "master instance reader is zero address");

        // validate created (cloned) instance
        assertTrue(registry.getNftId(address(instance)).eq(instanceNftId), "instance nft does not match");
        assertTrue(address(instanceAccessManager) != address(0), "instance access manager is zero address");
        assertTrue(address(instanceReader) != address(0), "instance reader is zero address");
    }

    // function testDeployAllInstanceOwner() public {
    //     NftId nftId = registry.getNftId(address(instance));
    //     assertEq(
    //         registry.ownerOf(nftId),
    //         instanceOwner,
    //         "unexpected instance owner"
    //     );
    // }

    // function testDeployAllInstanceNftId() public {
    //     NftId nftId = registry.getNftId(address(instance));
    //     assertNftId(
    //         nftId,
    //         instance.getNftId(),
    //         "registry and instance nft id differ"
    //     );
    //     assertNftId(nftId, toNftId(93133705), "instance getNftId not 93133705");
    // }

    // function testDeployAllProductOwner() public {
    //     NftId nftId = registry.getNftId(address(product));
    //     assertEq(
    //         registry.ownerOf(nftId),
    //         productOwner,
    //         "unexpected product owner"
    //     );
    // }

    // function testDeployAllHasProductOwnerRole() public {
    //     // TODO re-enable with new instance
    //     // assertTrue(
    //     //     instance.hasRole(PRODUCT_OWNER_ROLE(), productOwner),
    //     //     "product owner not assigned to product owner"
    //     // );
    //     // assertFalse(
    //     //     instance.hasRole(PRODUCT_OWNER_ROLE(), instanceOwner),
    //     //     "product owner is assigned to instance owner"
    //     // );
    // }

    // function testDeployAllDistributionNftId() public {
    //     NftId nftId = registry.getNftId(address(distribution));
    //     assertNftId(
    //         nftId,
    //         distribution.getNftId(),
    //         "registry and distribution nft id differ"
    //     );
    //     assertNftId(nftId, toNftId(113133705), "distribution getNftId not 113133705");
    // }

    // function testDeployAllProductNftId() public {
    //     NftId nftId = registry.getNftId(address(product));
    //     assertNftId(
    //         nftId,
    //         product.getNftId(),
    //         "registry and product nft id differ"
    //     );
    //     assertNftId(nftId, toNftId(123133705), "product getNftId not 123133705");
    // }

    // function testDeployAllProductPoolDistributionLink() public {
    //     NftId poolNftId = product.getPoolNftId();
    //     NftId distributionNftId = product.getDistributionNftId();
    //     assertNftId(
    //         pool.getNftId(),
    //         poolNftId,
    //         "pool nft id does not match with linked product"
    //     );
    //     assertNftId(
    //         distribution.getNftId(),
    //         distributionNftId,
    //         "distribution nft id does not match with linked product"
    //     );
    // }

    // function testDeployAllPoolNftId() public {
    //     NftId nftId = registry.getNftId(address(pool));
    //     assertNftId(nftId, pool.getNftId(), "registry and pool nft id differ");
    //     assertNftId(nftId, toNftId(103133705), "pool getNftId not 103133705");
    // }
}
