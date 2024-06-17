// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {Test, console} from "../../lib/forge-std/src/Test.sol";

import {AccessAdmin} from "../../contracts/shared/AccessAdmin.sol";
import {AccessManagedMock} from "../mock/AccessManagedMock.sol";
import {IAccessAdmin} from "../../contracts/shared/IAccessAdmin.sol";
import {RoleId, RoleIdLib} from "../../contracts/type/RoleId.sol";
import {Str, StrLib} from "../../contracts/type/String.sol";
import {Timestamp, TimestampLib} from "../../contracts/type/Timestamp.sol";


contract AccessAdminForTesting is AccessAdmin {

    constructor(address deployer) AccessAdmin(deployer) {
        // super constructor called implicitly
        // grant manager role access to createRoleSimple
        Function[] memory functions = new Function[](1);
        functions[0] = toFunction(AccessAdminForTesting.createRoleSimple.selector, "createRoleSimple");
        _authorizeTargetFunctions(address(this), _managerRoleId, functions);

        // grant manger role to deployer
        _grantRoleToAccount(_managerRoleId, _deployer);
    }

    function createRoleSimple(
        RoleId roleId, 
        RoleId adminRoleId, 
        string memory name
    )
        external
        restricted()
    {
        _createRole(roleId, adminRoleId, name, type(uint256).max, false);
    }
}

contract AccessAdminCloneable is AccessAdminForTesting {

    constructor(address deployer) AccessAdminForTesting(deployer) {
    }

    /// @dev initializer with externally provided accessManager
    /// IMPORTANT cloning and initialization needs to be done in a single transaction
    function initializeWithAccessManager(address accessManager) public initializer() {
        _initialize(accessManager);
    }

    /// @dev initializer that will creaete its own accessManager internally
    /// IMPORTANT cloning and initialization needs to be done in a single transaction
    // QUESTION AccessAdmin (base class) has _disableInitializer() in constructor
    // ANSWER constructor is never called in cloned contract, therefore _disableInitializer is never called in cloned contract.
    //      How can child class use initialzier / onlyInitializing then?
    //      Quote: "Calling this (_disableInitializer) in the constructor of a contract will prevent that contract from being initialized or reinitialized"
    function initialize() public initializer() {
        AccessManager accessManager = new AccessManager(address(this));
        _initialize(address(accessManager));
    }

    function _initialize(address accessManager) internal {
        _initializeAuthority(address(accessManager));
        _initializeRoleSetup();

        // grant manger role to deployer
        _grantRoleToAccount(_managerRoleId, _deployer);
    }
}

