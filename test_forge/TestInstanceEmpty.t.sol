// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import "../lib/forge-std/src/Test.sol";
import {console} from "../lib/forge-std/src/Script.sol";

import {DeployInstance} from "../scripts/DeployInstance.s.sol";

import {IRegistry} from "../contracts/registry/IRegistry.sol";
import {Registry} from "../contracts/registry/Registry.sol";
import {Instance} from "../contracts/instance/Instance.sol";

import {NftId, toNftId, NftIdLib} from "../contracts/types/NftId.sol";

contract TestInstanceEmpty is Test {
    using NftIdLib for NftId;

    IRegistry public registry;
    Instance public instance;
    address public registryOwner = makeAddr("registryOwner");
    address public instanceOwner = makeAddr("instanceOwner");

    function setUp() external {
        DeployInstance di = new DeployInstance();
        instance = di.run(registryOwner, instanceOwner);
        registry = instance.getRegistry();
    }

    function testRegistryCount() public {
        // 1. protocol
        // 2. global registry
        // 3. 23133705 anvil registry
        // 4. 33133705 component owner service
        // 5. 43133705 product service
        // 6. 53133705 pool service
        // 7. 63133705 instance
        assertEq(registry.getObjectCount(), 7, "getObjectCount not 1");
    }

    function testRegistryNftId() public {
        NftId nftId = registry.getNftId(address(instance));
        assertNftId(nftId, toNftId(63133705), "instance getNftId not 63133705");
        assertNftId(
            nftId,
            instance.getNftId(),
            "registry and instance nft id differ"
        );
    }

    function testInstanceOwner() public {
        NftId instanceId = registry.getNftId(address(instance));
        assertEq(
            registry.getOwner(instanceId),
            instanceOwner,
            "unexpected instance owner"
        );
    }

    function assertNftId(
        NftId actualNftId,
        NftId expectedNftId,
        string memory message
    ) public {
        if (block.chainid == 31337) {
            assertEq(actualNftId.toInt(), expectedNftId.toInt(), message);
        } else {
            // solhint-disable-next-line
            console.log("chain not anvil, skipping assertNftId");
        }
    }
}
