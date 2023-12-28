// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {console} from "../lib/forge-std/src/Script.sol";
import {TestGifBase} from "./base/TestGifBase.sol";
import {NftId, toNftId} from "../contracts/types/NftId.sol";

contract TestInstanceInitialSetup is TestGifBase {

    // function testRegistryCount() public {
    //     // 1. 1101 protocol
    //     // 2. 1201 global registry
    //     // 3. 23133705 anvil registry
    //     // 4. 33133705 registry service
    //     // 5. 43133705 component owner service
    //     // 6. 53133705 distribution service
    //     // 7. 63133705 product service
    //     // 8. 73133705 pool service
    //     // 9. 83133705 token
    //     // 10. 93133705 instance
    //     // 11. 103133705 pool
    //     // 12. 113133705 distribution
    //     // 13. 123133705 product
    //     // 14. 133133705 bundle
    //     assertEq(registry.getObjectCount(), 14, "getObjectCount not 14");
    // }

    // function testRegistryNftId() public {
    //     NftId nftId = registry.getNftId(address(instance));
    //     assertNftId(nftId, toNftId(93133705), "instance getNftId not 93133705");
    //     assertNftId(
    //         nftId,
    //         instance.getNftId(),
    //         "registry and instance nft id differ"
    //     );
    // }

    // function testInstanceOwner() public {
    //     NftId instanceId = registry.getNftId(address(instance));
    //     assertEq(
    //         registry.ownerOf(instanceId),
    //         instanceOwner,
    //         "unexpected instance owner"
    //     );
    // }
}
