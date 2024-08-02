// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../lib/forge-std/src/Test.sol";

import {BasicDistributionAuthorization} from "../contracts/distribution/BasicDistributionAuthorization.sol";
import {Fee, FeeLib} from "../contracts/type/Fee.sol";
import {GifTest} from "./base/GifTest.sol";
import {IAccess} from "../contracts/instance/module/IAccess.sol";
import {IComponent} from "../contracts/shared/IComponent.sol";
import {IComponents} from "../contracts/instance/module/IComponents.sol";
import {IComponentService} from "../contracts/shared/IComponentService.sol";
import {NftId, NftIdLib} from "../contracts/type/NftId.sol";
import {SimpleDistribution} from "../contracts/examples/unpermissioned/SimpleDistribution.sol";
import {TokenHandler} from "../contracts/shared/TokenHandler.sol";
import {UFixedLib} from "../contracts/type/UFixed.sol";


contract TestDistribution is GifTest {

    uint256 public constant INITIAL_BALANCE = 100000;

    function setUp() public override {
        super.setUp();
        _prepareProduct(); // also deploys and registers distribution
    }


    function test_distributionSetFees() public {
        // GIVEN - just setUp

        IComponents.ProductInfo memory productInfo = instanceReader.getProductInfo(productNftId);

        Fee memory distributionFee = productInfo.distributionFee;
        assertEq(distributionFee.fractionalFee.toInt(), 0, "distribution fee not 0 (fractional)");
        assertEq(distributionFee.fixedFee, 0, "distribution fee not 0 (fixed)");

        Fee memory minDistributionOwnerFee = productInfo.minDistributionOwnerFee;
        assertEq(minDistributionOwnerFee.fractionalFee.toInt(), 0, "min distribution owner fee not 0 (fractional)");
        assertEq(minDistributionOwnerFee.fixedFee, 0, "min distribution owner fee fee not 0 (fixed)");
        
        Fee memory newMinDistributionOwnerFee = FeeLib.toFee(UFixedLib.toUFixed(12,0), 34);
        Fee memory newDistributionFee = FeeLib.toFee(UFixedLib.toUFixed(123,0), 456);

        // WHEN
        vm.startPrank(distributionOwner);
        distribution.setFees(newDistributionFee, newMinDistributionOwnerFee);
        vm.stopPrank();

        // THEN
        productInfo = instanceReader.getProductInfo(productNftId);
        distributionFee = productInfo.distributionFee;
        assertEq(distributionFee.fractionalFee.toInt(), 123, "unexpected distribution fee (fractional))");
        assertEq(distributionFee.fixedFee, 456, "unexpected distribution fee not (fixed)");

        minDistributionOwnerFee = productInfo.minDistributionOwnerFee;
        assertEq(minDistributionOwnerFee.fractionalFee.toInt(), 12, "unexpected min distribution owner fee (fractional)");
        assertEq(minDistributionOwnerFee.fixedFee, 34, "unexpected min distribution owner fee not 0 (fixed)");
    }
}
