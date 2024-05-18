// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../lib/forge-std/src/Script.sol";
import {GifTest} from "./base/GifTest.sol";
import {IRegistry} from "../contracts/registry/IRegistry.sol";
import {IStaking} from "../contracts/staking/IStaking.sol";
import {IStakingService} from "../contracts/staking/IStakingService.sol";
import {NftId, NftIdLib} from "../contracts/type/NftId.sol";
import {BUNDLE, COMPONENT, POLICY, RISK, SERVICE, STAKING} from "../contracts/type/ObjectType.sol";
import {PRODUCT_OWNER_ROLE, POOL_OWNER_ROLE} from "../contracts/type/RoleId.sol";

contract TestDeployAll is GifTest {
    using NftIdLib for NftId;

    function test_deployAllOverview() public {
        assertEq(registry.getObjectCount(), 19, "invalid object count for base setup");

        // validate registry service
        assertTrue(registry.getNftId(address(registryService)).eq(registryServiceNftId), "registry service nft does not match");
        assertTrue(address(registryServiceManager) != address(0), "registry service manager is zero address");

        // validate staking service
        assertTrue(registry.getNftId(address(stakingService)).eq(stakingServiceNftId), "staking service nft does not match");
        assertTrue(address(stakingServiceManager) != address(0), "staking service manager is zero address");

        // validate instance service
        assertTrue(registry.getNftId(address(instanceService)).eq(instanceServiceNftId), "instance service nft does not match");
        assertTrue(address(instanceServiceManager) != address(0), "instance service manager is zero address");

        // validate component service
        assertTrue(registry.getNftId(address(componentService)).eq(componentServiceNftId), "instance service nft does not match");
        assertTrue(address(componentServiceManager) != address(0), "instance service manager is zero address");

        // validate distribution service
        assertTrue(registry.getNftId(address(distributionService)).eq(distributionServiceNftId), "distribution service nft does not match");
        assertTrue(address(distributionServiceManager) != address(0), "distribution service manager is zero address");

        // validate pricing service
        assertTrue(registry.getNftId(address(pricingService)).eq(pricingServiceNftId), "pricing service nft does not match");
        assertTrue(address(pricingServiceManager) != address(0), "pricing service manager is zero address");

        // validate bundle service
        assertTrue(registry.getNftId(address(bundleService)).eq(bundleServiceNftId), "bundle service nft does not match");
        assertTrue(address(bundleServiceManager) != address(0), "bundle service manager is zero address");

        // validate pool service
        assertTrue(registry.getNftId(address(poolService)).eq(poolServiceNftId), "pool service nft does not match");
        assertTrue(address(poolServiceManager) != address(0), "pool service manager is zero address");

        // validate oracle service
        assertTrue(registry.getNftId(address(oracleService)).eq(oracleServiceNftId), "oracle service nft does not match");
        assertTrue(address(oracleServiceManager) != address(0), "oracle service manager is zero address");

        // validate product service
        assertTrue(registry.getNftId(address(productService)).eq(productServiceNftId), "product service nft does not match");
        assertTrue(address(productServiceManager) != address(0), "product service manager is zero address");

        // validate claim service
        assertTrue(registry.getNftId(address(claimService)).eq(claimServiceNftId), "claim service nft does not match");
        assertTrue(address(claimServiceManager) != address(0), "claim service manager is zero address");

        // validate application service
        assertTrue(registry.getNftId(address(applicationService)).eq(applicationServiceNftId), "application service nft does not match");
        assertTrue(address(applicationServiceManager) != address(0), "application service manager is zero address");

        // validate policy service
        assertTrue(registry.getNftId(address(policyService)).eq(policyServiceNftId), "policy service nft does not match");
        assertTrue(address(policyServiceManager) != address(0), "policy service manager is zero address");

        // validate master instance
        assertTrue(registry.getNftId(address(masterInstance)).eq(masterInstanceNftId), "master instance nft does not match");
        assertTrue(address(masterInstanceAdmin) != address(0), "master instance admin is zero address");
        assertTrue(address(masterInstanceReader) != address(0), "master instance reader is zero address");

        // validate created (cloned) instance
        assertTrue(registry.getNftId(address(instance)).eq(instanceNftId), "instance nft does not match");
        assertTrue(address(instanceAdmin) != address(0), "instance admin is zero address");
        assertTrue(address(instanceReader) != address(0), "instance reader is zero address");
    }

    function test_deployAllInstanceOwner() public {
        NftId nftId = registry.getNftId(address(instance));
        assertEq(
            registry.ownerOf(nftId),
            instanceOwner,
            "unexpected instance owner"
        );
    }

    function test_deployAllInstanceLifecycles() public {
        assertTrue(instance.getInstanceStore().hasLifecycle(BUNDLE()), "instance misses bundle lifecycle");
        assertTrue(instance.getInstanceStore().hasLifecycle(COMPONENT()), "instance misses component lifecycle");
        assertTrue(instance.getInstanceStore().hasLifecycle(POLICY()), "instance misses policy lifecycle");
        assertTrue(instance.getInstanceStore().hasLifecycle(RISK()), "instance misses risk lifecycle");
    }


    // function testDeployAllInstanceNftId() public {
    //     NftId nftId = registry.getNftId(address(instance));
    //     assertNftId(
    //         nftId,
    //         instance.getNftId(),
    //         "registry and instance nft id differ"
    //     );
    //     assertNftId(nftId, NftIdLib.toNftId(93133705), "instance getNftId not 93133705");
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
    //     assertNftId(nftId, NftIdLib.toNftId(113133705), "distribution getNftId not 113133705");
    // }

    // function testDeployAllProductNftId() public {
    //     NftId nftId = registry.getNftId(address(product));
    //     assertNftId(
    //         nftId,
    //         product.getNftId(),
    //         "registry and product nft id differ"
    //     );
    //     assertNftId(nftId, NftIdLib.toNftId(123133705), "product getNftId not 123133705");
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
    //     assertNftId(nftId, NftIdLib.toNftId(103133705), "pool getNftId not 103133705");
    // }
}