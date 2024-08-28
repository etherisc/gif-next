// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {BasicDistributionAuthorization} from "../../../contracts/distribution/BasicDistributionAuthorization.sol";
import {GifTest} from "../../base/GifTest.sol";
import {NftId, NftIdLib} from "../../../contracts/type/NftId.sol";
import {ComponentService} from "../../../contracts/shared/ComponentService.sol";
import {SimpleDistribution} from "../../../contracts/examples/unpermissioned/SimpleDistribution.sol";
import {SimpleProduct} from "../../../contracts/examples/unpermissioned/SimpleProduct.sol";

contract TestDistributionService is GifTest {

    SimpleProduct public testProd;
    NftId public testProdNftId;

    function setUp() public override {
        super.setUp();

        (testProd, testProdNftId) = _deployAndRegisterNewSimpleProduct("NewSimpleProduct");
    }


    function test_distributionServiceRegisterHappyCase() public {
        vm.startPrank(distributionOwner);
        distribution = new SimpleDistribution(
            address(registry),
            testProdNftId,
            new BasicDistributionAuthorization("SimpleDistribution"),
            distributionOwner
        );
        vm.stopPrank();

        assertTrue(address(distribution) != address(0), "distribution address zero");

        NftId nftId = _registerComponent(testProd, address(distribution), "new distribution");
        assertTrue(nftId.gtz(), "nftId is zero");
    }

}
