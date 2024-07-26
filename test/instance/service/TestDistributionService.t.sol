// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {BasicDistributionAuthorization} from "../../../contracts/distribution/BasicDistributionAuthorization.sol";
import {GifTest} from "../../base/GifTest.sol";
import {NftId, NftIdLib} from "../../../contracts/type/NftId.sol";
import {ComponentService} from "../../../contracts/shared/ComponentService.sol";
import {SimpleDistribution} from "../../../contracts/examples/unpermissioned/SimpleDistribution.sol";

contract TestDistributionService is GifTest {
    using NftIdLib for NftId;

    function test_distributionServiceRegisterHappyCase() public {
        vm.startPrank(distributionOwner);
        distribution = new SimpleDistribution(
            address(registry),
            instanceNftId,
            new BasicDistributionAuthorization("SimpleDistribution"),
            distributionOwner,
            address(token)
        );
        vm.stopPrank();

        NftId nftId = _registerComponent(product, address(distribution), "distribution");
        assertTrue(nftId.gtz(), "nftId is zero");
    }

}
