// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../../../lib/forge-std/src/Test.sol";

import {IAccess} from "../../../contracts/authorization/IAccess.sol";
import {IAccessAdmin} from "../../../contracts/authorization/IAccessAdmin.sol";

import {ComponentService} from "../../../contracts/shared/ComponentService.sol";
import {GifTest} from "../../base/GifTest.sol";
import {FeeLib} from "../../../contracts/type/Fee.sol";
import {NftId, NftIdLib} from "../../../contracts/type/NftId.sol";
import {RoleId,RoleIdLib, ADMIN_ROLE, INSTANCE_OWNER_ROLE} from "../../../contracts/type/RoleId.sol";
import {SimplePool} from "../../../contracts/examples/unpermissioned/SimplePool.sol";
import {SimpleProduct} from "../../../contracts/examples/unpermissioned/SimpleProduct.sol";
import {TimestampLib} from "../../../contracts/type/Timestamp.sol";
import {UFixedLib} from "../../../contracts/type/UFixed.sol";

contract InstanceAuthorizationTest is GifTest {

    function test_instanceAuthorizationSetup() public {
        _printRoles();

        // check initial roles
        assertEq(instanceAdmin.roles(), 15, "unexpected initial instance roles count (admin)");
        assertEq(instanceReader.roles(), 15, "unexpected initial instance roles count (reader)");
    }

    function test_instanceAuthorizationCreateRoleHappyCase() public {
        // GIVEN setup
        uint256 rolesBefore = instanceReader.roles();
        string memory roleName = "MyCustomRole";
        RoleId adminRole = instanceReader.getInstanceOwnerRole();
        uint32 maxMemberCount = 42;

        // WHEN 
        vm.prank(instanceOwner);
        RoleId myCustomRoleId = instance.createRole(
            roleName, 
            adminRole, 
            maxMemberCount);

        // THEN
        assertTrue(myCustomRoleId.gtz(), "role id zero");
        assertEq(instanceReader.roles(), rolesBefore + 1, "unexpected roles count after createRole");

        IAccess.RoleInfo memory roleInfo = instanceReader.getRoleInfo(myCustomRoleId);
        assertEq(roleInfo.adminRoleId.toInt(), INSTANCE_OWNER_ROLE().toInt(), "instance owner role not role admin");
        assertTrue(roleInfo.roleType == IAccess.RoleType.Custom, "not custom role type");
        assertEq(roleInfo.maxMemberCount, maxMemberCount, "unexpected max member count");
        assertEq(roleInfo.name.toString(), "MyCustomRole", "unexpected role name");
        assertEq(roleInfo.createdAt.toInt(), TimestampLib.blockTimestamp().toInt(), "unexpected created at timestamp");
        assertEq(roleInfo.pausedAt.toInt(), TimestampLib.max().toInt(), "unexpected paused at timestamp");
    }


    function test_instanceAuthorizationCreateRoleRoleNameEmpty() public {
        // GIVEN setup
        string memory roleName = "";
        RoleId adminRole = instanceReader.getInstanceOwnerRole();
        uint32 maxMemberCount = 42;

        // WHEN + THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorAccessAdminRoleNameEmpty.selector, 
                1000000));

        vm.prank(instanceOwner);
        RoleId myCustomRoleId = instance.createRole(
            roleName, 
            adminRole, 
            maxMemberCount);

        assertTrue(myCustomRoleId.eqz(), "role id not zero");
    }


    function test_instanceAuthorizationCreateRoleAdminRoleNonexistent() public {
        // GIVEN setup
        string memory roleName = "myCustomRole";
        RoleId adminRole = RoleIdLib.toRoleId(12345);
        uint32 maxMemberCount = 42;

        // WHEN + THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorAccessAdminRoleAdminNotExisting.selector, 
                adminRole));

        vm.prank(instanceOwner);
        RoleId myCustomRoleId = instance.createRole(
            roleName, 
            adminRole, 
            maxMemberCount);

        assertTrue(myCustomRoleId.eqz(), "role id not zero");
    }


    function _printRoles() internal {
        // print roles
        for(uint256 i = 0; i < instanceReader.roles(); i++) {
            RoleId roleId = instanceReader.getRoleId(i);
            IAccess.RoleInfo memory roleInfo = instanceReader.getRoleInfo(roleId);
            console.log("role", i, roleId.toInt(), roleInfo.name.toString());
        }
    }
}