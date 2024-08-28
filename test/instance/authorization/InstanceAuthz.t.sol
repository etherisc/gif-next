// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../../../lib/forge-std/src/Test.sol";

import {IAccess} from "../../../contracts/authorization/IAccess.sol";
import {IAccessAdmin} from "../../../contracts/authorization/IAccessAdmin.sol";
import {IInstance} from "../../../contracts/instance/IInstance.sol";
import {INftOwnable} from "../../../contracts/shared/INftOwnable.sol";

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


    function test_instanceAuthorizationRoleCreateHappyCase() public {
        // GIVEN setup
        uint256 rolesBefore = instanceReader.roles();
        string memory roleName = "MyCustomRole";
        uint32 maxMemberCount = 42;

        // WHEN 
        vm.startPrank(instanceOwner);
        RoleId myCustomRoleId = instance.createRole(
            roleName, 
            INSTANCE_OWNER_ROLE(), 
            maxMemberCount);
        vm.stopPrank();

        // THEN
        assertTrue(myCustomRoleId.gtz(), "role id zero");
        assertTrue(instanceReader.roleExists(myCustomRoleId), "role not existing");
        assertTrue(instanceReader.isRoleActive(myCustomRoleId), "role not active");
        assertTrue(instanceReader.isRoleCustom(myCustomRoleId), "role not custom");
        assertEq(instanceReader.roles(), rolesBefore + 1, "unexpected roles count after createRole");

        IAccess.RoleInfo memory roleInfo = instanceReader.getRoleInfo(myCustomRoleId);
        assertEq(roleInfo.adminRoleId.toInt(), INSTANCE_OWNER_ROLE().toInt(), "instance owner role not role admin");
        assertTrue(roleInfo.roleType == IAccess.RoleType.Custom, "not custom role type");
        assertEq(roleInfo.maxMemberCount, maxMemberCount, "unexpected max member count");
        assertEq(roleInfo.name.toString(), "MyCustomRole", "unexpected role name");
        assertEq(roleInfo.createdAt.toInt(), TimestampLib.blockTimestamp().toInt(), "unexpected created at timestamp");
        assertEq(roleInfo.pausedAt.toInt(), TimestampLib.max().toInt(), "unexpected paused at timestamp");
    }


    function test_instanceAuthorizationRoleCreateStackedHappyCase() public {
        // GIVEN setup
        uint256 rolesBefore = instanceReader.roles();

        RoleId myCustomRoleId = _createRole("MyCustomRole", INSTANCE_OWNER_ROLE(), 42);

        // WHEN create another role
        string memory roleName = "MySackedRole";
        uint32 maxMemberCount = 100;

        vm.startPrank(instanceOwner);
        RoleId myStackedRoleId = instance.createRole(
            roleName, 
            myCustomRoleId, // admin of stacked role is the custom role
            maxMemberCount);
        vm.stopPrank();

        // THEN
        assertTrue(myStackedRoleId.gtz(), "role id zero");
        assertTrue(instanceReader.roleExists(myStackedRoleId), "role not existing");
        assertTrue(instanceReader.isRoleActive(myStackedRoleId), "role not active");
        assertTrue(instanceReader.isRoleCustom(myStackedRoleId), "role not custom");
        assertEq(instanceReader.roles(), rolesBefore + 2, "unexpected roles count after createRole");

        IAccess.RoleInfo memory roleInfo = instanceReader.getRoleInfo(myStackedRoleId);
        assertEq(roleInfo.adminRoleId.toInt(), myCustomRoleId.toInt(), "custom role not role admin");
        assertTrue(roleInfo.roleType == IAccess.RoleType.Custom, "not custom role type");
        assertEq(roleInfo.maxMemberCount, maxMemberCount, "unexpected max member count");
        assertEq(roleInfo.name.toString(), "MySackedRole", "unexpected role name");
        assertEq(roleInfo.createdAt.toInt(), TimestampLib.blockTimestamp().toInt(), "unexpected created at timestamp");
        assertEq(roleInfo.pausedAt.toInt(), TimestampLib.max().toInt(), "unexpected paused at timestamp");
    }


    function test_instanceAuthorizationRoleCreateNotInstanceOwner() public {
        // GIVEN setup
        address someAccount = makeAddr("someAccount");
        string memory roleName = "";
        RoleId adminRole = instanceReader.getInstanceOwnerRole();
        uint32 maxMemberCount = 42;

        // WHEN + THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                INftOwnable.ErrorNftOwnableNotOwner.selector, 
                someAccount));

        vm.prank(someAccount);
        RoleId myCustomRoleId = instance.createRole(
            roleName, 
            adminRole, 
            maxMemberCount);

        assertTrue(myCustomRoleId.eqz(), "role id not zero");
    }


    function test_instanceAuthorizationRoleCreateRoleNameEmpty() public {
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


    function test_instanceAuthorizationRoleCreateAdminRoleNonexistent() public {
        // GIVEN setup
        string memory roleName = "myCustomRole";
        RoleId adminRole = RoleIdLib.toRoleId(12345);
        uint32 maxMemberCount = 42;

        assertFalse(instanceReader.roleExists(adminRole), "admin role unexpectedly existing");

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


    function test_instanceAuthorizationRoleSetActiveHappyCase1() public {
        // GIVEN setup
        RoleId myCustomRoleId = _createRole("MyCustomRole", INSTANCE_OWNER_ROLE(), 42);

        assertTrue(instanceReader.isRoleActive(myCustomRoleId), "role not active");

        // WHEN - dactivate
        vm.prank(instanceOwner);
        instance.setRoleActive(myCustomRoleId, false);

        // THEN
        assertFalse(instanceReader.isRoleActive(myCustomRoleId), "role not active");
        assertEq(instanceReader.getRoleInfo(myCustomRoleId).pausedAt.toInt(), TimestampLib.blockTimestamp().toInt(), "unexpected paused at timestamp");

        // WHEN - activate
        vm.prank(instanceOwner);
        instance.setRoleActive(myCustomRoleId, true);

        // THEN
        assertTrue(instanceReader.isRoleActive(myCustomRoleId), "role not active");
        assertEq(instanceReader.getRoleInfo(myCustomRoleId).pausedAt.toInt(), TimestampLib.max().toInt(), "unexpected paused at timestamp");
    }


    function test_instanceAuthorizationRoleSetActiveHappyCase2() public {
        // GIVEN setup
        RoleId myCustomRoleId = _createRole("MyCustomRole", INSTANCE_OWNER_ROLE(), 42);

        assertTrue(instanceReader.isRoleActive(myCustomRoleId), "role not active");

        // WHEN - activate active role
        vm.prank(instanceOwner);
        instance.setRoleActive(myCustomRoleId, true);

        // THEN
        assertTrue(instanceReader.isRoleActive(myCustomRoleId), "role not active");
        assertEq(instanceReader.getRoleInfo(myCustomRoleId).pausedAt.toInt(), TimestampLib.max().toInt(), "unexpected paused at timestamp");

        // WHEN - deactivate active role
        vm.prank(instanceOwner);
        instance.setRoleActive(myCustomRoleId, false);

        // THEN
        assertFalse(instanceReader.isRoleActive(myCustomRoleId), "role not active");
        assertEq(instanceReader.getRoleInfo(myCustomRoleId).pausedAt.toInt(), TimestampLib.blockTimestamp().toInt(), "unexpected paused at timestamp");

        // WHEN - deactivate pused role
        vm.prank(instanceOwner);
        instance.setRoleActive(myCustomRoleId, false);

        // THEN
        assertFalse(instanceReader.isRoleActive(myCustomRoleId), "role not active");
        assertEq(instanceReader.getRoleInfo(myCustomRoleId).pausedAt.toInt(), TimestampLib.blockTimestamp().toInt(), "unexpected paused at timestamp");
    }


    function test_instanceAuthorizationRoleSetActiveRoleNonexistent() public {
        // GIVEN setup
        RoleId fakeRoleId = RoleIdLib.toRoleId(12345);

        // WHEN + THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                IInstance.ErrorInstanceNotCustomRole.selector, 
                fakeRoleId));

        vm.prank(instanceOwner);
        instance.setRoleActive(fakeRoleId, false);
    }


    function test_instanceAuthorizationRoleSetActiveRoleNotCustom() public {
        // GIVEN setup
        RoleId instanceRoleId = instance.getInstanceAdmin().getRoleForName("InstanceRole");
        // WHEN + THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                IInstance.ErrorInstanceNotCustomRole.selector, 
                instanceRoleId));

        vm.prank(instanceOwner);
        instance.setRoleActive(instanceRoleId, false);
    }


    function test_instanceAuthorizationRoleSetActiveNotInstanceOwner() public {
        // GIVEN setup
        address someAccount = makeAddr("someAccount");
        RoleId myCustomRoleId = _createRole("MyCustomRole", INSTANCE_OWNER_ROLE(), 42);

        // WHEN + THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                IInstance.ErrorInstanceNotRoleAdmin.selector, 
                myCustomRoleId,
                someAccount));

        vm.prank(someAccount);
        instance.setRoleActive(myCustomRoleId, false);
    }


    function _createRole(string memory roleName, RoleId adminRole, uint32 maxMemberCount) internal returns (RoleId) {
        vm.prank(instanceOwner);
        return instance.createRole(roleName, adminRole, maxMemberCount);
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