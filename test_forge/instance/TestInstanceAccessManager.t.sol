// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {TestGifBase} from "../base/TestGifBase.sol";
import {IBaseComponent} from "../../contracts/components/IBaseComponent.sol";
import {PRODUCT_OWNER_ROLE, RoleIdLib} from "../../contracts/types/RoleId.sol";
import {SimpleProduct, SPECIAL_ROLE_INT} from "../mock/SimpleProduct.sol";
import {FeeLib} from "../../contracts/types/Fee.sol";

contract TestInstanceAccessManager is TestGifBase {

    uint256 public constant INITIAL_BALANCE = 100000;

    function test_InstanceAccessManager_hasRole_unauthorized() public {
        // GIVEN
        vm.startPrank(instanceOwner);
        instanceAccessManager.grantRole(PRODUCT_OWNER_ROLE(), productOwner);
        vm.stopPrank();

        _prepareDistributionAndPool();

        vm.startPrank(productOwner);
        product = new SimpleProduct(
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
        vm.stopPrank();

        vm.startPrank(outsider);

        // THEN - missing role
        vm.expectRevert(abi.encodeWithSelector(IBaseComponent.ErrorBaseComponentUnauthorized.selector, outsider, 11111));

        // WHEN
        SimpleProduct dproduct = SimpleProduct(address(product));
        dproduct.doSomethingSpecial();

    }

    function test_InstanceAccessManager_hasRole_customRole() public {
        // GIVEN
        vm.startPrank(instanceOwner);
        instanceAccessManager.grantRole(PRODUCT_OWNER_ROLE(), productOwner);
        instanceAccessManager.createRole(RoleIdLib.toRoleId(SPECIAL_ROLE_INT), "SpecialRole");
        instanceAccessManager.grantRole(RoleIdLib.toRoleId(SPECIAL_ROLE_INT), outsider);
        vm.stopPrank();

        _prepareDistributionAndPool();

        vm.startPrank(productOwner);
        product = new SimpleProduct(
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
        vm.stopPrank();

        vm.startPrank(outsider);

        // WHEN
        SimpleProduct dproduct = SimpleProduct(address(product));
        dproduct.doSomethingSpecial();

        // THEN above call was authorized
    }
}
