// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {BasicPoolAuthorization} from "../../../contracts/pool/BasicPoolAuthorization.sol";
import {GifTest} from "../../base/GifTest.sol";
import {NftId, NftIdLib} from "../../../contracts/type/NftId.sol";
import {FeeLib} from "../../../contracts/type/Fee.sol";
import {UFixedLib} from "../../../contracts/type/UFixed.sol";
import {ComponentService} from "../../../contracts/shared/ComponentService.sol";
import {SimplePool} from "../../../contracts/examples/unpermissioned/SimplePool.sol";
import {SimpleProduct} from "../../../contracts/examples/unpermissioned/SimpleProduct.sol";

contract TestPoolService is GifTest {

    SimplePool public testPool;
    SimpleProduct public testProd;
    NftId public testProdNftId;

    function setUp() public override {
        super.setUp();

        (testProd, testProdNftId) = _deployAndRegisterNewSimpleProduct("NewSimpleProduct");
    }


    function test_poolServiceRegisterHappyCase() public {
        vm.startPrank(outsider);
        testPool = new SimplePool(
            address(registry),
            testProdNftId,
            address(token),
            new BasicPoolAuthorization("SimplePool"),
            outsider
        );
        vm.stopPrank();

        NftId nftId = _registerComponent(testProd, address(testPool), "pool");
        assertTrue(nftId.gtz(), "nftId is zero");
    }
}
