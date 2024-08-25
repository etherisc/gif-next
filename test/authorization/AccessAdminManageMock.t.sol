// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {Test, console} from "../../lib/forge-std/src/Test.sol";

import {AccessAdmin} from "../../contracts/authorization/AccessAdmin.sol";
import {AccessAdminForTesting} from "./AccessAdmin.t.sol";
import {AccessManagedMock} from "../mock/AccessManagedMock.sol";
import {IAccess} from "../../contracts/authorization/IAccess.sol";
import {IAccessAdmin} from "../../contracts/authorization/IAccessAdmin.sol";
import {RoleId, RoleIdLib} from "../../contracts/type/RoleId.sol";
import {Selector, SelectorLib} from "../../contracts/type/Selector.sol";
import {Str, StrLib} from "../../contracts/type/String.sol";
import {Timestamp, TimestampLib} from "../../contracts/type/Timestamp.sol";
import {AccessAdminBaseTest} from "./AccessAdmin.t.sol";

contract AccessAdminManageMockTest is AccessAdminBaseTest {

    AccessManagedMock public managedMock;
    address target;

    function setUp() public override {
        super.setUp();

        vm.startPrank(accessAdminDeployer);

        // deploy access managed mock using authority of access admin
        managedMock = new AccessManagedMock(accessAdmin.authority());
        target = address(managedMock);

        // register new target
        accessAdmin.createTarget(target, "AccessManagedMock");
        vm.stopPrank();
    }


    function test_managedMockSetup() public {
        // GIVEN (just setup)
        // solhint-disable no-console
        console.log("accessAdminDeployer", accessAdminDeployer);
        console.log("access admin", address(accessAdmin));
        console.log("access admin authority", accessAdmin.authority());
        console.log("managed mock", target);
        console.log("managed mock authority", managedMock.authority());

        console.log("==========================================");
        console.log("roles", accessAdmin.roles());
        // solhint-enable

        for(uint256 i = 0; i < accessAdmin.roles(); i++) {
            _printRoleMembers(accessAdmin, accessAdmin.getRoleId(i));
        }

        // solhint-disable no-console
        console.log("==========================================");
        console.log("targets", accessAdmin.targets());
        // solhint-enable

        for(uint256 i = 0; i < accessAdmin.targets(); i++) {
            _printTarget(accessAdmin, accessAdmin.getTargetAddress(i));
        }

        // solhint-disable no-console
        console.log("------------------------------------------");
        // solhint-enable

        // WHEN (empty)
        // THEN
        RoleId adminRole = accessAdmin.getAdminRole();
        assertTrue(accessAdmin.hasRole(address(accessAdmin), adminRole), "access admin contract does not have admin role");
        assertFalse(accessAdmin.hasRole(accessAdminDeployer, adminRole), "access admin deployer does have admin role");

        assertTrue(accessAdmin.targetExists(target));
        assertEq(accessAdmin.authorizedFunctions(target), 0, "unexpected initial number of authorized functions for target");

        // some more checks on access admin
        _checkAccessAdmin(accessAdmin, accessAdminDeployer);
    }


    function test_managedMockAuthorizeFunctionsHappyCase() public {
        // GIVEN
        AccessManager accessManager = AccessManager(accessAdmin.authority());
        RoleId adminRole = accessAdmin.getAdminRole();
        RoleId managerRole = accessAdmin.getManagerRole();

        IAccess.FunctionInfo memory increaseCounter1 = accessAdmin.toFunction(
            AccessManagedMock.increaseCounter1.selector, "increaseCounter1");

        IAccess.FunctionInfo memory increaseCounter2 = accessAdmin.toFunction(
            AccessManagedMock.increaseCounter2.selector, "increaseCounter2");

        _checkIncreaseCounter1Unauthorized(outsider, "outsider (before authorized)");
        _checkIncreaseCounter1Unauthorized(accessAdminDeployer, "aa deployer (before authorized)");

        // WHEN
        IAccess.FunctionInfo[] memory functions = new IAccess.FunctionInfo[](1);
        functions[0] = increaseCounter1;

        vm.startPrank(accessAdminDeployer);
        accessAdmin.authorizeFunctions(target, managerRole, functions);
        vm.stopPrank();

        // THEN
        // solhint-disable no-console
        console.log("==========================================");
        console.log("targets", accessAdmin.targets());
        // solhint-enable
        for(uint256 i = 0; i < accessAdmin.targets(); i++) {
            _printTarget(accessAdmin, accessAdmin.getTargetAddress(i));
        }

        _checkIncreaseCounter1Unauthorized(outsider, "outsider (after authorized)");

        assertEq(managedMock.counter1(), 0, "managed mock counter1: unexpected value");

        // increase counter 1
        vm.startPrank(accessAdminDeployer);
        managedMock.increaseCounter1();
        vm.stopPrank();

        assertEq(managedMock.counter1(), 1, "managed mock counter1: unexpected value (after increase)");

        // WHEN - unauthorize function
        vm.startPrank(accessAdminDeployer);
        accessAdmin.unauthorizeFunctions(target, functions);
        vm.stopPrank();

        // THEN
        // solhint-disable no-console
        console.log("==========================================");
        console.log("targets (after unauthorize mock)", accessAdmin.targets());
        // solhint-enable
        for(uint256 i = 0; i < accessAdmin.targets(); i++) {
            _printTarget(accessAdmin, accessAdmin.getTargetAddress(i));
        }

        _checkIncreaseCounter1Unauthorized(outsider, "outsider (after authorized)");
        _checkIncreaseCounter1Unauthorized(accessAdminDeployer, "aa deployer (after unauthorized)");
    }

    function test_managedMockAuthorizeFunctionsNotAdminRole() public {
        // GIVEN
        AccessManager accessManager = AccessManager(accessAdmin.authority());
        RoleId adminRole = accessAdmin.getAdminRole();

        IAccess.FunctionInfo memory increaseCounter1 = accessAdmin.toFunction(
            AccessManagedMock.increaseCounter1.selector, "increaseCounter1");

        // WHEN + THEN
        IAccess.FunctionInfo[] memory functions = new IAccess.FunctionInfo[](1);
        functions[0] = increaseCounter1;

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorAccessAdminAuthorizeForAdminRoleInvalid.selector,
                target));

        vm.startPrank(accessAdminDeployer);
        accessAdmin.authorizeFunctions(target, adminRole, functions);
        vm.stopPrank();
    }

    function _checkIncreaseCounter1Unauthorized(address account, string memory message) internal {
        // solhint-disable no-console
        console.log(">>> check increaseCounter1() not authorized", message);
        // solhint-enable

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessManaged.AccessManagedUnauthorized.selector,
                account));

        vm.startPrank(account);
        managedMock.increaseCounter1();
        vm.stopPrank();

    }


    function test_managedMockCheckInitialRoleAccess() public {
        // GIVEN
        AccessManager accessManager = AccessManager(accessAdmin.authority());
        RoleId adminRole = accessAdmin.getAdminRole();

        // access admin is only address that has admin Role
        address accessAdminAddress = address(accessAdmin);
        assertEq(accessAdmin.roleMembers(adminRole), 1, "unexpected number of members for admin role");
        assertTrue(accessAdmin.hasRole(accessAdminAddress, adminRole), "access admin contract does not have admin role");

        // print initial target setup
        _printTarget(accessAdmin, target);
        assertEq(accessAdmin.authorizedFunctions(target), 0, "target should not have authorized functions initially");

        // WHEN/THEN
        // check accessAdmin (with admin role) can access restricted functions regardless of granted roles
        address caller = accessAdminAddress;
        bool allowed;
        uint32 delay;
        (allowed, delay) = accessManager.canCall(caller, target, AccessManagedMock.increaseCounter1.selector);
        assertTrue(allowed, "accessAdminAddress (admin role) can't access increaseCounter1");
        assertEq(delay, 0, "unexpected delay");
        (allowed, delay) = accessManager.canCall(caller, target, AccessManagedMock.increaseCounter2.selector);
        assertTrue(allowed, "accessAdminAddress (admin role) can't access increaseCounter2");
        assertEq(delay, 0, "unexpected delay");

        // check accessAdminDeployer (with admin manager) can't access restricted functions regardless of granted roles
        caller = accessAdminDeployer;
        (allowed, delay) = accessManager.canCall(caller, target, AccessManagedMock.increaseCounter1.selector);
        assertFalse(allowed, "accessAdminDeployer (admin role) can access increaseCounter1");
        assertEq(delay, 0, "unexpected delay");
        (allowed, delay) = accessManager.canCall(caller, target, AccessManagedMock.increaseCounter2.selector);
        assertFalse(allowed, "accessAdminDeployer (admin role) can access increaseCounter2");
        assertEq(delay, 0, "unexpected delay");
    }


    function test_managedMockLockAndUnlockTarget() public {
        // GIVEN
        address accessAdminAddress = address(accessAdmin);
        AccessManager accessManager = AccessManager(accessAdmin.authority());
        RoleId adminRole = accessAdmin.getAdminRole();
        RoleId managerRole = accessAdmin.getManagerRole();

        // grant manager role access to increaseCounter2
        IAccess.FunctionInfo memory increaseCounter1 = accessAdmin.toFunction(
            AccessManagedMock.increaseCounter1.selector, "increaseCounter1");

        IAccess.FunctionInfo memory increaseCounter2 = accessAdmin.toFunction(
            AccessManagedMock.increaseCounter2.selector, "increaseCounter2");

        // WHEN
        IAccess.FunctionInfo[] memory functions = new IAccess.FunctionInfo[](1);
        functions[0] = increaseCounter2;

        vm.startPrank(accessAdminDeployer);
        accessAdmin.authorizeFunctions(target, managerRole, functions);
        vm.stopPrank();

        // THEN (mock target unlocked)
        assertFalse(accessAdmin.isTargetLocked(target), "target is closed");

        // check accessAdmin (with admin role) can access restricted functions regardless of granted roles
        // check aa deployer (with manager role) can access only granted restricted functions
        address caller = accessAdminAddress;
        bool allowed;

        allowed = accessAdmin.canCall(accessAdminAddress, target, increaseCounter1.selector);
        assertTrue(allowed, "accessAdminAddress (admin role) can't access (unlocked) increaseCounter1");
        allowed = accessAdmin.canCall(accessAdminDeployer, target, increaseCounter1.selector);
        assertFalse(allowed, "accessAdminDeployer (manager role) can't access (unlocked) increaseCounter1");

        allowed = accessAdmin.canCall(accessAdminAddress, target, increaseCounter2.selector);
        assertFalse(allowed, "accessAdminAddress (admin role) can't access (unlocked) increaseCounter2");
        allowed = accessAdmin.canCall(accessAdminDeployer, target, increaseCounter2.selector);
        assertTrue(allowed, "accessAdminDeployer (manager role) can't access (unlocked) increaseCounter2");

        // print target setup after given
        _printTarget(accessAdmin, target);
        assertEq(accessAdmin.authorizedFunctions(target), 1, "target should only have 1 authorized functions after given");

        // WHEN lock mock target
        vm.startPrank(accessAdminDeployer);
        accessAdmin.setTargetLocked(target, true);
        vm.stopPrank();

        // THEN
        assertTrue(accessAdmin.isTargetLocked(target), "target not closed");

        allowed = accessAdmin.canCall(accessAdminAddress, target, increaseCounter1.selector);
        assertFalse(allowed, "accessAdminAddress (admin role) can access (locked) increaseCounter1");
        allowed = accessAdmin.canCall(accessAdminDeployer, target, increaseCounter1.selector);
        assertFalse(allowed, "accessAdminDeployer (manager role) can access (locked) increaseCounter1");

        allowed = accessAdmin.canCall(accessAdminAddress, target, increaseCounter2.selector);
        assertFalse(allowed, "accessAdminAddress (admin role) can access (locked) increaseCounter2");
        allowed = accessAdmin.canCall(accessAdminDeployer, target, increaseCounter2.selector);
        assertFalse(allowed, "accessAdminDeployer (manager role) can access (locked) increaseCounter2");

        // WHEN - unlock mock target again
        vm.startPrank(accessAdminDeployer);
        accessAdmin.setTargetLocked(target, false);
        vm.stopPrank();

        // THEN - admin must be able again to call
        assertFalse(accessAdmin.isTargetLocked(target), "target is closed");

        allowed = accessAdmin.canCall(accessAdminAddress, target, increaseCounter1.selector);
        assertTrue(allowed, "accessAdminAddress (admin role) can't access (unlocked) increaseCounter1");
        allowed = accessAdmin.canCall(accessAdminDeployer, target, increaseCounter1.selector);
        assertFalse(allowed, "accessAdminDeployer (manager role) can't access (unlocked) increaseCounter1");

        allowed = accessAdmin.canCall(accessAdminAddress, target, increaseCounter2.selector);
        assertFalse(allowed, "accessAdminAddress (admin role) can't access (unlocked) increaseCounter2");
        allowed = accessAdmin.canCall(accessAdminDeployer, target, increaseCounter2.selector);
        assertTrue(allowed, "accessAdminDeployer (manager role) can't access (unlocked) increaseCounter2");
    }

    function _checkAccessAdmin(
        AccessAdminForTesting aa, 
        address expectedDeployer
    )
        internal
    {
        assertTrue(address(aa) != address(0), "access admin is 0");
        assertTrue(aa.authority() != address(0), "access admin authority is 0");

        assertEq(aa.deployer(), expectedDeployer, "unexpected deployer");

        // check aa roles
        assertTrue(aa.hasRole(address(aa), aa.getAdminRole()), "access admin missing admin role");
        assertFalse(aa.hasRole(address(aa), aa.getManagerRole()), "access admin has manager role");
        assertTrue(aa.hasRole(address(aa), aa.getPublicRole()), "access admin missing public role");

        // check deployer roles
        assertFalse(aa.hasRole(expectedDeployer, aa.getAdminRole()), "deployer has admin role");
        assertTrue(aa.hasRole(expectedDeployer, aa.getManagerRole()), "deployer missing manager role");
        assertTrue(aa.hasRole(expectedDeployer, aa.getPublicRole()), "deployer missing public role");

        // check outsider roles
        assertFalse(aa.hasRole(outsider, aa.getAdminRole()), "outsider has admin role");
        assertFalse(aa.hasRole(outsider, aa.getManagerRole()), "outsider has manager role");
        assertTrue(aa.hasRole(outsider, aa.getPublicRole()), "outsider missing public role");

        // count roles and check role ids
        assertEq(aa.roles(), 3, "unexpected number of roles for freshly initialized access admin");
        assertEq(aa.getRoleId(0).toInt(), aa.getAdminRole().toInt(), "unexpected admin role id");
        assertEq(aa.getRoleId(0).toInt(), type(uint64).min, "unexpected admin role id (absolute)");
        assertEq(aa.getRoleId(1).toInt(), aa.getPublicRole().toInt(), "unexpected public role id");
        assertEq(aa.getRoleId(1).toInt(), type(uint64).max, "unexpected public role id (absolute)");
        assertEq(aa.getRoleId(2).toInt(), aa.getManagerRole().toInt(), "unexpected manager role id");
        assertEq(aa.getRoleId(2).toInt(), 1, "unexpected manager role id (absolute)");

        // check admin role
        _checkRole(
            aa,
            aa.getAdminRole(), 
            aa.getAdminRole(),
            aa.ADMIN_ROLE_NAME(),
            TimestampLib.max(), 
            TimestampLib.blockTimestamp());

        // check public role
        _checkRole(
            aa,
            aa.getPublicRole(), 
            aa.getAdminRole(),
            aa.PUBLIC_ROLE_NAME(),
            TimestampLib.max(), 
            TimestampLib.blockTimestamp());

        // check manager role
        _checkRole(
            aa,
            aa.getManagerRole(), 
            aa.getAdminRole(),
            aa.MANAGER_ROLE_NAME(),
            TimestampLib.max(), 
            TimestampLib.blockTimestamp());

        // check non existent role
        RoleId missingRoleId = RoleIdLib.toRoleId(1313);
        assertFalse(aa.roleExists(missingRoleId), "missing role exists"); 

        assertFalse(aa.getRoleForName(StrLib.toStr("NoSuchRole")).exists, "NoSuchRole exists");

        // minimal check on access manager of access admin
        AccessManager accessManager = AccessManager(aa.authority());
        bool isMember;
        uint32 executionDelay;

        (isMember, executionDelay) = accessManager.hasRole(accessManager.ADMIN_ROLE(), address(aa));
        assertTrue(isMember, "access admin not admin of access manager");
        assertEq(executionDelay, 0, "acess admin role execution delay not 0");
    }

    function _checkRole(
        IAccessAdmin aa,
        RoleId roleId, 
        RoleId expectedAdminRoleId,
        string memory expectedName,
        Timestamp expectedDisabledAt,
        Timestamp expectedCreatedAt
    )
        internal
    {
        // solhint-disable-next-line
        console.log("checking role", expectedName);

        IAccessAdmin.RoleInfo memory info = aa.getRoleInfo(roleId);
        assertEq(info.adminRoleId.toInt(), expectedAdminRoleId.toInt(), "unexpected admin role (role info)");
        assertEq(info.name.toString(), expectedName, "unexpected role name");
        assertTrue(info.createdAt.gtz(), "role does not exist");

        Str roleName = StrLib.toStr(expectedName);
        IAccessAdmin.RoleNameInfo memory nameInfo = aa.getRoleForName(roleName);
        assertTrue(nameInfo.exists, "role name info missing");
        assertEq(nameInfo.roleId.toInt(), roleId.toInt(), "unexpected role name rold id");
    }

    function _printRoleMembers(AccessAdmin aa, RoleId roleId) internal {
        IAccessAdmin.RoleInfo memory info = aa.getRoleInfo(roleId);
        uint256 members = aa.roleMembers(roleId);

        // solhint-disable no-console
        console.log("role", info.name.toString(), "id", roleId.toInt()); 
        console.log("role members", members); 
        for(uint i = 0; i < members; i++) {
            console.log("-", i, aa.getRoleMember(roleId, i));
        }
        // solhint-enable
    }

    function _printTarget(AccessAdmin aa, address trgt) internal view {
        IAccessAdmin.TargetInfo memory info = aa.getTargetInfo(trgt);

        // solhint-disable no-console
        uint256 functions = aa.authorizedFunctions(trgt);
        console.log("target", info.name.toString(), "address", trgt);
        console.log("authorized functions", functions);
        for(uint256 i = 0; i < functions; i++) {
            (
                IAccess.FunctionInfo memory func,
                RoleId roleId
            ) = aa.getAuthorizedFunction(trgt, i);
            string memory role = aa.getRoleInfo(roleId).name.toString();

            console.log("-", i, string(abi.encodePacked(func.name.toString(), "(): ", role,":")), roleId.toInt());
        }
        // solhint-enable
    }

}
