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

    address gifRoleMember;

    RoleId customRoleId;
    RoleId customRoleAdmin;
    address customRoleMember;
    address customRoleAdminMember;

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
        (customRoleId, customRoleAdmin) = instanceAccessManager.createRole("SpecialRole", "SpecialRoleAdmin");
        // set special role for product custom product function 
        bytes4[] memory fcts = new bytes4[](1);
        fcts[0] = SimpleProduct.doSomethingSpecial.selector;
        instanceAccessManager.setTargetFunctionRole(product.getName(), fcts, customRoleId);
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
        instanceAccessManager.setTargetFunctionRole(product.getName(), fctSelectors, PRODUCT_OWNER_ROLE());
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

    function test_InstanceAccessMamanger_grantRole_gifRole_HappyCase() public {
        gifRoleMember = productOwner;

        vm.startPrank(instanceOwner);

        assertTrue(instanceAccessManager.grantRole(PRODUCT_OWNER_ROLE(), gifRoleMember), "grantRole(PRODUCT_OWNER_ROLE, productOwner) returned false");

        vm.stopPrank();
    }

    function test_InstanceAccessMamanger_revokeRole_gifRole_HappyCase() public {
        test_InstanceAccessMamanger_grantRole_gifRole_HappyCase();

        vm.startPrank(instanceOwner);

        assertTrue(instanceAccessManager.revokeRole(PRODUCT_OWNER_ROLE(), gifRoleMember), "grantRole(PRODUCT_OWNER_ROLE, productOwner) returned false");

        vm.stopPrank();        
    }

    // TODO renounce of gif role must be prohibited???
    function test_InstanceAccessMamanger_renounceRole_gifRole_HappyCase() public {
        test_InstanceAccessMamanger_grantRole_gifRole_HappyCase();

        vm.startPrank(gifRoleMember);

        assertTrue(instanceAccessManager.renounceRole(PRODUCT_OWNER_ROLE()), "grantRole(PRODUCT_OWNER_ROLE) returned false");

        vm.stopPrank();        
    }

    function test_InstanceAccessMamanger_grantRole_customRole_HappyCase() public 
    {
        vm.startPrank(instanceOwner);

        // create custom role
        (customRoleId, customRoleAdmin) = instanceAccessManager.createRole("SpecialRole", "SpecialRoleAdmin");
        customRoleMember = productOwner;
        customRoleAdminMember = outsider;

        //checkpoint
        assertEq(instanceAccessManager.getRoleAdmin(customRoleId).toInt(), customRoleAdmin.toInt(), "getRoleAdmin(customRoleId) returned !customRoleAdmin #1");
        assertEq(instanceAccessManager.getRoleAdmin(customRoleAdmin).toInt(), INSTANCE_OWNER_ROLE().toInt(), "getRoleAdmin(customRoleAdmin) returned !INSTANCE_OWNER_ROLE #1");
        
        assertFalse(instanceAccessManager.hasRole(customRoleId, instanceOwner));
        assertFalse(instanceAccessManager.hasRole(customRoleId, customRoleMember));
        assertFalse(instanceAccessManager.hasRole(customRoleId, customRoleAdminMember));

        assertFalse(instanceAccessManager.hasRole(customRoleAdmin, instanceOwner));
        assertFalse(instanceAccessManager.hasRole(customRoleAdmin, customRoleMember));
        assertFalse(instanceAccessManager.hasRole(customRoleAdmin, customRoleAdminMember));

        assertEq(instanceAccessManager.roleMembers(customRoleId), 0, "roleMembers(customRoleId) != 0 #1");
        assertEq(instanceAccessManager.roleMembers(customRoleAdmin), 0, "roleMembers(customRoleAdmin) != 0 #1");

        // grant custom role admin
        assertTrue(instanceAccessManager.grantRole(customRoleAdmin, customRoleAdminMember), "grantRole(customRoleAdmin, outsider) returned false");
        assertTrue(instanceAccessManager.hasRole(customRoleAdmin, customRoleAdminMember));

        // grant custom role admin to itself
        assertTrue(instanceAccessManager.grantRole(customRoleAdmin, instanceOwner), "grantRole(customRoleAdmin, instanceOwner) returned false");
        assertTrue(instanceAccessManager.hasRole(customRoleAdmin, instanceOwner));

        vm.stopPrank();
        vm.startPrank(customRoleAdminMember);

        // grant custom role
        assertTrue(instanceAccessManager.grantRole(customRoleId, customRoleMember), "grantRole(customRoleId, productOwner) returned false");
        assertTrue(instanceAccessManager.hasRole(customRoleId, customRoleMember));

        // grant custom role to itself
        assertTrue(instanceAccessManager.grantRole(customRoleId, customRoleAdminMember), "grantRole(customRoleId, outsider) returned false");
        assertTrue(instanceAccessManager.hasRole(customRoleId, customRoleAdminMember));

        vm.stopPrank();

        // checkpoint
        assertEq(instanceAccessManager.getRoleAdmin(customRoleId).toInt(), customRoleAdmin.toInt(), "getRoleAdmin(customRoleId) returned !customRoleAdmin #2");
        assertEq(instanceAccessManager.getRoleAdmin(customRoleAdmin).toInt(), INSTANCE_OWNER_ROLE().toInt(), "getRoleAdmin(customRoleAdmin) returned !INSTANCE_OWNER_ROLE #2");

        assertFalse(instanceAccessManager.hasRole(customRoleId, instanceOwner));
        assertTrue(instanceAccessManager.hasRole(customRoleId, customRoleMember));
        assertTrue(instanceAccessManager.hasRole(customRoleId, customRoleAdminMember));

        assertTrue(instanceAccessManager.hasRole(customRoleAdmin, instanceOwner));
        assertFalse(instanceAccessManager.hasRole(customRoleAdmin, customRoleMember));
        assertTrue(instanceAccessManager.hasRole(customRoleAdmin, customRoleAdminMember));

        assertEq(instanceAccessManager.roleMembers(customRoleId), 2, "roleMembers(customRoleId) != 2 #2");
        assertEq(instanceAccessManager.roleMembers(customRoleAdmin), 2, "roleMembers(customRoleAdmin) != 2 #4");
    }

    function test_InstanceAccessMamanger_revokeRole_customRole_HappyCase() public {
        test_InstanceAccessMamanger_grantRole_customRole_HappyCase();

        vm.startPrank(customRoleAdminMember);

        // revoke custom role
        assertTrue(instanceAccessManager.revokeRole(customRoleId, customRoleMember), "revokeRole(customRoleId, customRoleMember) returned false");
        assertFalse(instanceAccessManager.hasRole(customRoleId, customRoleMember));

        // revoke custom role from itself
        assertTrue(instanceAccessManager.revokeRole(customRoleId, customRoleAdminMember), "revokeRole(customRoleId, customRoleAdminMember) returned false");
        assertFalse(instanceAccessManager.hasRole(customRoleId, customRoleAdminMember));

        vm.stopPrank();
        vm.startPrank(instanceOwner);

        // revoke custom role admin
        assertTrue(instanceAccessManager.revokeRole(customRoleAdmin, customRoleAdminMember), "revokeRole(customRoleAdmin, customRoleAdminMember) returned false");
        assertFalse(instanceAccessManager.hasRole(customRoleAdmin, customRoleAdminMember));

        // revoke custom role admin from itself
        assertTrue(instanceAccessManager.revokeRole(customRoleAdmin, instanceOwner), "revokeRole(customRoleAdmin, instanceOwner) returned false");

        vm.stopPrank();

        //checkpoint
        assertEq(instanceAccessManager.getRoleAdmin(customRoleId).toInt(), customRoleAdmin.toInt(), "getRoleAdmin(customRoleId) returned !customRoleAdmin #3");
        assertEq(instanceAccessManager.getRoleAdmin(customRoleAdmin).toInt(), INSTANCE_OWNER_ROLE().toInt(), "getRoleAdmin(customRoleAdmin) returned !INSTANCE_OWNER_ROLE #3");

        assertFalse(instanceAccessManager.hasRole(customRoleId, instanceOwner));
        assertFalse(instanceAccessManager.hasRole(customRoleId, customRoleMember));
        assertFalse(instanceAccessManager.hasRole(customRoleId, customRoleAdminMember));

        assertFalse(instanceAccessManager.hasRole(customRoleAdmin, instanceOwner));
        assertFalse(instanceAccessManager.hasRole(customRoleAdmin, customRoleMember));
        assertFalse(instanceAccessManager.hasRole(customRoleAdmin, customRoleAdminMember));

        assertEq(instanceAccessManager.roleMembers(customRoleId), 0, "roleMembers(customRoleId) != 2 #3");
        assertEq(instanceAccessManager.roleMembers(customRoleAdmin), 0, "roleMembers(customRoleAdmin) != 2 #5");
    }

    function test_InstanceAccessMamanger_renounceRole_customRole_HappyCase() public {
        test_InstanceAccessMamanger_grantRole_customRole_HappyCase();

        // renounce custom role
        vm.startPrank(customRoleMember);

        assertTrue(instanceAccessManager.renounceRole(customRoleId), "revokeRole(customRoleId) returned false");
        assertFalse(instanceAccessManager.hasRole(customRoleId, customRoleMember));

        vm.stopPrank();
        vm.startPrank(customRoleAdminMember);

        // renounce custom role by custom role admin
        assertTrue(instanceAccessManager.renounceRole(customRoleId), "revokeRole(customRoleId) returned false");
        assertFalse(instanceAccessManager.hasRole(customRoleId, customRoleAdminMember));

        // renounce custom admin role by custom role admin
        assertTrue(instanceAccessManager.renounceRole(customRoleAdmin), "revokeRole(customRoleAdmin) returned false");
        assertFalse(instanceAccessManager.hasRole(customRoleAdmin, customRoleAdminMember));

        vm.stopPrank();
        vm.startPrank(instanceOwner);

        // renounce custom role admin by instance owner
        assertTrue(instanceAccessManager.renounceRole(customRoleAdmin), "revokeRole(customRoleAdmin) returned false");

        vm.stopPrank(); 

        //checkpoint
        assertEq(instanceAccessManager.getRoleAdmin(customRoleId).toInt(), customRoleAdmin.toInt(), "getRoleAdmin(customRoleId) returned !customRoleAdmin #3");
        assertEq(instanceAccessManager.getRoleAdmin(customRoleAdmin).toInt(), INSTANCE_OWNER_ROLE().toInt(), "getRoleAdmin(customRoleAdmin) returned !INSTANCE_OWNER_ROLE #3");

        assertFalse(instanceAccessManager.hasRole(customRoleId, instanceOwner));
        assertFalse(instanceAccessManager.hasRole(customRoleId, customRoleMember));
        assertFalse(instanceAccessManager.hasRole(customRoleId, customRoleAdminMember));

        assertFalse(instanceAccessManager.hasRole(customRoleAdmin, instanceOwner));
        assertFalse(instanceAccessManager.hasRole(customRoleAdmin, customRoleMember));
        assertFalse(instanceAccessManager.hasRole(customRoleAdmin, customRoleAdminMember));

        assertEq(instanceAccessManager.roleMembers(customRoleId), 0, "roleMembers(customRoleId) != 0 #2");
        assertEq(instanceAccessManager.roleMembers(customRoleAdmin), 0, "roleMembers(customRoleAdmin) != 0 #2");
    }

    function test_InstanceAccessManager_transferOwnerRole_HappyCase() public {

        assertTrue(instanceAccessManager.hasRole(INSTANCE_OWNER_ROLE(), instanceOwner));        
        assertEq(instanceAccessManager.roleMembers(INSTANCE_OWNER_ROLE()), 1, "roleMembers(INSTANCE_OWNER_ROLE) != 1 #1");

        vm.startPrank(address(instance));

        instanceAccessManager.transferOwnerRole(instanceOwner, outsider);

        vm.stopPrank();

        assertFalse(instanceAccessManager.hasRole(INSTANCE_OWNER_ROLE(), instanceOwner));
        assertTrue(instanceAccessManager.hasRole(INSTANCE_OWNER_ROLE(), outsider));
        assertEq(instanceAccessManager.roleMembers(INSTANCE_OWNER_ROLE()), 1, "roleMembers(INSTANCE_OWNER_ROLE) != 1 #2");
    }
}