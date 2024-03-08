// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {Test, console} from "../../lib/forge-std/src/Test.sol";


import {TestGifBase} from "../base/TestGifBase.sol";
import {IAccess} from "../../contracts/instance/module/IAccess.sol";
import {IComponent} from "../../contracts/components/IComponent.sol";
import {PRODUCT_OWNER_ROLE, INSTANCE_OWNER_ROLE, RoleId, RoleIdLib} from "../../contracts/types/RoleId.sol";
import {SimpleProduct, SPECIAL_ROLE_INT} from "../mock/SimpleProduct.sol";
import {FeeLib} from "../../contracts/types/Fee.sol";
import {RoleId} from "../../contracts/types/RoleId.sol";

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
        productService.register(address(product));
        SimpleProduct dproduct = SimpleProduct(address(product));
        vm.stopPrank();

        vm.startPrank(outsider);
        
        // THEN - call not auhorized
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(outsider)));

        // WHEN
        dproduct.doSomethingSpecial();
    }

    function test_InstanceAccessManager_hasRole_customRole() public {
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
        // create special role and special role admin
        RoleId customRoleId;
        RoleId customRoleAdmin;
        (customRoleId, customRoleAdmin) = instanceAccessManager.createCustomRole("SpecialRole", "SpecialRoleAdmin");
        // set special role for product custom product function 
        bytes4[] memory fcts = new bytes4[](1);
        fcts[0] = SimpleProduct.doSomethingSpecial.selector;
        instanceAccessManager.setTargetFunctionCustomRole(product.getName(), fcts, customRoleId);
        // assign special role to outsider
        instanceAccessManager.grantRole(customRoleAdmin, instanceOwner);
        //instanceAccessManager.grantRole("SpecialRole", outsider);
        instanceAccessManager.grantRole(customRoleId, outsider);
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

    function test_InstanceAccessManager_revokeRole_revokeCustomRoleAdmin() public {
        vm.startPrank(instanceOwner);

        RoleId customRoleId;
        RoleId customRoleAdmin;
        (customRoleId, customRoleAdmin) = instanceAccessManager.createCustomRole("SpecialRole#2", "SpecialRole#2Admin");
        
        assertEq(instanceAccessManager.roleMembers(customRoleId), 0, "custom role members count != 0 #1");
        assertEq(instanceAccessManager.roleMembers(customRoleAdmin), 0, "custom role admin members count != 0 #1");

        // grant custom role admin
        assertTrue(instanceAccessManager.grantRole(customRoleAdmin, outsider), "grantRole() returned false #1");

        vm.stopPrank();
        vm.startPrank(outsider);

         // grant custom role
        assertTrue(instanceAccessManager.grantRole(customRoleId, address(registryService)), "grantRole() returned false #2");   

        vm.stopPrank();
        vm.startPrank(instanceOwner);

        assertEq(instanceAccessManager.roleMembers(customRoleId), 1, "custom role members count != 1 #1");
        assertEq(instanceAccessManager.roleMember(customRoleId, 0), address(registryService), "custom role id member[0] != registryService");

        assertEq(instanceAccessManager.roleMembers(customRoleAdmin), 1, "custom role admin members count != 1 #1");
        assertEq(instanceAccessManager.roleMember(customRoleAdmin, 0), outsider, "custom role admin member[0] != outsider");

        // revoke
        assertTrue(instanceAccessManager.revokeRole(customRoleAdmin, outsider), "revokeRole() returned false");

        assertEq(instanceAccessManager.roleMembers(customRoleId), 0, "custom role members count != 0 #2");
        assertEq(instanceAccessManager.roleMembers(customRoleAdmin), 0, "custom role admin members count != 0 #2");
        
        vm.stopPrank();
    }

    function test_InstanceAccessManager_revokeRole_revokeCustomRole() public {
        vm.startPrank(instanceOwner);

        RoleId customRoleId;
        RoleId customRoleAdmin;
        (customRoleId, customRoleAdmin) = instanceAccessManager.createCustomRole("SpecialRole#2", "SpecialRole#2Admin");
        
        assertEq(instanceAccessManager.roleMembers(customRoleId), 0, "custom role members count != 0 #1");
        assertEq(instanceAccessManager.roleMembers(customRoleAdmin), 0, "custom role admin members count != 0 #1");

        // grant custom role admin
        assertTrue(instanceAccessManager.grantRole(customRoleAdmin, outsider), "grantRole() returned false #1");

        vm.stopPrank();
        vm.startPrank(outsider);

        // grant custom role
        assertTrue(instanceAccessManager.grantRole(customRoleId, address(registryService)), "grantRole() returned false #2");   

        assertEq(instanceAccessManager.roleMembers(customRoleId), 1, "custom role members count != 1 #1");
        assertEq(instanceAccessManager.roleMember(customRoleId, 0), address(registryService), "custom role id member[0] != registryService");

        assertEq(instanceAccessManager.roleMembers(customRoleAdmin), 1, "custom role admin members count != 1 #1");
        assertEq(instanceAccessManager.roleMember(customRoleAdmin, 0), outsider, "custom role admin member[0] != outsider");

        // revoke
        assertTrue(instanceAccessManager.revokeRole(customRoleId, address(registryService)), "revokeRole() returned false");

        assertEq(instanceAccessManager.roleMembers(customRoleId), 0, "custom role members count != 0 #2");
        assertEq(instanceAccessManager.roleMembers(customRoleAdmin), 1, "custom role admin members count != 0 #2");
        
        vm.stopPrank();      
    }
}