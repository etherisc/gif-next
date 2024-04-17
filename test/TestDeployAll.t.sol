// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {console} from "../lib/forge-std/src/Script.sol";
import {GifTest} from "./base/GifTest.sol";
import {IRegistry} from "../contracts/registry/IRegistry.sol";
import {IStaking} from "../contracts/staking/IStaking.sol";
import {IStakingService} from "../contracts/staking/IStakingService.sol";
import {NftId, toNftId, NftIdLib} from "../contracts/type/NftId.sol";
import {BUNDLE, COMPONENT, POLICY, RISK, SERVICE, STAKING} from "../contracts/type/ObjectType.sol";
import {PRODUCT_OWNER_ROLE, POOL_OWNER_ROLE} from "../contracts/type/RoleId.sol";

contract TestDeployAll is GifTest {
    using NftIdLib for NftId;

    // FIXME: add missing services
    function test_deployAllOverview() public {
        assertEq(registry.getObjectCount(), 17, "invalid object count for base setup");

        // validate instance service
        assertTrue(registry.getNftId(address(stakingService)).eq(stakingServiceNftId), "staking service nft does not match");
        assertTrue(address(stakingServiceManager) != address(0), "staking service manager is zero address");

        // validate instance service
        assertTrue(registry.getNftId(address(instanceService)).eq(instanceServiceNftId), "instance service nft does not match");
        assertTrue(address(instanceServiceManager) != address(0), "instance service manager is zero address");

        // validate distribution service
        assertTrue(registry.getNftId(address(distributionService)).eq(distributionServiceNftId), "distribution service nft does not match");
        assertTrue(address(distributionServiceManager) != address(0), "distribution service manager is zero address");

        // validate pool service
        assertTrue(registry.getNftId(address(poolService)).eq(poolServiceNftId), "pool service nft does not match");
        assertTrue(address(poolServiceManager) != address(0), "pool service manager is zero address");

        // validate policy service
        assertTrue(registry.getNftId(address(policyService)).eq(policyServiceNftId), "pool service nft does not match");
        assertTrue(address(policyServiceManager) != address(0), "pool service manager is zero address");

        // validate master instance
        assertTrue(registry.getNftId(address(masterInstance)).eq(masterInstanceNftId), "master instance nft does not match");
        assertTrue(address(masterInstanceAccessManager) != address(0), "master instance access manager is zero address");
        assertTrue(address(masterInstanceReader) != address(0), "master instance reader is zero address");

        // validate created (cloned) instance
        assertTrue(registry.getNftId(address(instance)).eq(instanceNftId), "instance nft does not match");
        assertTrue(address(instanceAccessManager) != address(0), "instance access manager is zero address");
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

    function test_deployAllStakingSetup() public {
        // staking manager
        assertEq(stakingManager.getOwner(), staking.getOwner(), "unexpected staking manager owner");
        assertEq(address(stakingManager.getStaking()), address(staking), "unexpected staking address");

        // staking
        assertTrue(staking.supportsInterface(type(IStaking).interfaceId), "not supportint expected interface");
        assertTrue(registry.getNftId(address(staking)).gtz(), "staking nft id zero");
        assertEq(staking.getNftId().toInt(), stakingNftId.toInt(), "unexpected staking nft id (1)");
        assertEq(staking.getNftId().toInt(), registry.getNftId(address(staking)).toInt(), "unexpected staking nft id (2)");

        IRegistry.ObjectInfo memory stakingInfo = registry.getObjectInfo(staking.getNftId());
        assertEq(stakingInfo.nftId.toInt(), stakingNftId.toInt(), "unexpected staking nft id (3)");
        assertEq(stakingInfo.parentNftId.toInt(), registryNftId.toInt(), "unexpected parent nft id");
        assertEq(stakingInfo.objectType.toInt(), STAKING().toInt(), "unexpected object type");
        assertFalse(stakingInfo.isInterceptor, "staking should not be interceptor");
        assertEq(stakingInfo.objectAddress, address(staking), "unexpected contract address");
        assertEq(stakingInfo.initialOwner, registryOwner, "unexpected initial owner");

        // staking service manager
        assertEq(stakingServiceManager.getOwner(), stakingService.getOwner(), "unexpected staking service manager owner");
        assertEq(address(stakingServiceManager.getStakingService()), address(stakingService), "unexpected staking service address");

        // staking service
        assertTrue(stakingService.supportsInterface(type(IStakingService).interfaceId), "not supportint expected interface");
        assertTrue(registry.getNftId(address(stakingService)).gtz(), "staking service nft id zero");
        assertEq(stakingService.getNftId().toInt(), stakingServiceNftId.toInt(), "unexpected staking service nft id (1)");
        assertEq(stakingService.getNftId().toInt(), registry.getNftId(address(stakingService)).toInt(), "unexpected staking service nft id (2)");

        IRegistry.ObjectInfo memory serviceInfo = registry.getObjectInfo(stakingService.getNftId());
        assertEq(serviceInfo.nftId.toInt(), stakingServiceNftId.toInt(), "unexpected staking service nft id (3)");
        assertEq(serviceInfo.parentNftId.toInt(), registryNftId.toInt(), "unexpected parent nft id");
        assertEq(serviceInfo.objectType.toInt(), SERVICE().toInt(), "unexpected object type");
        assertFalse(serviceInfo.isInterceptor, "staking service should not be interceptor");
        assertEq(serviceInfo.objectAddress, address(stakingService), "unexpected contract address");
        assertEq(serviceInfo.initialOwner, registryOwner, "unexpected initial owner");

        // roles
        // access rights
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