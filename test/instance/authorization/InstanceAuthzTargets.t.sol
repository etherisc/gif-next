// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {console} from "../../../lib/forge-std/src/Test.sol";

import {IAccess} from "../../../contracts/authorization/IAccess.sol";
import {IAccessAdmin} from "../../../contracts/authorization/IAccessAdmin.sol";
import {IInstance} from "../../../contracts/instance/IInstance.sol";

import {AccessManagedMock} from "../../mock/AccessManagedMock.sol";
import {InstanceAuthzBaseTest} from "./InstanceAuthzBase.t.sol";
import {RoleId, RoleIdLib} from "../../../contracts/type/RoleId.sol";
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
        instance.createTarget(address(target), targetName);

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

    function test_instanceAuthzTargetsAuthorizeFunctionsHappyCase() public {
        // GIVEN
        AccessManagedMock target = _deployAccessManagedMock();
        string memory targetName = "MyTarget";

        vm.prank(instanceOwner);
        instance.createTarget(address(target), targetName);

        assertTrue(instanceReader.targetExists(address(target)), "target not existing after create");
        assertFalse(instanceReader.isLocked(address(target)), "target locked");
        assertEq(target.counter1(), 0, "unexpected initial counter value");

        // WHEN + THEN attempt to call unauthorized function
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessManaged.AccessManagedUnauthorized.selector, 
                outsider));

        vm.prank(outsider);
        target.increaseCounter1();

        assertEq(target.counter1(), 0, "unexpected initial counter value");

        // WHEN - add function authz
        RoleId publicRoleId = instance.getInstanceAdmin().getPublicRole();
        IAccess.FunctionInfo[] memory functions = new IAccess.FunctionInfo[](1);
        functions[0] = instanceReader.toFunction(AccessManagedMock.increaseCounter1.selector, "increaseCounter1");

        vm.prank(instanceOwner);
        instance.authorizeFunctions(address(target), publicRoleId, functions);

        // must not revert now
        vm.prank(outsider);
        target.increaseCounter1();

        // THEN
        assertEq(target.counter1(), 1, "unexpected counter value after increaseCounter1");
    }


    function test_instanceAuthzTargetsUnauthorizeFunctionsHappyCase() public {
        // GIVEN
        AccessManagedMock target = _deployAccessManagedMock();
        string memory targetName = "MyTarget";
        RoleId publicRoleId = instance.getInstanceAdmin().getPublicRole();
        IAccess.FunctionInfo[] memory functions = new IAccess.FunctionInfo[](1);
        functions[0] = instanceReader.toFunction(AccessManagedMock.increaseCounter1.selector, "increaseCounter1");

        vm.startPrank(instanceOwner);
        instance.createTarget(address(target), targetName);
        instance.authorizeFunctions(address(target), publicRoleId, functions);
        vm.stopPrank();

        // must not revert
        vm.prank(outsider);
        target.increaseCounter1();

        assertEq(target.counter1(), 1, "unexpected counter value after increaseCounter1");

        // WHEN - unauthorize function
        vm.prank(instanceOwner);
        instance.unauthorizeFunctions(address(target), functions);

        // THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessManaged.AccessManagedUnauthorized.selector, 
                outsider));
                
        vm.prank(outsider);
        target.increaseCounter1();

        assertEq(target.counter1(), 1, "unexpected counter value after increaseCounter1");
    }


    function test_instanceAuthzToTargetAll() public {
        bytes4 signature = AccessManagedMock.increaseCounter1.selector;
        string memory name = "increaseCounter1";

        IAccess.FunctionInfo memory myFunction = instanceReader.toFunction(signature, name);
        assertEq(myFunction.name.toString(), name, "unexpected function name");
        assertEq(myFunction.selector.toBytes4(), signature, "unexpected function selector");
        assertEq(myFunction.createdAt.toInt(), TimestampLib.blockTimestamp().toInt(), "unexpected function creation time");

        // check signature zero check
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorAccessAdminSelectorZero.selector));

        instanceReader.toFunction(bytes4(0), name);

        // check name length check
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorAccessAdminFunctionNameEmpty.selector));

        instanceReader.toFunction(signature, "");
    }


    //--- helper functions ----------------------------------------------------//

    // TODO cleanup
    // function _deployAccessManagedMock() internal returns (AccessManagedMock accessManagedMock) {
    //     return _deployAccessManagedMock();
    // }

    function _deployAccessManagedMock() internal returns (AccessManagedMock accessManagedMock) {
        accessManagedMock = new AccessManagedMock(instance.authority());
    }
}