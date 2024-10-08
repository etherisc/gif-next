// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {Test, console} from "../../lib/forge-std/src/Test.sol";

import {IAccess} from "../../contracts/authorization/IAccess.sol";
import {IAccessAdmin} from "../../contracts/authorization/IAccessAdmin.sol";

import {AccessAdmin} from "../../contracts/authorization/AccessAdmin.sol";
import {AccessAdminLib} from "../../contracts/authorization/AccessAdminLib.sol";
import {AccessManagerCloneable} from "../../contracts/authorization/AccessManagerCloneable.sol";
import {AccessManagedMock} from "../mock/AccessManagedMock.sol";
import {Blocknumber, BlocknumberLib} from ".../../contracts/type/Blocknumber.sol";
import {RegistryAdmin} from "../../contracts/registry/RegistryAdmin.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {RoleId, RoleIdLib} from "../../contracts/type/RoleId.sol";
import {Selector, SelectorLib} from "../../contracts/type/Selector.sol";
import {Str, StrLib} from "../../contracts/type/String.sol";
import {Timestamp, TimestampLib} from "../../contracts/type/Timestamp.sol";
import {VersionPart, VersionPartLib} from "../../contracts/type/Version.sol";


contract AccessAdminForTesting is AccessAdmin {

    uint64 public constant MANAGER_ROLE = type(uint64).min + 1;
    string public constant MANAGER_ROLE_NAME = "ManagerRole";

    /// @dev required role for state changes to this contract
    RoleId internal _managerRoleId;

    // constructor as in registry admin
    constructor() {
        initialize(
            address(new AccessManagerCloneable()),
            "TestAdmin");
    }

    function completeSetup(
        address registry,
        VersionPart release
    )
        public
        reinitializer(type(uint8).max)
    {
        // we assume that this function is called by the deployer
        // this can be enforced when the contract is created and the setup is completed in a single tx.
        address deployer = msg.sender;

        // link access manager to registry and release
        AccessManagerCloneable(authority()).completeSetup(
            registry, 
            release);

        // create targets for testing
        _createTarget(address(this), "AccessAdmin", IAccess.TargetType.Core, false);

        // setup manager role
        _managerRoleId = RoleIdLib.toRoleId(MANAGER_ROLE);
        _createRole(
            _managerRoleId, 
            AccessAdminLib.roleInfo(
                getAdminRole(),
                TargetType.Custom,
                3, // max accounts with this role
                MANAGER_ROLE_NAME),
            true); 

        // grant public role access to grant and revoke, renounce
        FunctionInfo[] memory functions;
        functions = new FunctionInfo[](4);
        functions[0] = AccessAdminLib.toFunction(AccessAdminForTesting.grantManagerRole.selector, "grantManagerRole");
        functions[1] = AccessAdminLib.toFunction(AccessAdminForTesting.grantRole.selector, "grantRole");
        functions[2] = AccessAdminLib.toFunction(AccessAdminForTesting.revokeRole.selector, "revokeRole");
        functions[3] = AccessAdminLib.toFunction(AccessAdminForTesting.renounceRole.selector, "renounceRole");
        _authorizeTargetFunctions(address(this), getPublicRole(), functions, false, true);

        // grant manager role access to the specified functions 
        functions = new FunctionInfo[](7);
        functions[0] = AccessAdminLib.toFunction(AccessAdminForTesting.createRole.selector, "createRole");
        functions[1] = AccessAdminLib.toFunction(AccessAdminForTesting.createRoleExtended.selector, "createRoleExtended");
        functions[2] = AccessAdminLib.toFunction(AccessAdminForTesting.setRoleActive.selector, "setRoleActive");
        functions[3] = AccessAdminLib.toFunction(AccessAdminForTesting.createTarget.selector, "createTarget");
        functions[4] = AccessAdminLib.toFunction(AccessAdminForTesting.setTargetLocked.selector, "setTargetLocked");
        functions[5] = AccessAdminLib.toFunction(AccessAdminForTesting.authorizeFunctions.selector, "authorizeFunctions");
        functions[6] = AccessAdminLib.toFunction(AccessAdminForTesting.unauthorizeFunctions.selector, "unauthorizeFunctions");
        _authorizeTargetFunctions(address(this), getManagerRole(), functions, false, true);

        _grantRoleToAccount(_managerRoleId, deployer);
    }

    //--- role management functions -----------------------------------------//

    function grantManagerRole(address account)
        external
        restricted()
    {
        _grantRoleToAccount(_managerRoleId, account);
    }

    function createRole(
        RoleId roleId, 
        RoleId adminRoleId, 
        string memory name
    )
        external
        restricted()
    {
        // check role does not yet exist
        if (roleExists(roleId)) {
            revert IAccessAdmin.ErrorAccessAdminRoleAlreadyCreated(
                roleId,
                getRoleInfo(roleId).name.toString());
        }

        (RoleId existingRoleId, bool exists) = getRoleForName(name);
        if (exists) {
            revert IAccessAdmin.ErrorAccessAdminRoleNameAlreadyExists(
                roleId,
                name,
                existingRoleId);
        }

        _createRole(
            roleId,
            AccessAdminLib.roleInfo(
                adminRoleId, 
                TargetType.Custom, 
                type(uint32).max, 
                name),
            true);
    }

    function createRoleExtended(
        RoleId roleId, 
        RoleId adminRoleId, 
        TargetType targetType,
        string memory name, 
        uint32 maxOneRoleMember
    )
        external
        restricted()
    {
        _createRole(
            roleId, 
            AccessAdminLib.roleInfo(
                adminRoleId, 
                targetType, 
                maxOneRoleMember, 
                name),
            true);
    }


    function setRoleActive(
        RoleId roleId, 
        bool active
    )
        external
        restricted()
    {
        _setRoleActive(roleId, active);
    }


    function grantRole(
        address account, 
        RoleId roleId
    )
        external
        virtual
        restricted()
    {
        _grantRoleToAccount(roleId, account);
    }

    function revokeRole(
        address account, 
        RoleId roleId
    )
        external
        virtual
        restricted()
    {
        _revokeRoleFromAccount(roleId, account);
    }

    function renounceRole(
        RoleId roleId
    )
        external
        virtual
        restricted()
    {
        _revokeRoleFromAccount(roleId, msg.sender);
    }

    //--- target management functions ---------------------------------------//

    function createTarget(
        address target, 
        string memory name
    )
        external
        virtual
        restricted()
    {
        _createTarget(target, name, IAccess.TargetType.Custom, true);
    }

    function authorizeFunctions(
        address target, 
        RoleId roleId, 
        FunctionInfo[] memory functions
    )
        external
        virtual
        restricted()
    {
        _authorizeTargetFunctions(target, roleId, functions, false, true);
    }

    function unauthorizeFunctions(
        address target, 
        FunctionInfo[] memory functions
    )
        external
        virtual
        restricted()
    {
        _authorizeTargetFunctions(target, getAdminRole(), functions, false, false);
    }


    function setTargetLocked(
        address target, 
        bool locked
    )
        external
        virtual
        // restricted() - must not have this 
    {
        _setTargetLocked(target, locked);
    }

    function getManagerRole() public view returns (RoleId roleId) {
        return _managerRoleId;
    }

}

