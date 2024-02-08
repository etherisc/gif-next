// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {console} from "../../../lib/forge-std/src/Script.sol";
import {TestGifBase} from "../../base/TestGifBase.sol";
import {NftId, toNftId, NftIdLib} from "../../../contracts/types/NftId.sol";
import {PRODUCT_OWNER_ROLE, POOL_OWNER_ROLE, DISTRIBUTION_OWNER_ROLE} from "../../../contracts/types/RoleId.sol";
import {Pool} from "../../../contracts/components/Pool.sol";
import {IRegistry} from "../../../contracts/registry/IRegistry.sol";
import {ISetup} from "../../../contracts/instance/module/ISetup.sol";
import {Fee, FeeLib} from "../../../contracts/types/Fee.sol";
import {UFixedLib} from "../../../contracts/types/UFixed.sol";
import {ComponentServiceBase} from "../../../contracts/instance/base/ComponentServiceBase.sol";
import {MockProduct} from "../../mock/MockProduct.sol";

contract TestProductService is TestGifBase {
    using NftIdLib for NftId;

    function test_ProductService_register_missingProductOwnerRole() public {
        _prepareDistributionAndPool();

        vm.startPrank(productOwner);
        product = new MockProduct(
            address(registry),
            instanceNftId,
            address(token),
            false,
            address(pool), 
            address(distribution), 
            FeeLib.zeroFee(),
            FeeLib.zeroFee(),
            productOwner
        );

        vm.expectRevert(abi.encodeWithSelector(ComponentServiceBase.ExpectedRoleMissing.selector, PRODUCT_OWNER_ROLE(), productOwner));
        productService.register(address(product));
    }

    function test_ProductService_register() public {
        vm.startPrank(instanceOwner);
        instanceAccessManager.grantRole(PRODUCT_OWNER_ROLE(), productOwner);
        vm.stopPrank();

        _prepareDistributionAndPool();

        vm.startPrank(productOwner);
        product = new MockProduct(
            address(registry),
            instanceNftId,
            address(token),
            false,
            address(pool), 
            address(distribution), 
            FeeLib.zeroFee(),
            FeeLib.zeroFee(),
            productOwner
        );

        NftId nftId = productService.register(address(product));
        assertFalse(nftId.eqz(), "nftId is zero");
    }

}
