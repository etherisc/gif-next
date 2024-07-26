// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {BasicPoolAuthorization} from "../../../contracts/pool/BasicPoolAuthorization.sol";
import {GifTest} from "../../base/GifTest.sol";
import {NftId, NftIdLib} from "../../../contracts/type/NftId.sol";
import {FeeLib} from "../../../contracts/type/Fee.sol";
import {UFixedLib} from "../../../contracts/type/UFixed.sol";
import {ComponentService} from "../../../contracts/shared/ComponentService.sol";
import {SimplePool} from "../../../contracts/examples/unpermissioned/SimplePool.sol";

contract TestPoolService is GifTest {

    function test_PoolServiceRegisterHappyCase() public {
        vm.startPrank(outsider);
        pool = new SimplePool(
            address(registry),
            instanceNftId,
            address(token),
            new BasicPoolAuthorization("SimplePool"),
            outsider
        );
        vm.stopPrank();

        NftId nftId = _registerComponent(product, address(pool), "pool");
        assertTrue(nftId.gtz(), "nftId is zero");
    }
}
