// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {console} from "../lib/forge-std/src/Script.sol";
import {TestGifBase} from "./base/TestGifBase.sol";
import {NftId, toNftId} from "../contracts/types/NftId.sol";

contract TestInstanceInitialSetup is TestGifBase {

    function testRegistryCount() public {
        // 1. 1101 protocol
        // 2. 1201 global registry
        // 3. 23133705 anvil registry
        // 4. 33133705 component owner service
        // 5. 43133705 distribution service
        // 6. 53133705 product service
        // 7. 63133705 pool service
        // 8. 73133705 instance
        // 9. 83133705 pool
        // 10. 93133705 distribution
        // 11. 103133705 product
        // 12. 113133705 bundle
        assertEq(registry.getObjectCount(), 12, "getObjectCount not 12");
    }

    function testRegistryNftId() public {
        NftId nftId = registry.getNftId(address(instance));
        assertNftId(nftId, toNftId(73133705), "instance getNftId not 73133705");
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
}
