// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../../../lib/forge-std/src/Test.sol";

import {IAccess} from "../../../contracts/authorization/IAccess.sol";
import {IAccessAdmin} from "../../../contracts/authorization/IAccessAdmin.sol";
import {IInstance} from "../../../contracts/instance/IInstance.sol";

import {AccessManagedMock} from "../../mock/AccessManagedMock.sol";
import {InstanceAuthzBaseTest} from "./InstanceAuthzBase.t.sol";
import {INftOwnable} from "../../../contracts/shared/INftOwnable.sol";
import {RoleId, RoleIdLib, ADMIN_ROLE, INSTANCE_OWNER_ROLE} from "../../../contracts/type/RoleId.sol";
import {TimestampLib} from "../../../contracts/type/Timestamp.sol";


contract InstanceAuthzTargetsTest is InstanceAuthzBaseTest {

    function test_instanceAuthzTargetsSetup() public {
        _printRoles();
        _printTargets();

        // check initial roles
        assertEq(instanceAdmin.targets(), 5, "unexpected initial instance target count (admin)");
        assertEq(instanceReader.targets(), 5, "unexpected initial instance target count (reader)");
    }


    function test_instanceAuthzTargetsCreateHappyCase() public {
        // GIVEN
        AccessManagedMock target = _deployAccessManagedMock();
        RoleId expectedRoleId = RoleIdLib.toRoleId(1000000);
        string memory targetName = "MyTarget";

        uint256 initialTargetCount = instanceAdmin.targets();
        uint256 initialRoleCount = instanceAdmin.roles();

        // WHEN + THEN
        vm.expectEmit(address(instance));
        emit IInstance.LogInstanceCustomTargetCreated(address(target), expectedRoleId, targetName);

        vm.prank(instanceOwner);
        RoleId myTargetRoleId = instance.createTarget(address(target), targetName);

        // THEN
        assertEq(instanceAdmin.targets(), initialTargetCount + 1, "unexpected target count after create (admin)");
        assertEq(instanceReader.targets(), initialTargetCount + 1, "unexpected target count after create (reader)");
        assertEq(instanceReader.roles(), initialRoleCount + 1, "unexpected role count after create (reader)");

        assertTrue(instanceReader.targetExists(address(target)), "target not existing after create");
        assertTrue(instanceReader.roleExists(myTargetRoleId), "role not existing after create");
        assertEq(myTargetRoleId.toInt(), expectedRoleId.toInt(), "unexpected target role id");

        // check target info
        assertTrue(instanceReader.targetExists(address(target)), "target not existing after create");
        assertFalse(instanceReader.isLocked(address(target)), "target locked");
        IAccess.TargetInfo memory targetInfo = instanceReader.getTargetInfo(address(target));
        assertEq(targetInfo.name.toString(), "MyTarget", "unexpected target name");
        assertTrue(targetInfo.targetType == IAccess.TargetType.Custom, "target type not custom");
        assertEq(targetInfo.roleId.toInt(), expectedRoleId.toInt(), "unexpected target role id");
        assertEq(targetInfo.createdAt.toInt(), TimestampLib.blockTimestamp().toInt(), "unexpected target creation time");

        // check role
        assertTrue(instanceReader.roleExists(targetInfo.roleId), "role not existing after create");
        assertFalse(instanceReader.isRoleCustom(targetInfo.roleId), "role is custom");
        assertEq(instanceReader.roleMembers(targetInfo.roleId), 1, "unexpected role member count");
        assertEq(instanceReader.getRoleMember(targetInfo.roleId, 0), address(target), "target not role member");

        IAccess.RoleInfo memory roleInfo = instanceReader.getRoleInfo(targetInfo.roleId);
        assertEq(roleInfo.name.toString(), "MyTarget_Role", "unexpected role name");
        assertTrue(roleInfo.roleType == IAccess.RoleType.Contract, "unexpected role type");
        assertEq(roleInfo.maxMemberCount, 1, "unexpected max member count");
        assertEq(roleInfo.createdAt.toInt(), TimestampLib.blockTimestamp().toInt(), "unexpected role creation time");
        assertEq(roleInfo.pausedAt.toInt(), TimestampLib.max().toInt(), "unexpected role pausing time");
    }


    // check locking of custom targets works the same as for targets created via authorization spec
    function test_instanceAuthzTargetsSetTargetLockedHappyCase() public {
        // GIVEN
        AccessManagedMock target = _deployAccessManagedMock();
        string memory targetName = "MyTarget";

        vm.prank(instanceOwner);
        RoleId myTargetRoleId = instance.createTarget(address(target), targetName);

        assertTrue(instanceReader.targetExists(address(target)), "target not existing after create");
        assertFalse(instanceReader.isLocked(address(target)), "target locked");

        // WHEN - lock target
        vm.prank(instanceOwner);
        instance.setTargetLocked(address(target), true);

        // THEN
        assertTrue(instanceReader.isLocked(address(target)), "target not locked after set locked");

        // WHEN - unlock target 
        vm.prank(instanceOwner);
        instance.setTargetLocked(address(target), false);

        // THEN
        assertFalse(instanceReader.isLocked(address(target)), "target locked (2)");

        // WHEN - lock target via instance lock
        vm.prank(instanceOwner);
        instance.setInstanceLocked(true);

        // THEN
        assertTrue(instanceReader.isLocked(address(target)), "target not locked after locking instance");
    }

    //--- helper functions ----------------------------------------------------//

    function _deployAccessManagedMock() internal returns (AccessManagedMock accessManagedMock) {
        return _deployAccessManagedMock(instance.authority());
    }

    function _deployAccessManagedMock(address authority) internal returns (AccessManagedMock accessManagedMock) {
        accessManagedMock = new AccessManagedMock(instance.authority());
    }
}