contract AccessAdminBaseTest is Test {

    address public accessAdminDeployer = makeAddr("accessAdminDeployer");
    address public globalRegistry = makeAddr("globalRegistry");
    address public admin = makeAddr("admin");
    address public outsider = makeAddr("outsider");
    address public outsider2 = makeAddr("outsider2");

    RegistryAdmin public registryAdmin;
    Registry public registry;
    VersionPart public release;
    AccessManagerCloneable public accessManager;
    AccessAdminForTesting public accessAdmin;

    AccessManagedMock public accessManaged;


    function setUp() public virtual {

        vm.startPrank(accessAdminDeployer);

        // create access admin for testing
        accessAdmin = new AccessAdminForTesting();

        // create registry and release version
        registryAdmin = new RegistryAdmin();
        registry = new Registry(registryAdmin, globalRegistry);
        release = VersionPartLib.toVersionPart(3);

        // complete setup (which links internal acccess manager to registry and release)
        // and grants manager role to deployer
        accessAdmin.completeSetup(
            address(registry), 
            release);

        vm.stopPrank();
    }
}


contract AccessAdminTest is AccessAdminBaseTest {


    function test_accessAdminSetup() public {
        // GIVEN (just setup)
        // solhint-disable no-console
        console.log("accessAdminDeployer", accessAdminDeployer);
        console.log("access admin", address(accessAdmin));
        console.log("access admin authority", accessAdmin.authority());

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
        assertTrue(accessAdmin.isRoleMember(adminRole, address(accessAdmin)), "access admin contract does not have admin role");
        assertFalse(accessAdmin.isRoleMember(adminRole, accessAdminDeployer), "access admin deployer does have admin role");

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
        assertEq(info.createdAt.toInt(), TimestampLib.current().toInt(), "unexpected created at (info)");
    }

    function test_accessAdminCreateTargetInvalidParameters() public {
        // GIVEN 
        string memory targetName = "AccessAdmin";

        // WHEN + THEN

        // attempt to create accessAdmin target a 2nd time
        address accessAdminTarget = address(accessAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorAccessAdminTargetAlreadyCreated.selector, 
                accessAdminTarget,
                targetName));

        vm.startPrank(accessAdminDeployer);
        accessAdmin.createTarget(accessAdminTarget, "SomeTarget");
        vm.stopPrank();

        // attempt to create target that is not access managed
        address invalidTarget = makeAddr("invalidContract");
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorAccessAdminTargetNotAccessManaged.selector, 
                invalidTarget));

        vm.startPrank(accessAdminDeployer);
        accessAdmin.createTarget(invalidTarget, "SomeTarget");
        vm.stopPrank();

        // attempt to create target with empty name
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorAccessAdminTargetNameEmpty.selector, 
                address(this)));

        vm.startPrank(accessAdminDeployer);
        accessAdmin.createTarget(address(this), "");
        vm.stopPrank();

        // attempt to create target with existing name
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorAccessAdminTargetNameAlreadyExists.selector, 
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

        vm.roll(2001);

        // WHEN
        vm.startPrank(accessAdminDeployer);
        accessAdmin.setTargetLocked(accessAdminTarget, true);
        vm.stopPrank();

        vm.roll(2002);

        // THEN
        assertTrue(accessAdmin.isTargetLocked(accessAdminTarget), "target still not locked");

        // attempt to deactivate role while access admin is locked 
        RoleId managerRoleId = accessAdmin.getManagerRole();
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessManaged.AccessManagedUnauthorized.selector, 
                accessAdminDeployer));

        vm.prank(accessAdminDeployer);
        accessAdmin.setRoleActive(managerRoleId, false);

        // WHEN set acces
        vm.prank(accessAdminDeployer);
        accessAdmin.setTargetLocked(accessAdminTarget, false);

        // 2nd attempt to deactivate role, must go through now
        vm.prank(accessAdminDeployer);
        accessAdmin.setRoleActive(managerRoleId, false);

        // assertTrue(false, "oops");
    }

    function test_accessAdminCreateRoleHappyCase() public {

        // GIVEN (just setup)
        RoleId newRoleId = RoleIdLib.toRoleId(123456789);
        RoleId adminRoleId = accessAdmin.getManagerRole();
        string memory newRoleName = "NewRole";

        vm.startPrank(accessAdminDeployer);

        // WHEN
        accessAdmin.createRole(
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
            TimestampLib.current());

        _checkRoleGranting(
            accessAdmin,
            newRoleId, 
            accessAdminDeployer,
            outsider,
            outsider2);
    }


    function test_accessAdminCreateRoleWithSingleMember() public {

        // GIVEN (just setup)
        RoleId newRoleId = RoleIdLib.toRoleId(123456789);
        RoleId adminRoleId = accessAdmin.getManagerRole();
        // check that deployer has admin role
        assertTrue(accessAdmin.isRoleMember(adminRoleId, accessAdminDeployer), "deployer does not have admin role");

        string memory newRoleName = "NewRole";

        // WHEN
        uint32 maxOneRoleMember = 1; // max 1 member allowed
        vm.prank(accessAdminDeployer);
        accessAdmin.createRoleExtended(
            newRoleId, 
            adminRoleId, 
            IAccess.TargetType.Contract,
            newRoleName,
            maxOneRoleMember); 

        // THEN
        _checkRole(
            accessAdmin,
            newRoleId, 
            adminRoleId,
            newRoleName,
            maxOneRoleMember,
            TimestampLib.current());

        assertEq(accessAdmin.roleMembers(newRoleId), 0, "role members > 0 before granting role");

        // WHEN - assign role 1st time
        address thisContract = address(this);
        vm.prank(accessAdminDeployer);
        accessAdmin.grantRole(thisContract, newRoleId);

        // THEN
        assertEq(accessAdmin.roleMembers(newRoleId), 1, "unexpected role member count after granting");
        assertEq(accessAdmin.getRoleMember(newRoleId, 0), thisContract, "unexpected role member");

        // WHEN + THEN - attempt to add 2nd role member
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorAccessAdminRoleMembersLimitReached.selector, 
                newRoleId,
                maxOneRoleMember));

        vm.prank(accessAdminDeployer);
        accessAdmin.grantRole(outsider, newRoleId);

        // WHEN + THEN - attempt to revoke role
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorAccessAdminRoleMemberRemovalDisabled.selector, 
                newRoleId,
                thisContract));

        vm.prank(accessAdminDeployer);
        accessAdmin.revokeRole(thisContract, newRoleId);

        // WHEN + THEN - attempt to renounce role
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorAccessAdminRoleMemberRemovalDisabled.selector, 
                newRoleId,
                thisContract));

        vm.prank(thisContract);
        accessAdmin.renounceRole(newRoleId);
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
                IAccessAdmin.ErrorAccessAdminRoleAlreadyCreated.selector, 
                adminRole,
                "AdminRole"));

        vm.startPrank(accessAdminDeployer);
        accessAdmin.createRole(
            adminRole, 
            adminRole, 
            newName);

        // attempt to recreate public role
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorAccessAdminRoleAlreadyCreated.selector, 
                publicRole,
                "PublicRole"));

        vm.startPrank(accessAdminDeployer);
        accessAdmin.createRole(
            publicRole, 
            adminRole, 
            newName);

        // attempt to recreate manager role
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorAccessAdminRoleAlreadyCreated.selector, 
                managerRole,
                "ManagerRole"));

        vm.startPrank(accessAdminDeployer);
        accessAdmin.createRole(
            managerRole, 
            adminRole, 
            newName);

        vm.stopPrank();
    }


    function test_accessAdminCreateRoleTwice() public {
        // GIVEN
        RoleId newRoleId = RoleIdLib.toRoleId(123456789);
        RoleId adminRoleId = accessAdmin.getManagerRole();
        string memory newRoleName = "NewRole";

        vm.startPrank(accessAdminDeployer);
        accessAdmin.createRole(
            newRoleId, 
            adminRoleId, 
            newRoleName);
        vm.stopPrank();

        // WHEN + THEN - use existing role id with differnt name
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorAccessAdminRoleAlreadyCreated.selector, 
                newRoleId,
                newRoleName));

        vm.startPrank(accessAdminDeployer);
        accessAdmin.createRole(
            newRoleId, 
            adminRoleId, 
            "SomeOtherRole");
        vm.stopPrank();

        // WHEN + THEN - use existing role name with different role id
        RoleId otherRoleId = RoleIdLib.toRoleId(123);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorAccessAdminRoleNameAlreadyExists.selector, 
                otherRoleId,
                newRoleName,
                newRoleId));

        vm.startPrank(accessAdminDeployer);
        accessAdmin.createRole(
            otherRoleId, 
            adminRoleId, 
            newRoleName);
        vm.stopPrank();
    }


    function test_accessAdminCreateEmptyNameMissingAdminRole() public {
        // GIVEN
        RoleId newRoleId = RoleIdLib.toRoleId(123456789);
        RoleId missingAdminRoleId = RoleIdLib.toRoleId(111);
        RoleId adminRoleId = accessAdmin.getManagerRole();
        string memory newRoleName = "NewRole";

        // WHEN + THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorAccessAdminRoleNameEmpty.selector, 
                newRoleId));

        vm.startPrank(accessAdminDeployer);
        accessAdmin.createRole(
            newRoleId, 
            adminRoleId, 
            "");
        vm.stopPrank();

        // WHEN + THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorAccessAdminRoleAdminNotExisting.selector, 
                missingAdminRoleId));

        vm.startPrank(accessAdminDeployer);
        accessAdmin.createRole(
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
        RoleId newAdminRoleId = RoleIdLib.toRoleId(123456789);
        string memory newRoleAdminName = "NewRoleAdmin";

        RoleId newRoleId = RoleIdLib.toRoleId(101);
        string memory newRoleName = "NewRole";

        vm.startPrank(accessAdminDeployer);

        // WHEN

        // create admin role first
        accessAdmin.createRole(
            newAdminRoleId, 
            adminRoleId, 
            newRoleAdminName);

        // then create actual role
        accessAdmin.createRole(
            newRoleId, 
            newAdminRoleId, 
            newRoleName);

        // grant newly created role admin role to roleAdmin 
        accessAdmin.grantRole(roleAdmin, newAdminRoleId);

        vm.stopPrank();

        // THEN
        assertTrue(accessAdmin.isRoleMember(newAdminRoleId, roleAdmin), "roleAdmin not having new role admin role");

        _checkRole(
            accessAdmin,
            newAdminRoleId, 
            adminRoleId,
            newRoleAdminName,
            TimestampLib.current());

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
            TimestampLib.current());

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
        uint64 roleIdInt = 42;
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
        assertTrue(accessAdmin.isRoleMember(newAdminRoleId, roleAdmin), "roleAdmin not having new role admin role");

        _checkRole(
            accessAdmin,
            newAdminRoleId, 
            adminRoleId,
            newAdminRoleName,
            TimestampLib.current());

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
            TimestampLib.current());

        // check granting of new role (check that roleAdmin can grant/revoke new role)
        _checkRoleGranting(
            accessAdmin,
            newRoleId, 
            roleAdmin,
            account1,
            account2);
    }


    function test_accessAdminCreateRole2LevelGrantAndRevokeToMultipleAccounts() public {
        // GIVEN

        RoleId adminRoleId = accessAdmin.getManagerRole();
        uint64 roleIdInt = 42;
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


    function test_accessAdminCreateRoleUnauthorized() public {
        // GIVEN (just setup)
        RoleId newRoleId = RoleIdLib.toRoleId(123456789);
        RoleId adminRoleId = accessAdmin.getAdminRole();
        string memory newRoleName = "NewRole";

        vm.startPrank(outsider);

        // WHEN + THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessManaged.AccessManagedUnauthorized.selector,
                outsider));

        accessAdmin.createRole(
            newRoleId, 
            adminRoleId, 
            newRoleName);

        vm.stopPrank();
    }


    function test_accessAdminGrantRevokeNonexistentRole() public {

        // GIVEN - setup
        RoleId missingRoleId = RoleIdLib.toRoleId(404);

        // WHEN + THEN grant/revoke
        vm.startPrank(accessAdminDeployer);

        // granting non existent role -> role unknown
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorAccessAdminRoleUnknown.selector,
                missingRoleId));

        accessAdmin.grantRole(outsider, missingRoleId);

        // revoking non existent role -> role unknown
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorAccessAdminRoleUnknown.selector,
                missingRoleId));

        accessAdmin.revokeRole(outsider, missingRoleId);
        vm.stopPrank();

        vm.startPrank(outsider);

        // WHEN + THEN - renounce
        // renouncing non existent role -> role unknown
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorAccessAdminRoleUnknown.selector,
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

        // solhint-disable next-line
        console.log("attempt to grant admin role");
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorAccessAdminInvalidUseOfAdminRole.selector));

        accessAdmin.grantRole(outsider, adminRole);

        // solhint-disable next-line
        console.log("attempt to revoke admin role");
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorAccessAdminInvalidUseOfAdminRole.selector));

        accessAdmin.revokeRole(outsider, adminRole);

        // solhint-disable next-line
        console.log("attempt to renounce admin role");
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorAccessAdminInvalidUseOfAdminRole.selector));

        accessAdmin.renounceRole(adminRole);

        // public role
        vm.startPrank(address(accessAdmin));

        // solhint-disable next-line
        console.log("attempt to grant public role");
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorAccessAdminInvalidUseOfPublicRole.selector));

        accessAdmin.grantRole(outsider, publicRole);

        // solhint-disable next-line
        console.log("attempt to revoke public role");
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorAccessAdminInvalidUseOfPublicRole.selector));

        accessAdmin.revokeRole(outsider, publicRole);

        // solhint-disable next-line
        console.log("attempt to renounce public role");
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorAccessAdminInvalidUseOfPublicRole.selector));

        accessAdmin.renounceRole(publicRole);

        vm.stopPrank();
    }


    function test_accessAdminSetRoleActive() public {

        // GIVEN (just setup)
        RoleId newRoleId = RoleIdLib.toRoleId(123456789);
        RoleId adminRoleId = accessAdmin.getManagerRole();
        string memory newRoleName = "NewRole";

        vm.roll(2001);
        vm.startPrank(accessAdminDeployer);

        accessAdmin.createRole(
            newRoleId, 
            adminRoleId, 
            newRoleName);

        assertTrue(accessAdmin.isRoleActive(newRoleId), "role not active (before)");

        // WHEN - deactivate role
        vm.roll(2002);
        accessAdmin.setRoleActive(newRoleId, false);

        // THEN
        assertFalse(accessAdmin.isRoleActive(newRoleId), "role active (after)");

        // attempt to grant role
        vm.roll(2003);

        // solhint-disable next-line
        console.log("attempt to grant a paused role");
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorAccessAdminRoleIsPaused.selector,
                newRoleId));

        accessAdmin.grantRole(outsider, newRoleId);

        // check that role assignment did not happen
        assertFalse(accessAdmin.isRoleMember(newRoleId, outsider), "outsider has role (after)");

        // WHEN re-activate role
        accessAdmin.setRoleActive(newRoleId, true);

        // THEN
        assertTrue(accessAdmin.isRoleActive(newRoleId), "role not active (after 2)");

        // attempt to grant role should now work
        accessAdmin.grantRole(outsider, newRoleId);

        // check that role assignment now did happen
        assertTrue(accessAdmin.isRoleMember(newRoleId, outsider), "outsider doesn't have role (after 2)");
        // assertTrue(false, "oops");
    }


    function test_accessAdminAuthorizeFunctions() public {
        // GIVEN
        RoleId managerRoleId = accessAdmin.getManagerRole();

        accessAdmin.grantRole(accessAdminDeployer, managerRoleId);

        assertTrue(
            accessAdmin.isRoleMember(
                managerRoleId,
                accessAdminDeployer),
            "access admin deployer does not have manager role");

        Selector grantRoleSelector = SelectorLib.toSelector(accessAdmin.grantRole.selector);
        IAccess.FunctionInfo memory functionInfo = accessAdmin.getFunctionInfo(
            address(accessAdmin), grantRoleSelector);

        assertTrue(functionInfo.name == StrLib.toStr("grantRole"), "unexpected selector, not 'grantRole'");
        assertEq(functionInfo.lastUpdateIn.toInt(), 1, "unexpected last update in");

        IAccess.FunctionInfo[] memory grantRoleFunction = new IAccess.FunctionInfo[](1);
        grantRoleFunction[0] = AccessAdminLib.toFunction(
            AccessAdminForTesting.grantRole.selector,
            "grantRole");

        vm.roll(2001);
        vm.startPrank(accessAdminDeployer);

        // WHEN
        accessAdmin.unauthorizeFunctions(
            address(accessAdmin), 
            grantRoleFunction);

        // check updated functio info
        IAccess.FunctionInfo memory fInfo = accessAdmin.getFunctionInfo(address(accessAdmin), grantRoleSelector);
        console.log("fInfo.lastUpdateIn", fInfo.lastUpdateIn.toInt());

        // THEN

        // attempt to grant role without authorization
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessManaged.AccessManagedUnauthorized.selector, 
                accessAdminDeployer));

        accessAdmin.grantRole(outsider, managerRoleId);

        vm.roll(2002);

        // WHEN granting back to manager role
        accessAdmin.authorizeFunctions(
            address(accessAdmin), 
            managerRoleId,
            grantRoleFunction);

        // THEN

        // attempt to grant role will now work
        accessAdmin.grantRole(outsider, managerRoleId);
        // assertTrue(false, "oops");
    }


    function _createManagedRoleWithOwnAdmin(
        uint64 roleIdInt, 
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
        accessAdmin.createRole(
            newAdminRoleId, 
            adminRoleId, 
            newAdminRoleName);

        // then create actual role
        accessAdmin.createRole(
            newRoleId, 
            newAdminRoleId, 
            newRoleName);

        // grant newly created role admin role to roleAdmin 
        accessAdmin.grantRole(roleAdmin, newAdminRoleId);
    }

    function _checkRoleGranting(
        AccessAdminForTesting aa, 
        RoleId roleId, 
        address roleAdmin,
        address account1,
        address account2
    )
        internal
    {
        // GIVEN
        RoleId adminRoleId = aa.getRoleInfo(roleId).adminRoleId;
        assertFalse(aa.isRoleMember(roleId, account1), "account1 already has role");
        assertFalse(aa.isRoleMember(adminRoleId, account1), "account1 is role admin");
        assertTrue(aa.isRoleMember(adminRoleId, roleAdmin), "role admin is not role admin");

        // WHEN - grant role
        vm.startPrank(roleAdmin);
        aa.grantRole(account1, roleId);
        aa.grantRole(account2, roleId);
        vm.stopPrank();

        // THEN (grant)
        assertTrue(aa.isRoleMember(roleId, account1), "outsider has not been granted role");
        assertTrue(aa.isRoleMember(roleId, account2), "outsider2 has not been granted role");
        assertFalse(aa.isRoleMember(adminRoleId, account1), "outsider is role admin");
        assertFalse(aa.isRoleMember(adminRoleId, account2), "outsider2 is role admin");

        // WHEN - revoke role
        vm.startPrank(roleAdmin);
        aa.revokeRole(account1, roleId);
        vm.stopPrank();

        // THEN (revoke)
        assertFalse(aa.isRoleMember(roleId, account1), "outsider still has role");
        assertFalse(aa.isRoleMember(adminRoleId, account1), "outsider is role admin");

        // WHEN - renounce role
        vm.startPrank(account2);
        aa.renounceRole(roleId);
        vm.stopPrank();

        // THEN (renounce)
        assertFalse(aa.isRoleMember(roleId, account2), "outsider2 still has role");
        assertFalse(aa.isRoleMember(adminRoleId, account2), "outsider2 is role admin");
    }


    function _checkAccessAdmin(
        AccessAdminForTesting aa, 
        address expectedDeployer
    )
        internal
    {
        assertTrue(address(aa) != address(0), "access admin is 0");
        assertTrue(aa.authority() != address(0), "access admin authority is 0");

        // check aa roles
        assertTrue(aa.isRoleMember(aa.getAdminRole(), address(aa)), "access admin missing admin role");
        assertFalse(aa.isRoleMember(aa.getManagerRole(), address(aa)), "access admin has manager role");
        assertTrue(aa.isRoleMember(aa.getPublicRole(), address(aa)), "access admin missing public role");

        // check deployer roles
        assertFalse(aa.isRoleMember(aa.getAdminRole(), expectedDeployer), "deployer has admin role");
        assertTrue(aa.isRoleMember(aa.getManagerRole(), expectedDeployer), "deployer missing manager role");
        assertTrue(aa.isRoleMember(aa.getPublicRole(), expectedDeployer), "deployer missing public role");

        // check outsider roles
        assertFalse(aa.isRoleMember(aa.getAdminRole(), outsider), "outsider has admin role");
        assertFalse(aa.isRoleMember(aa.getManagerRole(), outsider), "outsider has manager role");
        assertTrue(aa.isRoleMember(aa.getPublicRole(), outsider), "outsider missing public role");

        // count roles and check role ids
        assertEq(aa.roles(), 4, "unexpected number of roles for freshly initialized access admin");
        assertEq(aa.getRoleId(0).toInt(), aa.getAdminRole().toInt(), "unexpected admin role id");
        assertEq(aa.getRoleId(0).toInt(), type(uint64).min, "unexpected admin role id (absolute)");
        assertEq(aa.getRoleId(1).toInt(), aa.getPublicRole().toInt(), "unexpected public role id");
        assertEq(aa.getRoleId(1).toInt(), type(uint64).max, "unexpected public role id (absolute)");
        assertEq(aa.getRoleId(3).toInt(), aa.getManagerRole().toInt(), "unexpected manager role id");
        assertEq(aa.getRoleId(3).toInt(), 1, "unexpected manager role id (absolute)");

        // check admin role
        _checkRole(
            aa,
            aa.getAdminRole(), 
            aa.getAdminRole(),
            AccessAdminLib.ADMIN_ROLE_NAME(),
            1, // only one admin ! (aa contract is sole admin role member)
            TimestampLib.current());

        // check public role
        _checkRole(
            aa,
            aa.getPublicRole(), 
            aa.getAdminRole(),
            AccessAdminLib.PUBLIC_ROLE_NAME(),
            type(uint32).max, // every account is public role member
            TimestampLib.current());

        // check manager role
        _checkRole(
            aa,
            aa.getManagerRole(), 
            aa.getAdminRole(),
            aa.MANAGER_ROLE_NAME(),
            3,
            TimestampLib.current());

        // check non existent role
        RoleId missingRoleId = RoleIdLib.toRoleId(1313);
        assertFalse(aa.roleExists(missingRoleId), "missing role exists"); 

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
        Timestamp expectedCreatedAt
    )
        internal
    {
        _checkRole(
            aa, 
            roleId, 
            expectedAdminRoleId, 
            expectedName, 
            type(uint32).max, 
            expectedCreatedAt);
    }

    function _checkRole(
        IAccessAdmin aa,
        RoleId roleId, 
        RoleId expectedAdminRoleId,
        string memory expectedName,
        uint256 expectedMaxMemberCount,
        Timestamp expectedCreatedAt
    )
        internal
        view
    {
        // solhint-disable-next-line
        console.log("checking role", expectedName);

        assertTrue(aa.roleExists(roleId), "role does not exist");

        IAccessAdmin.RoleInfo memory info = aa.getRoleInfo(roleId);
        assertEq(info.adminRoleId.toInt(), expectedAdminRoleId.toInt(), "unexpected admin role (role info)");
        assertEq(info.name.toString(), expectedName, "unexpected role name");
        assertEq(info.maxMemberCount, expectedMaxMemberCount, "unexpected maxMemberCount");
        assertTrue(info.createdAt.gtz(), "role does not exist");
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
                IAccess.FunctionInfo memory func,
                RoleId roleId
            ) = aa.getAuthorizedFunction(target, i);
            string memory role = aa.getRoleInfo(roleId).name.toString();

            console.log("-", i, string(abi.encodePacked(func.name.toString(), "(): ", role,":")), roleId.toInt());
        }
        // solhint-enable
    }

}
