// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {console} from "../lib/forge-std/src/Script.sol";
import {TestGifBase} from "./base/TestGifBase.sol";
import {NftId, toNftId, NftIdLib} from "../contracts/types/NftId.sol";
import {PRODUCT_OWNER_ROLE, POOL_OWNER_ROLE, DISTRIBUTION_OWNER_ROLE} from "../contracts/types/RoleId.sol";
import {Product} from "../contracts/components/Product.sol";
import {Distribution} from "../contracts/components/Distribution.sol";
import {Pool} from "../contracts/components/Pool.sol";
import {IRegistry} from "../contracts/registry/IRegistry.sol";
import {ISetup} from "../contracts/instance/module/ISetup.sol";
import {Fee, FeeLib} from "../contracts/types/Fee.sol";
import {UFixedLib} from "../contracts/types/UFixed.sol";

contract TestProduct is TestGifBase {
    using NftIdLib for NftId;

    function testProductSetFees() public {
        vm.startPrank(instanceOwner);
        instanceAccessManager.grantRole(PRODUCT_OWNER_ROLE().toInt(), productOwner, 0);
        vm.stopPrank();

        _prepareDistributionAndPool();

        vm.startPrank(productOwner);
        product = new Product(
            address(registry),
            instanceNftId,
            address(token),
            false,
            address(pool), // TODO probably needs real one
            address(distribution), // TODO probably needs real one
            FeeLib.zeroFee(),
            FeeLib.zeroFee(),
            productOwner
        );

        NftId productNftId = productService.register(address(product));

        ISetup.ProductSetupInfo memory productSetupInfo = instanceReader.getProductSetupInfo(productNftId);
        Fee memory productFee = productSetupInfo.productFee;
        assertEq(productFee.fractionalFee.toInt(), 0, "product fee not 0");
        assertEq(productFee.fixedFee, 0, "product fee not 0");
        Fee memory processingFee = productSetupInfo.processingFee;
        assertEq(processingFee.fractionalFee.toInt(), 0, "processing fee not 0");
        assertEq(processingFee.fixedFee, 0, "processing fee not 0");
        
        Fee memory newProductFee = FeeLib.toFee(UFixedLib.toUFixed(123,0), 456);
        Fee memory newProcessingFee = FeeLib.toFee(UFixedLib.toUFixed(789,0), 101112);
        product.setFees(newProductFee, newProcessingFee);

        productSetupInfo = instanceReader.getProductSetupInfo(productNftId);
        productFee = productSetupInfo.productFee;
        assertEq(productFee.fractionalFee.toInt(), 123, "product fee not 123");
        assertEq(productFee.fixedFee, 456, "product fee not 456");
        processingFee = productSetupInfo.processingFee;
        assertEq(processingFee.fractionalFee.toInt(), 789, "processing fee not 789");
        assertEq(processingFee.fixedFee, 101112, "processing fee not 101112");

        vm.stopPrank();
    }

    function _prepareDistributionAndPool() internal {
        vm.startPrank(instanceOwner);
        instanceAccessManager.grantRole(DISTRIBUTION_OWNER_ROLE().toInt(), distributionOwner, 0);
        instanceAccessManager.grantRole(POOL_OWNER_ROLE().toInt(), poolOwner, 0);
        vm.stopPrank();

        vm.startPrank(distributionOwner);
        distribution = new Distribution(
            address(registry),
            instanceNftId,
            address(token),
            false,
            FeeLib.zeroFee(),
            distributionOwner
        );
        NftId distributionNftId = distributionService.register(address(distribution));
        vm.stopPrank();

        vm.startPrank(poolOwner);
        pool = new Pool(
            address(registry),
            instanceNftId,
            address(token),
            false,
            false,
            UFixedLib.toUFixed(1),
            FeeLib.zeroFee(),
            FeeLib.zeroFee(),
            FeeLib.zeroFee(),
            poolOwner
        );
        NftId poolNftId = poolService.register(address(pool));
        vm.stopPrank();
    }

}
