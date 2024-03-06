// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";


import {TestGifBase} from "../base/TestGifBase.sol";
import {IAccess} from "../../contracts/instance/module/IAccess.sol";
import {IComponent} from "../../contracts/components/IComponent.sol";
import {PRODUCT_OWNER_ROLE, INSTANCE_OWNER_ROLE, RoleId, RoleIdLib} from "../../contracts/types/RoleId.sol";
import {SimpleProduct, SPECIAL_ROLE_INT} from "../mock/SimpleProduct.sol";
import {FeeLib} from "../../contracts/types/Fee.sol";

contract TestInstanceAccessManager is TestGifBase {

    uint256 public constant INITIAL_BALANCE = 100000;

    // FIXME: fix test
    function skip_test_InstanceAccessManager_hasRole_unauthorized() public {
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
        vm.expectRevert(abi.encodeWithSelector(IComponent.ErrorComponentUnauthorized.selector, outsider, 11111));

        // WHEN
        SimpleProduct dproduct = SimpleProduct(address(product));
        dproduct.doSomethingSpecial();
    }

    // FIXME: fix test
    function skip_test_InstanceAccessManager_hasRole_customRole() public {
        // GIVEN
        vm.startPrank(instanceOwner);
        instanceAccessManager.grantRole(PRODUCT_OWNER_ROLE(), productOwner);
        RoleId customRoleId = instanceAccessManager.createCustomRole("SpecialRole", INSTANCE_OWNER_ROLE());
        instanceAccessManager.grantRole(customRoleId, outsider);
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

    function test_InstanceAccessManager_isTargetClosed() public {
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
        productService.register(address(product));
        vm.stopPrank();

        vm.startPrank(instanceOwner);
        bytes4[] memory fctSelectors = new bytes4[](1);
        fctSelectors[0] = SimpleProduct.doWhenNotLocked.selector;
        instanceAccessManager.setTargetFunctionCustomRole(product.getName(), fctSelectors, PRODUCT_OWNER_ROLE());
        vm.stopPrank();

        vm.startPrank(productOwner);
        product.lock();

        // THEN - expect locked
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(productOwner)));

        // WHEN
        SimpleProduct dproduct = SimpleProduct(address(product));
        dproduct.doWhenNotLocked();

        // WHEN - unlock
        product.unlock();

        // THEN - expect function to be called
        dproduct.doWhenNotLocked();
    }
}
