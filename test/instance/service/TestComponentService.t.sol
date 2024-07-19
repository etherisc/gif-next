// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {BasicProductAuthorization} from "../../../contracts/product/BasicProductAuthorization.sol";
import {console} from "../../../lib/forge-std/src/Script.sol";
import {GifTest} from "../../base/GifTest.sol";
import {NftId, NftIdLib} from "../../../contracts/type/NftId.sol";
import {PRODUCT_OWNER_ROLE, POOL_OWNER_ROLE, DISTRIBUTION_OWNER_ROLE} from "../../../contracts/type/RoleId.sol";
import {ComponentService} from "../../../contracts/shared/ComponentService.sol";
import {SimpleProduct} from "../../../contracts/examples/unpermissioned/SimpleProduct.sol";

contract TestComponentService is GifTest {
    using NftIdLib for NftId;

    function test_ComponentService_register_missingProductOwnerRole() public {
        _prepareDistributionAndPool();

        vm.startPrank(productOwner);
        product = new SimpleProduct(
            address(registry),
            instanceNftId,
            new BasicProductAuthorization("SimpleProduct"),
            productOwner,
            address(token),
            false,
            address(pool), 
            address(distribution)
        );
        
        vm.expectRevert(
            abi.encodeWithSelector(
                ComponentService.ErrorComponentServiceExpectedRoleMissing.selector, 
                instanceNftId, 
                PRODUCT_OWNER_ROLE(), 
                productOwner));

        product.register();
    }

    function test_ComponentService_register() public {
        vm.startPrank(instanceOwner);
        instance.grantRole(PRODUCT_OWNER_ROLE(), productOwner);
        vm.stopPrank();

        _prepareDistributionAndPool();

        vm.startPrank(productOwner);
        product = new SimpleProduct(
            address(registry),
            instanceNftId,
            new BasicProductAuthorization("SimpleProduct"),
            productOwner,
            address(token),
            false,
            address(pool), 
            address(distribution)
        );

        product.register();
        NftId nftId = product.getNftId();
        assertTrue(nftId.gtz(), "nftId is zero");
    }
}