contract AccessAdminTest is Test {

    address public accessAdminDeployer = makeAddr("accessAdminDeployer");
    address public accessAdminCloner = makeAddr("accessAdminCloner");
    address public outsider = makeAddr("outsider");
    address public outsider2 = makeAddr("outsider2");

    AccessAdminForTesting public accessAdmin;
    AccessAdminCloneable aaMaster;


    function setUp() public {
        vm.startPrank(accessAdminDeployer);
        accessAdmin = new AccessAdminForTesting(accessAdminDeployer);
        accessAdmin.createTarget(address(accessAdmin), "AccessAdmin");

        aaMaster = new AccessAdminCloneable(accessAdminDeployer);
        vm.stopPrank();
    }


    function test_accessAdminSetup() public {
        // GIVEN (just setup)
        // solhint-disable no-console
        console.log("accessAdminDeployer", accessAdminDeployer);
        console.log("access admin", address(accessAdmin));
        console.log("access admin authority", accessAdmin.authority());
        console.log("access admin deployer", accessAdmin.deployer());

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

        // some more checks on access admin
        _checkAccessAdmin(accessAdmin, accessAdminDeployer);
    }


    function test_accessAdminCreateTargetHappyCase() public {
        // GIVEN 

        string memory targetName = "AccessManagedMock";
        Str name = StrLib.toStr(targetName);
        AccessManagedMock accessManagedMock = new AccessManagedMock(accessAdmin.authority());

        assertEq(accessAdmin.targets(), 1, "unexpected number of initial targets");
        assertFalse(accessAdmin.targetExists(address(accessManagedMock)), "address(accessManagedMock) already exists as target");
        assertEq(accessAdmin.getTargetForName(name), address(0), "AccessAdmin -> non zero target");

        // WHEN
        vm.startPrank(accessAdminDeployer);
        accessAdmin.createTarget(address(accessManagedMock), targetName);
        vm.stopPrank();

        // THEN
        assertEq(accessAdmin.targets(), 2, "unexpected number of targets");
        assertTrue(accessAdmin.targetExists(address(accessManagedMock)), "address(accessManagedMock) doesn't exist as target");
        assertEq(accessAdmin.getTargetForName(name), address(accessManagedMock), "unexpected target address for name 'AccessManagedMock'");

        IAccessAdmin.TargetInfo memory info = accessAdmin.getTargetInfo(address(accessManagedMock));
        assertEq(info.name.toString(), targetName, "unexpected target name (info)");
        assertEq(info.createdAt.toInt(), TimestampLib.blockTimestamp().toInt(), "unexpected created at (info)");
    }

    function test_accessAdminCreateTargetInvalidParameters() public {
        // GIVEN 
        string memory targetName = "AccessAdmin";

        // WHEN + THEN

        // attempt to create accessAdmin target a 2nd time
        address accessAdminTarget = address(accessAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorTargetAlreadyCreated.selector, 
                accessAdminTarget,
                targetName));

        vm.startPrank(accessAdminDeployer);
        accessAdmin.createTarget(accessAdminTarget, "SomeTarget");
        vm.stopPrank();

        // attempt to create target that is not access managed
        address invalidTarget = makeAddr("invalidContract");
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorTargetNotAccessManaged.selector, 
                invalidTarget));

        vm.startPrank(accessAdminDeployer);
        accessAdmin.createTarget(invalidTarget, "SomeTarget");
        vm.stopPrank();

        // attempt to create target with empty name
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorTargetNameEmpty.selector, 
                address(this)));

        vm.startPrank(accessAdminDeployer);
        accessAdmin.createTarget(address(this), "");
        vm.stopPrank();

        // attempt to create target with existing name
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorTargetNameAlreadyExists.selector, 
                address(this),
                targetName,
                accessAdminTarget));

        vm.startPrank(accessAdminDeployer);
        accessAdmin.createTarget(address(this), "AccessAdmin");
        vm.stopPrank();
    }

    function test_accessAdminSetTargetLocked() public {
        // GIVEN (just setup)

        address accessAdminTarget = address(accessAdmin);
        assertFalse(accessAdmin.isTargetLocked(accessAdminTarget), "target is locked (before)");

        // WHEN
        vm.startPrank(accessAdminDeployer);
        accessAdmin.setTargetLocked(accessAdminTarget, true);
        vm.stopPrank();

        // THEN
        assertTrue(accessAdmin.isTargetLocked(accessAdminTarget), "target still not locked");

        // WHEN + THEN - attempt to unlock 
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessManaged.AccessManagedUnauthorized.selector, 
                accessAdminDeployer));

        vm.startPrank(accessAdminDeployer);
        // TODO - locked target is not callable -> why it is works?
        // because throws AccessManagedUnauthorized before it reaches locked check...
        // why "open" is not authorized if was able to close by the same account?
        accessAdmin.setTargetLocked(accessAdminTarget, false);
        vm.stopPrank();
    }

    function test_accessAdminCreateRoleHappyCase() public {

        // GIVEN (just setup)
        RoleId newRoleId = RoleIdLib.toRoleId(100);
        RoleId adminRoleId = accessAdmin.getManagerRole();
        string memory newRoleName = "NewRole";

        vm.startPrank(accessAdminDeployer);

        // WHEN
        accessAdmin.createRoleSimple(
            newRoleId, 
            adminRoleId, 
            newRoleName);

        vm.stopPrank();

        // THEN
        _checkRole(
            accessAdmin,
            newRoleId, 
            adminRoleId,
            newRoleName,
            TimestampLib.max(),
            TimestampLib.blockTimestamp());

        _checkRoleGranting(
            accessAdmin,
            newRoleId, 
            accessAdminDeployer,
            outsider,
            outsider2);
    }


    function test_accessAdminCreateRoleWithSingleMember() public {

        // GIVEN (just setup)
        RoleId newRoleId = RoleIdLib.toRoleId(100);
        RoleId adminRoleId = accessAdmin.getManagerRole();
        string memory newRoleName = "NewRole";

        vm.startPrank(accessAdminDeployer);

        // WHEN
        uint256 maxOneRoleMember = 1; // max 1 member allowed
        bool memberRemovalDisallowed = true;
        accessAdmin.createRole(
            newRoleId, 
            adminRoleId, 
            newRoleName,
            maxOneRoleMember, 
            memberRemovalDisallowed); // member removal disallowed

        vm.stopPrank();

        // THEN
        _checkRole(
            accessAdmin,
            newRoleId, 
            adminRoleId,
            newRoleName,
            maxOneRoleMember,
            memberRemovalDisallowed,
            TimestampLib.max(),
            TimestampLib.blockTimestamp());

        assertEq(accessAdmin.roleMembers(newRoleId), 0, "role members > 0 before granting role");
        assertFalse(accessAdmin.isRoleDisabled(newRoleId), "role disabled after creation");

        // WHEN - assign role 1st time
        address thisContract = address(this);
        vm.startPrank(accessAdminDeployer);
        accessAdmin.grantRole(thisContract, newRoleId);
        vm.stopPrank();

        // THEN
        assertEq(accessAdmin.roleMembers(newRoleId), 1, "unexpected role member count after granting");
        assertEq(accessAdmin.getRoleMember(newRoleId, 0), thisContract, "unexpected role member");

        // WHEN + THEN - attempt to add 2nd role member
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorRoleMembersLimitReached.selector, 
                newRoleId,
                maxOneRoleMember));

        vm.startPrank(accessAdminDeployer);
        accessAdmin.grantRole(outsider, newRoleId);
        vm.stopPrank();

        // WHEN + THEN - attempt to revoke role
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorRoleRemovalDisabled.selector, 
                newRoleId));

        vm.startPrank(accessAdminDeployer);
        accessAdmin.revokeRole(thisContract, newRoleId);
        vm.stopPrank();

        // WHEN + THEN - attempt to renounce role
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorRoleRemovalDisabled.selector, 
                newRoleId));

        vm.startPrank(thisContract);
        accessAdmin.renounceRole(newRoleId);
        vm.stopPrank();
    }

    function test_accessAdminCreateProtectedRoles() public {
        // GIVEN
        RoleId adminRole = accessAdmin.getAdminRole();
        RoleId publicRole = accessAdmin.getPublicRole();
        RoleId managerRole = accessAdmin.getManagerRole();
        string memory newName = "newRole";

        // WHEN + THEN - use existing protected role ids

        // attempt to recreate admin role
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorRoleAlreadyCreated.selector, 
                adminRole,
                "AdminRole"));

        vm.startPrank(accessAdminDeployer);
        accessAdmin.createRoleSimple(
            adminRole, 
            adminRole, 
            newName);

        // attempt to recreate public role
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorRoleAlreadyCreated.selector, 
                publicRole,
                "PublicRole"));

        vm.startPrank(accessAdminDeployer);
        accessAdmin.createRoleSimple(
            publicRole, 
            adminRole, 
            newName);

        // attempt to recreate manager role
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorRoleAlreadyCreated.selector, 
                managerRole,
                "ManagerRole"));

        vm.startPrank(accessAdminDeployer);
        accessAdmin.createRoleSimple(
            managerRole, 
            adminRole, 
            newName);

        vm.stopPrank();
    }


    function test_accessAdminCreateRoleTwice() public {
        // GIVEN
        RoleId newRoleId = RoleIdLib.toRoleId(100);
        RoleId adminRoleId = accessAdmin.getManagerRole();
        string memory newRoleName = "NewRole";

        vm.startPrank(accessAdminDeployer);
        accessAdmin.createRoleSimple(
            newRoleId, 
            adminRoleId, 
            newRoleName);
        vm.stopPrank();

        // WHEN + THEN - use existing role id
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorRoleAlreadyCreated.selector, 
                newRoleId,
                newRoleName));

        vm.startPrank(accessAdminDeployer);
        accessAdmin.createRoleSimple(
            newRoleId, 
            adminRoleId, 
            "SomeOtherRule");
        vm.stopPrank();

        // WHEN + THEN - use existing role name
        RoleId otherRoleId = RoleIdLib.toRoleId(123);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorRoleNameAlreadyExists.selector, 
                otherRoleId,
                newRoleName,
                newRoleId));

        vm.startPrank(accessAdminDeployer);
        accessAdmin.createRoleSimple(
            otherRoleId, 
            adminRoleId, 
            newRoleName);
        vm.stopPrank();
    }


    function test_accessAdminCreateEmptyNameMissingAdminRole() public {
        // GIVEN
        RoleId newRoleId = RoleIdLib.toRoleId(100);
        RoleId missingAdminRoleId = RoleIdLib.toRoleId(111);
        RoleId adminRoleId = accessAdmin.getManagerRole();
        string memory newRoleName = "NewRole";

        // WHEN + THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorRoleNameEmpty.selector, 
                newRoleId));

        vm.startPrank(accessAdminDeployer);
        accessAdmin.createRoleSimple(
            newRoleId, 
            adminRoleId, 
            "");
        vm.stopPrank();

        // WHEN + THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorRoleAdminNotExisting.selector, 
                missingAdminRoleId));

        vm.startPrank(accessAdminDeployer);
        accessAdmin.createRoleSimple(
            newRoleId, 
            missingAdminRoleId, 
            newRoleName);
        vm.stopPrank();
    }


    function test_accessAdminCreateRoleWithOwnAdminRoleHappyCase() public {
        // GIVEN

        address roleAdmin = makeAddr("roleAdmin");
        address account1 = makeAddr("account1");
        address account2 = makeAddr("account2");

        RoleId adminRoleId = accessAdmin.getManagerRole();
        RoleId newAdminRoleId = RoleIdLib.toRoleId(100);
        string memory newRoleAdminName = "NewRoleAdmin";

        RoleId newRoleId = RoleIdLib.toRoleId(101);
        string memory newRoleName = "NewRole";

        vm.startPrank(accessAdminDeployer);

        // WHEN

        // create admin role first
        accessAdmin.createRoleSimple(
            newAdminRoleId, 
            adminRoleId, 
            newRoleAdminName);

        // then create actual role
        accessAdmin.createRoleSimple(
            newRoleId, 
            newAdminRoleId, 
            newRoleName);

        // grant newly created role admin role to roleAdmin 
        accessAdmin.grantRole(roleAdmin, newAdminRoleId);

        vm.stopPrank();

        // THEN
        assertTrue(accessAdmin.hasRole(roleAdmin, newAdminRoleId), "roleAdmin not having new role admin role");

        _checkRole(
            accessAdmin,
            newAdminRoleId, 
            adminRoleId,
            newRoleAdminName,
            TimestampLib.max(),
            TimestampLib.blockTimestamp());

        // check granting of new role admin role
        _checkRoleGranting(
            accessAdmin,
            newAdminRoleId, 
            accessAdminDeployer,
            account1,
            account2);

        _checkRole(
            accessAdmin,
            newRoleId, 
            newAdminRoleId,
            newRoleName,
            TimestampLib.max(),
            TimestampLib.blockTimestamp());

        // check granting of new role (check that roleAdmin can grant/revoke new role)
        _checkRoleGranting(
            accessAdmin,
            newRoleId, 
            roleAdmin,
            account1,
            account2);
    }

    function test_accessAdminCreateRoleWithOwnAdminRole2HappyCase() public {
        // GIVEN

        RoleId adminRoleId = accessAdmin.getManagerRole();
        uint256 roleIdInt = 42;
        string memory roleNameBase = "test";
        address account1 = makeAddr("account1");
        address account2 = makeAddr("account2");

        // WHEN
        (
            RoleId newRoleId,
            RoleId newAdminRoleId,
            string memory newRoleName,
            string memory newAdminRoleName,
            address roleAdmin
        ) = _createManagedRoleWithOwnAdmin(
            roleIdInt, 
            roleNameBase);

        // THEN
        assertTrue(accessAdmin.hasRole(roleAdmin, newAdminRoleId), "roleAdmin not having new role admin role");

        _checkRole(
            accessAdmin,
            newAdminRoleId, 
            adminRoleId,
            newAdminRoleName,
            TimestampLib.max(),
            TimestampLib.blockTimestamp());

        // check granting of new role admin role
        _checkRoleGranting(
            accessAdmin,
            newAdminRoleId, 
            accessAdminDeployer,
            account1,
            account2);

        _checkRole(
            accessAdmin,
            newRoleId, 
            newAdminRoleId,
            newRoleName,
            TimestampLib.max(),
            TimestampLib.blockTimestamp());

        // check granting of new role (check that roleAdmin can grant/revoke new role)
        _checkRoleGranting(
            accessAdmin,
            newRoleId, 
            roleAdmin,
            account1,
            account2);
    }

    function test_accessAdminCreateRole2LevelAddingMissingAdminRole() public {
        // GIVEN

        RoleId adminRoleId = accessAdmin.getManagerRole();
        uint256 roleIdInt = 42;
        string memory roleNameBase = "test";
        address account1 = makeAddr("account1");
        address account2 = makeAddr("account2");

        (
            RoleId newRoleId,
            RoleId newAdminRoleId,
            string memory newRoleName,
            string memory newAdminRoleName,
            address roleAdmin
        ) = _createManagedRoleWithOwnAdmin(
            roleIdInt, 
            roleNameBase);

        assertFalse(accessAdmin.hasRole(account1, newRoleId), "account1 already has new role");
        assertTrue(accessAdmin.hasRole(roleAdmin, newAdminRoleId), "roleAdmin not having new role admin role");
        assertFalse(accessAdmin.hasRole(accessAdminDeployer, newAdminRoleId), "accessAdminDeployer having new role admin role");

        // WHEN + THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorNotAdminOfRole.selector, 
                newAdminRoleId));

        vm.startPrank(accessAdminDeployer);
        accessAdmin.grantRole(account1, newRoleId);
        vm.stopPrank();

        // WHEN
        vm.startPrank(accessAdminDeployer);
        accessAdmin.grantRole(accessAdminDeployer, newAdminRoleId);
        accessAdmin.grantRole(account1, newRoleId);
        vm.stopPrank();

        // THEN
        assertTrue(accessAdmin.hasRole(accessAdminDeployer, newAdminRoleId), "accessAdminDeployer missing new role admin role");
        assertTrue(accessAdmin.hasRole(account1, newRoleId), "account1 missing new role");
    }


    function test_accessAdminCreateRole2LevelRemovingAdminRole() public {
        // GIVEN

        RoleId adminRoleId = accessAdmin.getManagerRole();
        uint256 roleIdInt = 42;
        string memory roleNameBase = "test";
        address account1 = makeAddr("account1");
        address account2 = makeAddr("account2");

        (
            RoleId newRoleId,
            RoleId newAdminRoleId,
            string memory newRoleName,
            string memory newAdminRoleName,
            address roleAdmin
        ) = _createManagedRoleWithOwnAdmin(
            roleIdInt, 
            roleNameBase);

        assertFalse(accessAdmin.hasRole(account1, newRoleId), "account1 already has new role");
        assertTrue(accessAdmin.hasRole(roleAdmin, newAdminRoleId), "roleAdmin not having new role admin role");

        // WHEN
        vm.startPrank(accessAdminDeployer);
        accessAdmin.revokeRole(roleAdmin, newAdminRoleId);
        vm.stopPrank();

        // THEN
        assertFalse(accessAdmin.hasRole(roleAdmin, newAdminRoleId), "roleAdmin having new role admin role");

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorNotAdminOfRole.selector, 
                newAdminRoleId));

        vm.startPrank(roleAdmin);
        accessAdmin.grantRole(account1, newRoleId);
        vm.stopPrank();
    }


    function test_accessAdminCreateRole2LevelGrantAndRevokeToMultipleAccounts() public {
        // GIVEN

        RoleId adminRoleId = accessAdmin.getManagerRole();
        uint256 roleIdInt = 42;
        string memory roleNameBase = "test";
        address account1 = makeAddr("account1");
        address account2 = makeAddr("account2");
        address account3 = makeAddr("account3");

        (
            RoleId roleId,
            RoleId newAdminRoleId,
            string memory newRoleName,
            string memory newAdminRoleName,
            address roleAdmin
        ) = _createManagedRoleWithOwnAdmin(
            roleIdInt, 
            roleNameBase);

        assertEq(accessAdmin.roleMembers(roleId), 0);

        // WHEN
        vm.startPrank(roleAdmin);
        accessAdmin.grantRole(account1, roleId);
        accessAdmin.grantRole(account2, roleId);
        accessAdmin.grantRole(account3, roleId);
        vm.stopPrank();

        // THEN after 3 grants
        assertEq(accessAdmin.roleMembers(roleId), 3);
        assertEq(accessAdmin.getRoleMember(roleId, 0), account1, "1st member not account1");
        assertEq(accessAdmin.getRoleMember(roleId, 1), account2, "2nd member not account2");
        assertEq(accessAdmin.getRoleMember(roleId, 2), account3, "3rd member not account3");

        // WHEN
        vm.startPrank(roleAdmin);
        accessAdmin.revokeRole(account3, roleId);
        vm.stopPrank();

        // THEN after 1st revoke
        assertEq(accessAdmin.roleMembers(roleId), 2);
        assertEq(accessAdmin.getRoleMember(roleId, 0), account1, "1st member not account1 (remove 1)");
        assertEq(accessAdmin.getRoleMember(roleId, 1), account2, "2nd member not account2 (remove 1)");

        // WHEN
        vm.startPrank(roleAdmin);
        accessAdmin.revokeRole(account1, roleId);
        vm.stopPrank();

        // THEN after 2nd remove
        assertEq(accessAdmin.roleMembers(roleId), 1);
        assertEq(accessAdmin.getRoleMember(roleId, 0), account2, "1st member not account2 (remove 1)");
    }


    function test_accessAdminCreateRole2LevelGrantRevokeRoleMultipleTimes() public {
        // GIVEN

        RoleId adminRoleId = accessAdmin.getManagerRole();
        uint256 roleIdInt = 42;
        string memory roleNameBase = "test";
        address account1 = makeAddr("account1");
        address account2 = makeAddr("account2");

        (
            RoleId newRoleId,
            RoleId newAdminRoleId,
            string memory newRoleName,
            string memory newAdminRoleName,
            address roleAdmin
        ) = _createManagedRoleWithOwnAdmin(
            roleIdInt, 
            roleNameBase);

        assertFalse(accessAdmin.hasRole(account1, newRoleId), "account1 already has new role");
        assertTrue(accessAdmin.hasRole(roleAdmin, newAdminRoleId), "roleAdmin not having new role admin role");

        // WHEN + THEN add multiple times
        vm.startPrank(roleAdmin);
        assertEq(accessAdmin.roleMembers(newRoleId), 0);

        accessAdmin.grantRole(account1, newRoleId);
        assertEq(accessAdmin.roleMembers(newRoleId), 1);

        accessAdmin.grantRole(account2, newRoleId);
        assertEq(accessAdmin.roleMembers(newRoleId), 2);

        assertTrue(accessAdmin.hasRole(account1, newRoleId), "account1 doesn't have new role");

        // grant new role 2nd time to account 1
        accessAdmin.grantRole(account1, newRoleId);
        assertEq(accessAdmin.roleMembers(newRoleId), 2);
        assertTrue(accessAdmin.hasRole(account1, newRoleId), "account1 doesn't have new role");

        accessAdmin.revokeRole(account1, newRoleId);
        assertEq(accessAdmin.roleMembers(newRoleId), 1);
        assertFalse(accessAdmin.hasRole(account1, newRoleId), "account1 still has new role");

        // revoke new role 2nd time from account 1
        accessAdmin.revokeRole(account1, newRoleId);

        assertEq(accessAdmin.roleMembers(newRoleId), 1);
        assertFalse(accessAdmin.hasRole(account1, newRoleId), "account1 still has new role");
        vm.stopPrank();

        vm.startPrank(account1);

        // remove role account1 no longer has
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorNotRoleOwner.selector,
                newRoleId));

        accessAdmin.renounceRole(newRoleId);

        assertEq(accessAdmin.roleMembers(newRoleId), 1);
        assertFalse(accessAdmin.hasRole(account1, newRoleId), "account1 still has new role");
        vm.stopPrank();

        vm.startPrank(account2);
        assertTrue(accessAdmin.hasRole(account2, newRoleId), "account2 doesn't have new role");

        // renouncing 1st time has effect
        accessAdmin.renounceRole(newRoleId);
        assertEq(accessAdmin.roleMembers(newRoleId), 0);
        assertFalse(accessAdmin.hasRole(account2, newRoleId), "account2 still has new role");

        // remove role account2 no longer has
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorNotRoleOwner.selector,
                newRoleId));

        accessAdmin.renounceRole(newRoleId);

        assertEq(accessAdmin.roleMembers(newRoleId), 0);
        assertFalse(accessAdmin.hasRole(account2, newRoleId), "account2 still has new role");
        vm.stopPrank();
    }


    function test_accessAdminCreateRoleUnauthorized() public {
        // GIVEN (just setup)
        RoleId newRoleId = RoleIdLib.toRoleId(100);
        RoleId adminRoleId = accessAdmin.getAdminRole();
        string memory newRoleName = "NewRole";

        vm.startPrank(outsider);

        // WHEN + THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessManaged.AccessManagedUnauthorized.selector,
                outsider));

        accessAdmin.createRoleSimple(
            newRoleId, 
            adminRoleId, 
            newRoleName);

        vm.stopPrank();
    }


    function test_accessAdminSetRoleDisabledHappyCase() public {

        // GIVEN - setup
        RoleId newRoleId = RoleIdLib.toRoleId(100);
        RoleId newRoleAdminRoleId = accessAdmin.getManagerRole();
        string memory newRoleName = "NewRole";

        // WHEN
        vm.startPrank(accessAdminDeployer);
        accessAdmin.createRoleSimple(
            newRoleId, 
            newRoleAdminRoleId, 
            newRoleName);

        accessAdmin.grantRole(outsider, newRoleId);
        vm.stopPrank();

        // THEN
        assertTrue(accessAdmin.roleExists(newRoleId), "my role doesn't exist");
        assertFalse(accessAdmin.isRoleDisabled(newRoleId), "my role disabled");
        assertTrue(accessAdmin.hasRole(outsider, newRoleId), "outsider without my role");
        assertFalse(accessAdmin.hasRole(outsider2, newRoleId), "outsider2 without my role");

        // WHEN - disable new role
        bool disabled = true;
        vm.startPrank(accessAdminDeployer);
        accessAdmin.setRoleDisabled(newRoleId, disabled);
        vm.stopPrank();

        // THEN
        assertTrue(accessAdmin.roleExists(newRoleId), "my role doesn't exist (after disable)");
        assertTrue(accessAdmin.isRoleDisabled(newRoleId), "my role isn't disabled (after disable)");

        // WHEN + THEN 
        vm.startPrank(accessAdminDeployer);

        // attempt to grant disabled role must revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorRoleIsDisabled.selector,
                newRoleId));

        accessAdmin.grantRole(outsider2, newRoleId);

        // revoking diabled roles must not revert
        accessAdmin.revokeRole(outsider, newRoleId);
        vm.stopPrank();

        assertFalse(accessAdmin.hasRole(outsider, newRoleId), "outsider has my role (after revoke)");
        assertFalse(accessAdmin.hasRole(outsider2, newRoleId), "outsider2 has my role (after revoke)");

        // WHEN - enable new role again
        disabled = false;
        vm.startPrank(accessAdminDeployer);
        accessAdmin.setRoleDisabled(newRoleId, disabled);

        // granting role must again work and not revert
        accessAdmin.grantRole(outsider2, newRoleId);
        vm.stopPrank();

        // THEN
        assertTrue(accessAdmin.roleExists(newRoleId), "my role doesn't exist (after re-enable)");
        assertFalse(accessAdmin.isRoleDisabled(newRoleId), "my role is disabled (after re-enable)");
        assertFalse(accessAdmin.hasRole(outsider, newRoleId), "outsider has my role (after re-enable)");
        assertTrue(accessAdmin.hasRole(outsider2, newRoleId), "outsider2 without my role (after re-enable)");
    }


    function test_accessAdminGrantRevokeNonexistentRole() public {

        // GIVEN - setup
        RoleId adminRoleId = accessAdmin.getAdminRole();
        RoleId missingRoleId = RoleIdLib.toRoleId(404);

        // WHEN + THEN grant/revoke
        vm.startPrank(accessAdminDeployer);

        // granting non existent role -> role unknown
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorRoleUnknown.selector,
                missingRoleId));

        accessAdmin.grantRole(outsider, missingRoleId);

        // revoking non existent role -> role unknown
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorRoleUnknown.selector,
                missingRoleId));

        accessAdmin.revokeRole(outsider, missingRoleId);
        vm.stopPrank();

        vm.startPrank(outsider);

        // WHEN + THEN - renounce
        // renouncing non existent role -> role unknown
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorNotRoleOwner.selector,
                missingRoleId));

        accessAdmin.renounceRole(missingRoleId);
        vm.stopPrank();
    }


    function test_accessAdminGrantRevokeRenounceLockedRoles() public {
        // GIVEN (just setup)
        RoleId adminRole = accessAdmin.getAdminRole();
        RoleId publicRole = accessAdmin.getPublicRole();
        RoleId managerRole = accessAdmin.getManagerRole();

        // admin role
        vm.startPrank(address(accessAdmin));

        // attempt to grant admin role
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorRoleIsLocked.selector,
                adminRole));

        accessAdmin.grantRole(outsider, adminRole);

        // attempt to revoke admin role
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorRoleIsLocked.selector,
                adminRole));

        accessAdmin.revokeRole(outsider, adminRole);

        // attempt to renounce admin role
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorRoleIsLocked.selector,
                adminRole));

        accessAdmin.renounceRole(adminRole);

        // public role
        vm.startPrank(address(accessAdmin));

        // attempt to grant admin role
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorRoleIsLocked.selector,
                publicRole));

        accessAdmin.grantRole(outsider, publicRole);

        // attempt to revoke admin role
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorRoleIsLocked.selector,
                publicRole));

        accessAdmin.revokeRole(outsider, publicRole);

        // attempt to renounce admin role
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorRoleIsLocked.selector,
                publicRole));

        accessAdmin.renounceRole(publicRole);

        vm.stopPrank();
    }


    /// @dev test creating a new access admin via constructor
    function test_accessAdminConstructorHappyCase() public {
        // GIVEN (just setup)
        // WHEN
        vm.startPrank(accessAdminDeployer);
        AccessAdminForTesting aat = new AccessAdminForTesting(accessAdminDeployer);
        vm.stopPrank();

        // THEN
        _checkAccessAdmin(aat, accessAdminDeployer);
    }


    /// @dev test creating a new access admin via cloning a deployed access admin and initilizing the clone
    function test_accessAdminClonedHappyCase() public {
        // GIVEN (just setup)
        vm.startPrank(accessAdminCloner);

        // WHEN
        // create cloned access manager
        AccessAdminCloneable aa = AccessAdminCloneable(
            Clones.clone(
                address(aaMaster)));

        // initialize aa with newly created access manager
        aa.initialize();
        vm.stopPrank();

        // THEN
        _checkAccessAdmin(aa, accessAdminCloner);
    }


    /// @dev test that a access admin created via constructor cannot be initialized
    function test_accessAdminClonedFailingToInitializeMaster() public {
        // GIVEN (just setup)
        vm.startPrank(accessAdminDeployer);

        // WHEN + 
        // create access manager with aa as admin
        AccessManager am = AccessManager(address(aaMaster));

        // THEN
        // initialize aa with newly created access manager
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        aaMaster.initializeWithAccessManager(address(am));
        vm.stopPrank();
    }


    /// @dev test that a cloned access admin can only be initialized once
    function test_accessAdminClonedFailingToInitializeTwice1stVersion() public {
        // GIVEN
        vm.startPrank(accessAdminCloner);

        // create cloned access manager
        AccessAdminCloneable aa = AccessAdminCloneable(
            Clones.clone(
                address(aaMaster)));
        
        // initialize aa with newly created access manager
        aa.initialize();

        // WHEN + THEN
        // attempt to initialize 2nd time
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        aa.initialize();

        vm.stopPrank();
    }


    /// @dev test that a cloned access admin can only be initialized once
    function test_accessAdminClonedFailingToInitializeTwice2NdVersion() public {
        // GIVEN
        vm.startPrank(accessAdminCloner);

        // create cloned access manager
        AccessAdminCloneable aa = AccessAdminCloneable(
            Clones.clone(
                address(aaMaster)));
        
        // create access manager with aa as admin
        AccessManager am = new AccessManager(address(aa));

        // initialize aa with newly created access manager
        aa.initializeWithAccessManager(address(am));

        // WHEN + THEN
        // attempt to initialize 2nd time
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        aa.initializeWithAccessManager(address(am));

        vm.stopPrank();
    }

    /// @dev check that initializing a cloned access admin reverts
    /// when trying to provide an access manager that does not have
    /// the access admin as initial owner
    function test_accessAdminClonedAdminMismatch() public {
        // GIVEN
        vm.startPrank(accessAdminCloner);

        // create cloned access manager
        AccessAdminCloneable aa = AccessAdminCloneable(
            Clones.clone(
                address(aaMaster)));

        // create access manager with outsider as admin
        AccessManager am = new AccessManager(outsider);

        // WHEN + THEN
        // attempt to initialize with unsuitable access manager
        vm.expectRevert(IAccessAdmin.ErrorAdminRoleMissing.selector);
        aa.initializeWithAccessManager(address(am));

        vm.stopPrank();
    }

    function _createManagedRoleWithOwnAdmin(
        uint256 roleIdInt, 
        string memory roleNameBase
    )
        internal
        returns (
            RoleId newRoleId,
            RoleId newAdminRoleId,
            string memory newRoleName,
            string memory newAdminRoleName,
            address roleAdmin
        )
    {
        newRoleId = RoleIdLib.toRoleId(roleIdInt);
        newRoleName = string(abi.encodePacked(roleNameBase, "Role"));

        newAdminRoleId = RoleIdLib.toRoleId(roleIdInt + 1);
        newAdminRoleName = string(abi.encodePacked(roleNameBase, "AdminRole"));
        roleAdmin = makeAddr(string(abi.encodePacked(roleNameBase, "RoleAdmin")));

        RoleId adminRoleId = accessAdmin.getManagerRole();

        vm.startPrank(accessAdminDeployer);

        // create admin role first
        accessAdmin.createRoleSimple(
            newAdminRoleId, 
            adminRoleId, 
            newAdminRoleName);

        // then create actual role
        accessAdmin.createRoleSimple(
            newRoleId, 
            newAdminRoleId, 
            newRoleName);

        // grant newly created role admin role to roleAdmin 
        accessAdmin.grantRole(roleAdmin, newAdminRoleId);
    }

    function _checkRoleGranting(
        AccessAdmin aa, 
        RoleId roleId, 
        address roleAdmin,
        address account1,
        address account2
    )
        internal
    {
        // GIVEN
        RoleId adminRoleId = aa.getRoleInfo(roleId).adminRoleId;
        assertFalse(aa.hasRole(account1, roleId), "account1 already has role");
        assertFalse(aa.hasRole(account1, adminRoleId), "account1 is role admin");
        assertTrue(aa.hasRole(roleAdmin, adminRoleId), "role admin is not role admin");

        // WHEN - grant role
        vm.startPrank(roleAdmin);
        aa.grantRole(account1, roleId);
        aa.grantRole(account2, roleId);
        vm.stopPrank();

        // THEN (grant)
        assertTrue(aa.hasRole(account1, roleId), "outsider has not been granted role");
        assertTrue(aa.hasRole(account2, roleId), "outsider2 has not been granted role");
        assertFalse(aa.hasRole(account1, adminRoleId), "outsider is role admin");
        assertFalse(aa.hasRole(account2, adminRoleId), "outsider2 is role admin");

        // WHEN - revoke role
        vm.startPrank(roleAdmin);
        aa.revokeRole(account1, roleId);
        vm.stopPrank();

        // THEN (revoke)
        assertFalse(aa.hasRole(account1, roleId), "outsider still has role");
        assertFalse(aa.hasRole(account1, adminRoleId), "outsider is role admin");

        // WHEN - renounce role
        vm.startPrank(account2);
        aa.renounceRole(roleId);
        vm.stopPrank();

        // THEN (renounce)
        assertFalse(aa.hasRole(account2, roleId), "outsider2 still has role");
        assertFalse(aa.hasRole(account2, adminRoleId), "outsider2 is role admin");
    }


    function _checkAccessAdmin(
        AccessAdmin aa, 
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
            1, // only one admin ! (aa contract is sole admin role member)
            true, // no removal of only admin
            TimestampLib.max(), 
            TimestampLib.blockTimestamp());

        // check public role
        _checkRole(
            aa,
            aa.getPublicRole(), 
            aa.getAdminRole(),
            aa.PUBLIC_ROLE_NAME(),
            type(uint256).max, // every account is public role member
            true, // role membership cannot be removed
            TimestampLib.max(), 
            TimestampLib.blockTimestamp());

        // check manager role
        _checkRole(
            aa,
            aa.getManagerRole(), 
            aa.getAdminRole(),
            aa.MANAGER_ROLE_NAME(),
            3,
            false, // manager role may be removed
            TimestampLib.max(), 
            TimestampLib.blockTimestamp());

        // check non existent role
        RoleId missingRoleId = RoleIdLib.toRoleId(1313);
        assertFalse(aa.roleExists(missingRoleId), "missing role exists"); 
        assertTrue(aa.isRoleDisabled(missingRoleId), "missing role active");

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
        _checkRole(
            aa, 
            roleId, 
            expectedAdminRoleId, 
            expectedName, 
            type(uint256).max, 
            false, 
            expectedDisabledAt, 
            expectedCreatedAt);
    }

    function _checkRole(
        IAccessAdmin aa,
        RoleId roleId, 
        RoleId expectedAdminRoleId,
        string memory expectedName,
        uint256 expectedMaxMemberCount,
        bool expectedMemberRemovalDisabled,
        Timestamp expectedDisabledAt,
        Timestamp expectedCreatedAt
    )
        internal
    {
        // solhint-disable-next-line
        console.log("checking role", expectedName);

        assertTrue(aa.roleExists(roleId), "role does not exist");
        assertEq(aa.getRoleForName(StrLib.toStr(expectedName)).roleId.toInt(), roleId.toInt(), "unexpected roleId for getRoleForName");

        IAccessAdmin.RoleInfo memory info = aa.getRoleInfo(roleId);
        assertEq(info.adminRoleId.toInt(), expectedAdminRoleId.toInt(), "unexpected admin role (role info)");
        assertEq(info.name.toString(), expectedName, "unexpected role name");
        assertEq(info.maxMemberCount, expectedMaxMemberCount, "unexpected maxMemberCount");
        assertEq(info.memberRemovalDisabled, expectedMemberRemovalDisabled, "unexpected memberRemovalDisabled");
        assertEq(info.disabledAt.toInt(), expectedDisabledAt.toInt(), "unexpected disabled at");
        assertTrue(info.exists, "role does not exist");

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

    function _printTarget(AccessAdmin aa, address target) internal view {
        IAccessAdmin.TargetInfo memory info = aa.getTargetInfo(target);

        // solhint-disable no-console
        uint256 functions = aa.authorizedFunctions(target);
        console.log("target", info.name.toString(), "address", target);
        console.log("authorized functions", functions);
        for(uint256 i = 0; i < functions; i++) {
            (
                IAccessAdmin.Function memory func,
                RoleId roleId
            ) = aa.getAuthorizedFunction(target, i);
            string memory role = aa.getRoleInfo(roleId).name.toString();

            console.log("-", i, string(abi.encodePacked(func.name.toString(), "(): ", role,":")), roleId.toInt());
        }
        // solhint-enable
    }

}