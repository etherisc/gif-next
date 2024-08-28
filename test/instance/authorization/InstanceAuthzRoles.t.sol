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

contract InstanceAuthzRolesTest is GifTest {

    function test_instanceAuthzSetup() public {
        _printRoles();

        // check initial roles
        assertEq(instanceAdmin.roles(), 15, "unexpected initial instance roles count (admin)");
        assertEq(instanceReader.roles(), 15, "unexpected initial instance roles count (reader)");
    }

    //--- role creation ----------------------------------------------------//

    function test_instanceAuthzRolesCreateHappyCase() public {
        // GIVEN setup
        uint256 rolesBefore = instanceReader.roles();
        string memory roleName = "MyCustomRole";
        RoleId expectedRoleId = RoleIdLib.toRoleId(1000000);
        RoleId adminRoleId = INSTANCE_OWNER_ROLE();
        uint32 maxMemberCount = 42;

        // WHEN 
        vm.expectEmit(address(instance));
        emit IInstance.LogInstanceCustomRoleCreated(
            expectedRoleId, 
            roleName, 
            adminRoleId, 
            maxMemberCount);

        vm.prank(instanceOwner);
        RoleId myCustomRoleId = instance.createRole(
            roleName, 
            adminRoleId, 
            maxMemberCount);

        // THEN
        assertEq(myCustomRoleId.toInt(), expectedRoleId.toInt(), "unexpected role id");
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


    function test_instanceAuthzRolesCreateStackedHappyCase() public {
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


    function test_instanceAuthzRolesCreateNotInstanceOwner() public {
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


    function test_instanceAuthzRolesCreateRoleNameEmpty() public {
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


    function test_instanceAuthzRolesCreateAdminRoleNonexistent() public {
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

    //--- role activation ----------------------------------------------------//

    function test_instanceAuthzRolesSetActiveHappyCase1() public {
        // GIVEN setup
        RoleId myCustomRoleId = _createRole("MyCustomRole", INSTANCE_OWNER_ROLE(), 42);

        assertTrue(instanceReader.isRoleActive(myCustomRoleId), "role not active");

        // WHEN - dactivate
        vm.expectEmit(address(instance));
        emit IInstance.LogInstanceCustomRoleActiveSet(
            myCustomRoleId, 
            false, 
            instanceOwner);

        vm.prank(instanceOwner);
        instance.setRoleActive(myCustomRoleId, false);

        // THEN
        assertFalse(instanceReader.isRoleActive(myCustomRoleId), "role not active");
        assertEq(instanceReader.getRoleInfo(myCustomRoleId).pausedAt.toInt(), TimestampLib.blockTimestamp().toInt(), "unexpected paused at timestamp");

        // WHEN - activate
        vm.expectEmit(address(instance));
        emit IInstance.LogInstanceCustomRoleActiveSet(
            myCustomRoleId, 
            true, 
            instanceOwner);

        vm.prank(instanceOwner);
        instance.setRoleActive(myCustomRoleId, true);

        // THEN
        assertTrue(instanceReader.isRoleActive(myCustomRoleId), "role not active");
        assertEq(instanceReader.getRoleInfo(myCustomRoleId).pausedAt.toInt(), TimestampLib.max().toInt(), "unexpected paused at timestamp");
    }


    function test_instanceAuthzRolesSetActiveHappyCase2() public {
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


    function test_instanceAuthzRolesSetActiveRoleNonexistent() public {
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


    function test_instanceAuthzRolesSetActiveRoleNotCustom() public {
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


    function test_instanceAuthzRolesSetActiveNotInstanceOwner() public {
        // GIVEN 
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

    //--- role granting ----------------------------------------------------//

    function test_instanceAuthzRolesGrantInstancOwnerHappyCase() public {
        // GIVEN 
        RoleId myCustomRoleId = _createRole("MyCustomRole", INSTANCE_OWNER_ROLE(), 42);
        address someAccount = makeAddr("someAccount");

        assertFalse(instanceReader.isRoleMember(myCustomRoleId, someAccount), "some account unexpectedly role member");
        assertEq(instanceReader.roleMembers(myCustomRoleId), 0, "unexpected role member count");

        // WHEN
        vm.expectEmit(address(instance));
        emit IInstance.LogInstanceCustomRoleGranted(
            myCustomRoleId, 
            someAccount, 
            instanceOwner);

        vm.prank(instanceOwner);
        instance.grantRole(myCustomRoleId, someAccount);

        // THEN
        assertTrue(instanceReader.isRoleMember(myCustomRoleId, someAccount), "some account not role member");
        assertEq(instanceReader.roleMembers(myCustomRoleId), 1, "unexpected role member count");
        assertEq(instanceReader.getRoleMember(myCustomRoleId, 0), someAccount, "unexpected role member");
    }


    function test_instanceAuthzRolesGrantSomeAccountHappyCase() public {
        // GIVEN 
        RoleId myCustomAdminRoleId = _createRole("MyCustomAdminRole", INSTANCE_OWNER_ROLE(), 1);
        RoleId myCustomRoleId = _createRole("MyCustomRole", myCustomAdminRoleId, 42);
        address someAdminAccount = makeAddr("someAdminAccount");
        address someAccount1 = makeAddr("someAccount1");
        address someAccount2 = makeAddr("someAccount2");
        address instanceOwnerColleague  = makeAddr("instanceOwnerColleague");

        assertFalse(instanceReader.isRoleMember(myCustomAdminRoleId, someAdminAccount), "some admin account unexpectedly role member (before)");
        assertFalse(instanceReader.isRoleMember(myCustomRoleId, someAccount1), "some account1 unexpectedly role member (before)");
        assertFalse(instanceReader.isRoleMember(myCustomRoleId, someAccount2), "some account2 unexpectedly role member (before)");
        assertFalse(instanceReader.isRoleMember(myCustomRoleId, instanceOwnerColleague), "instance owner colleague unexpectedly role member (before)");
        assertEq(instanceReader.roleMembers(myCustomAdminRoleId), 0, "unexpected admin role member count (before)");
        assertEq(instanceReader.roleMembers(myCustomRoleId), 0, "unexpected role member count (before)");

        // WHEN grantings by instance owner
        vm.startPrank(instanceOwner);
        instance.grantRole(myCustomAdminRoleId, someAdminAccount);
        instance.grantRole(myCustomRoleId, instanceOwnerColleague);
        vm.stopPrank();

        // THEN
        assertTrue(instanceReader.isRoleMember(myCustomAdminRoleId, someAdminAccount), "some admin account not role member (after1)");
        assertTrue(instanceReader.isRoleAdmin(myCustomRoleId, someAdminAccount), "some admin account not admin role member (after1)");

        assertFalse(instanceReader.isRoleMember(myCustomRoleId, someAccount1), "some account1 unexpectedly role member (after1)");
        assertFalse(instanceReader.isRoleMember(myCustomRoleId, someAccount2), "some account2 unexpectedly role member (after1)");
        assertTrue(instanceReader.isRoleMember(myCustomRoleId, instanceOwnerColleague), "instance owner colleague not role member (after1)");
        assertEq(instanceReader.roleMembers(myCustomAdminRoleId), 1, "unexpected admin role member count (after1)");
        assertEq(instanceReader.roleMembers(myCustomRoleId), 1, "unexpected role member count (after1)");

        assertTrue(instanceReader.isRoleAdmin(myCustomRoleId, someAdminAccount), "some admin account not role admin");

        // WHEN grantings by some admin account
        vm.startPrank(someAdminAccount);
        instance.grantRole(myCustomRoleId, someAccount1);
        instance.grantRole(myCustomRoleId, someAccount2);
        vm.stopPrank();

        // THEN
        assertTrue(instanceReader.isRoleMember(myCustomAdminRoleId, someAdminAccount), "some admin account not role member (after2)");
        assertTrue(instanceReader.isRoleMember(myCustomRoleId, someAccount1), "some account1 not role member (after2)");
        assertTrue(instanceReader.isRoleMember(myCustomRoleId, someAccount2), "some account2 not role member (after2)");
        assertTrue(instanceReader.isRoleMember(myCustomRoleId, instanceOwnerColleague), "instance owner colleague not role member (after2)");
        assertEq(instanceReader.roleMembers(myCustomAdminRoleId), 1, "unexpected admin role member count (after2)");
        assertEq(instanceReader.roleMembers(myCustomRoleId), 3, "unexpected role member count (after2)");
    }


    function test_instanceAuthzRolesGrantInactiveRole() public {
        // GIVEN
        RoleId customRoleId = _createRole("CustomRole", INSTANCE_OWNER_ROLE(), 3);
        address someAccount = makeAddr("someAccount");

        // pause role
        vm.prank(instanceOwner);
        instance.setRoleActive(customRoleId, false);

        assertFalse(instanceReader.isRoleMember(customRoleId, someAccount), "unexpected role member (before)");
        assertEq(instanceReader.roleMembers(customRoleId), 0, "unexpected role member count (before)");

        // WHEN + THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorAccessAdminRoleIsPaused.selector, 
                customRoleId));

        vm.prank(instanceOwner);
        instance.grantRole(customRoleId, someAccount);

        // THEN nothing happened
        assertFalse(instanceReader.isRoleMember(customRoleId, someAccount), "unexpected role member (after)");
        assertEq(instanceReader.roleMembers(customRoleId), 0, "unexpected role member count (after)");
    }


    function test_instanceAuthzRolesGrantMaxMemberExceeded() public {
        // GIVEN 
        uint32 maxMemberCount = 3;
        RoleId customRoleId = _createRole("CustomRole", INSTANCE_OWNER_ROLE(), maxMemberCount);
        address someAccount = makeAddr("someAccount");

        assertFalse(instanceReader.isRoleMember(customRoleId, someAccount), "some account unexpectedly role member (before)");
        assertEq(instanceReader.roleMembers(customRoleId), 0, "unexpected role member count (before)");

        // WHEN multiple grantings to same account
        vm.startPrank(instanceOwner);
        instance.grantRole(customRoleId, someAccount);
        instance.grantRole(customRoleId, someAccount);
        instance.grantRole(customRoleId, someAccount);
        instance.grantRole(customRoleId, someAccount);
        vm.stopPrank();

        // THEN everything ok so far
        assertTrue(instanceReader.isRoleMember(customRoleId, someAccount), "some account not role member (after1)");
        assertEq(instanceReader.roleMembers(customRoleId), 1, "unexpected role member count (after1)");
        assertEq(instanceReader.getRoleMember(customRoleId, 0), someAccount, "unexpected 1st role member (after1)");

        // WHEN reach max member count
        address someAccount1 = makeAddr("someAccount1");
        address someAccount2 = makeAddr("someAccount2");

        vm.startPrank(instanceOwner);
        instance.grantRole(customRoleId, someAccount1);
        instance.grantRole(customRoleId, someAccount2);
        vm.stopPrank();

        // THEN still ok
        assertTrue(instanceReader.isRoleMember(customRoleId, someAccount), "some account not role member (after2)");
        assertTrue(instanceReader.isRoleMember(customRoleId, someAccount1), "some account1 not role member (after2)");
        assertTrue(instanceReader.isRoleMember(customRoleId, someAccount2), "some account2 not role member (after2)");
        assertEq(instanceReader.roleMembers(customRoleId), 3, "unexpected role member count (after2)");
        assertEq(instanceReader.getRoleMember(customRoleId, 0), someAccount, "unexpected 1st role member (after2)");
        assertEq(instanceReader.getRoleMember(customRoleId, 1), someAccount1, "unexpected 2nd role member (after2)");
        assertEq(instanceReader.getRoleMember(customRoleId, 2), someAccount2, "unexpected 3rd role member (after2)");

        // WHEN exceed max member count
        address someAccount3 = makeAddr("someAccount3");

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorAccessAdminRoleMembersLimitReached.selector, 
                customRoleId,
                maxMemberCount));

        vm.prank(instanceOwner);
        instance.grantRole(customRoleId, someAccount3);

        // THEN
        assertEq(instanceReader.roleMembers(customRoleId), 3, "unexpected role member count (after2)");
    }


    function test_instanceAuthzRolesGrantNotInstanceOwner() public {
        // GIVEN 
        uint32 maxMemberCount = 3;
        RoleId customRoleId = _createRole("CustomRole", INSTANCE_OWNER_ROLE(), maxMemberCount);
        address someAccount = makeAddr("someAccount");

        assertFalse(instanceReader.isRoleMember(customRoleId, someAccount), "some account unexpectedly role member (before)");
        assertEq(instanceReader.roleMembers(customRoleId), 0, "unexpected role member count (before)");

        // WHEN + THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                IInstance.ErrorInstanceNotRoleAdmin.selector, 
                customRoleId,
                someAccount));
        
        vm.prank(someAccount);
        instance.grantRole(customRoleId, someAccount);

        // THEN nothing happened
        assertEq(instanceReader.roleMembers(customRoleId), 0, "unexpected role member count (after)");
        assertFalse(instanceReader.isRoleMember(customRoleId, someAccount), "some account unexpectedly role member (after)");
    }


    function test_instanceAuthzRolesGrantNotRoleAdmin() public {
        // GIVEN 
        RoleId myCustomAdminRoleId = _createRole("MyCustomAdminRole", INSTANCE_OWNER_ROLE(), 1);
        RoleId myCustomRoleId = _createRole("MyCustomRole", myCustomAdminRoleId, 42);
        address someAdminAccount = makeAddr("someAdminAccount");
        address someAccount = makeAddr("someAccount");

        vm.prank(instanceOwner);
        instance.grantRole(myCustomAdminRoleId, someAdminAccount);

        assertTrue(instanceReader.isRoleAdmin(myCustomRoleId, someAdminAccount), "some admin account not role admin");

        // WHEN + THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                IInstance.ErrorInstanceNotRoleAdmin.selector, 
                myCustomRoleId,
                someAccount));

        vm.prank(someAccount);
        instance.grantRole(myCustomRoleId, someAccount);
    }

    function test_instanceAuthzRolesGrantRoleNonexisting() public {
        // GIVEN
        RoleId fakeRoleId = RoleIdLib.toRoleId(12345);
        address someAccount = makeAddr("someAccount");

        // WHEN + THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                IInstance.ErrorInstanceNotCustomRole.selector, 
                fakeRoleId));

        vm.prank(instanceOwner);
        instance.grantRole(fakeRoleId, someAccount);
    }


    function test_instanceAuthzRolesGrantRoleNotCustomRole() public {
        // GIVEN
        RoleId instanceRoleId = instanceAdmin.getRoleForName("InstanceRole");
        address someAccount = makeAddr("someAccount");

        // WHEN + THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                IInstance.ErrorInstanceNotCustomRole.selector, 
                instanceRoleId));

        vm.prank(instanceOwner);
        instance.grantRole(instanceRoleId, someAccount);
    }


    //--- role revoking ----------------------------------------------------//

    function test_instanceAuthzRolesRevokeInstancOwnerHappyCase() public {
        // GIVEN 
        RoleId myCustomRoleId = _createRole("MyCustomRole", INSTANCE_OWNER_ROLE(), 42);
        address someAccount = makeAddr("someAccount");

        vm.prank(instanceOwner);
        instance.grantRole(myCustomRoleId, someAccount);

        assertTrue(instanceReader.isRoleMember(myCustomRoleId, someAccount), "some account not role member (before)");
        assertEq(instanceReader.roleMembers(myCustomRoleId), 1, "unexpected role member count (before)");

        // WHEN + THEN
        vm.expectEmit(address(instance));
        emit IInstance.LogInstanceCustomRoleRevoked(
            myCustomRoleId, 
            someAccount, 
            instanceOwner);

        vm.prank(instanceOwner);
        instance.revokeRole(myCustomRoleId, someAccount);

        // THEN
        assertFalse(instanceReader.isRoleMember(myCustomRoleId, someAccount), "some account unexpectedly role member (after)");
        assertEq(instanceReader.roleMembers(myCustomRoleId), 0, "unexpected role member count (after)");
    }


    function test_instanceAuthzRolesRevokeRoleAdminHappyCase() public {
        // GIVEN 
        RoleId myCustomAdminRoleId = _createRole("MyCustomAdminRole", INSTANCE_OWNER_ROLE(), 1);
        RoleId myCustomRoleId = _createRole("MyCustomRole", myCustomAdminRoleId, 42);
        address someAdminAccount = makeAddr("someAdminAccount");
        address someAccount1 = makeAddr("someAccount1");
        address someAccount2 = makeAddr("someAccount2");

        vm.prank(instanceOwner);
        instance.grantRole(myCustomAdminRoleId, someAdminAccount);

        vm.startPrank(someAdminAccount);
        instance.grantRole(myCustomRoleId, someAccount1);
        instance.grantRole(myCustomRoleId, someAccount2);
        vm.stopPrank();

        assertTrue(instanceReader.isRoleMember(myCustomAdminRoleId, someAdminAccount), "some admin account unexpectedly role member (before)");
        assertTrue(instanceReader.isRoleMember(myCustomRoleId, someAccount1), "some account1 unexpectedly role member (before)");
        assertTrue(instanceReader.isRoleMember(myCustomRoleId, someAccount2), "some account2 unexpectedly role member (before)");
        assertEq(instanceReader.roleMembers(myCustomAdminRoleId), 1, "unexpected admin role member count (before)");
        assertEq(instanceReader.roleMembers(myCustomRoleId), 2, "unexpected role member count (before)");

        // WHEN revoke by role admin
        vm.prank(someAdminAccount);
        instance.revokeRole(myCustomRoleId, someAccount1);

        // THEN
        assertTrue(instanceReader.isRoleMember(myCustomAdminRoleId, someAdminAccount), "some admin account unexpectedly role member (after1)");
        assertFalse(instanceReader.isRoleMember(myCustomRoleId, someAccount1), "some account1 unexpectedly role member (after1)");
        assertTrue(instanceReader.isRoleMember(myCustomRoleId, someAccount2), "some account2 unexpectedly role member (after1)");
        assertEq(instanceReader.roleMembers(myCustomAdminRoleId), 1, "unexpected admin role member count (after1)");
        assertEq(instanceReader.roleMembers(myCustomRoleId), 1, "unexpected role member count (after1)");

        // WHEN revoke by instance owner
        vm.prank(instanceOwner);
        instance.revokeRole(myCustomRoleId, someAccount2);

        // THEN
        assertTrue(instanceReader.isRoleMember(myCustomAdminRoleId, someAdminAccount), "some admin account unexpectedly role member (after2)");
        assertFalse(instanceReader.isRoleMember(myCustomRoleId, someAccount1), "some account1 unexpectedly role member (after2)");
        assertFalse(instanceReader.isRoleMember(myCustomRoleId, someAccount2), "some account2 unexpectedly role member (after2)");
        assertEq(instanceReader.roleMembers(myCustomAdminRoleId), 1, "unexpected admin role member count (after2)");
        assertEq(instanceReader.roleMembers(myCustomRoleId), 0, "unexpected role member count (after2)");
    }


    function test_instanceAuthzRolesRevokeNotRoleAdmin() public {
        // GIVEN 
        RoleId myCustomRoleId = _createRole("MyCustomRole", INSTANCE_OWNER_ROLE(), 42);
        address someAdminAccount = makeAddr("someAdminAccount");
        address someAccount = makeAddr("someAccount");

        vm.prank(instanceOwner);
        instance.grantRole(myCustomRoleId, someAccount);

        assertTrue(instanceReader.isRoleMember(myCustomRoleId, someAccount), "some account not role member (before)");
        assertEq(instanceReader.roleMembers(myCustomRoleId), 1, "unexpected role member count (before)");

        // WHEN + THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                IInstance.ErrorInstanceNotRoleAdmin.selector,
                myCustomRoleId, 
                someAdminAccount));

        vm.prank(someAdminAccount);
        instance.revokeRole(myCustomRoleId, someAccount);

        // THEN nothing happened
        assertTrue(instanceReader.isRoleMember(myCustomRoleId, someAccount), "some account not role member (before)");
        assertEq(instanceReader.roleMembers(myCustomRoleId), 1, "unexpected role member count (before)");
    }


    //--- helper functions ----------------------------------------------------//

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