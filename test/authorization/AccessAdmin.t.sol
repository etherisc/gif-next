// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {Test, console} from "../../lib/forge-std/src/Test.sol";

import {AccessAdmin} from "../../contracts/authorization/AccessAdmin.sol";
import {AccessManagerCloneable} from "../../contracts/authorization/AccessManagerCloneable.sol";
import {AccessManagedMock} from "../mock/AccessManagedMock.sol";
import {IAccess} from "../../contracts/authorization/IAccess.sol";
import {IAccessAdmin} from "../../contracts/authorization/IAccessAdmin.sol";
import {RegistryAdmin} from "../../contracts/registry/RegistryAdmin.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {RoleId, RoleIdLib} from "../../contracts/type/RoleId.sol";
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
        initialize(new AccessManagerCloneable());
    }

    function completeSetup(
        address registry,
        VersionPart release
    )
        public
        reinitializer(type(uint8).max)
        onlyDeployer()
    {
        // link access manager to registry and release
        AccessManagerCloneable(authority()).completeSetup(
            registry, 
            release);

        // create targets for testing
        _createTarget(address(this), "AccessAdmin", false, true);

        // setup manager role
        _managerRoleId = RoleIdLib.toRoleId(MANAGER_ROLE);
        _createRole(
            _managerRoleId, 
            toRole(
                getAdminRole(),
                RoleType.Custom,
                3, // max accounts with this role
                MANAGER_ROLE_NAME)); 

        // grant public role access to grant and revoke, renounce
        FunctionInfo[] memory functions;
        functions = new FunctionInfo[](4);
        functions[0] = toFunction(AccessAdminForTesting.grantManagerRole.selector, "grantManagerRole");
        functions[1] = toFunction(AccessAdminForTesting.grantRole.selector, "grantRole");
        functions[2] = toFunction(AccessAdminForTesting.revokeRole.selector, "revokeRole");
        functions[3] = toFunction(AccessAdminForTesting.renounceRole.selector, "renounceRole");
        _authorizeTargetFunctions(address(this), getPublicRole(), functions);

        // grant manager role access to the specified functions 
        functions = new FunctionInfo[](6);
        functions[0] = toFunction(AccessAdminForTesting.createRole.selector, "createRole");
        functions[1] = toFunction(AccessAdminForTesting.createRoleExtended.selector, "createRoleExtended");
        functions[2] = toFunction(AccessAdminForTesting.createTarget.selector, "createTarget");
        functions[3] = toFunction(AccessAdminForTesting.setTargetLocked.selector, "setTargetLocked");
        functions[4] = toFunction(AccessAdminForTesting.authorizeFunctions.selector, "authorizeFunctions");
        functions[5] = toFunction(AccessAdminForTesting.unauthorizeFunctions.selector, "unauthorizeFunctions");
        _authorizeTargetFunctions(address(this), getManagerRole(), functions);

        _grantRoleToAccount(_managerRoleId, _deployer);
    }

    //--- role management functions -----------------------------------------//

    function grantManagerRole(address account)
        external
        restricted()
        onlyDeployer()
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
        _createRole(
            roleId,
            toRole(
                adminRoleId, 
                RoleType.Custom, 
                type(uint32).max, 
                name));
    }

    function createRoleExtended(
        RoleId roleId, 
        RoleId adminRoleId, 
        RoleType roleType,
        string memory name, 
        uint32 maxOneRoleMember
    )
        external
        restricted()
    {
        _createRole(
            roleId, 
            toRole(
                adminRoleId, 
                roleType, 
                maxOneRoleMember, 
                name));
    }

    function grantRole(
        address account, 
        RoleId roleId
    )
        external
        virtual
        onlyRoleAdmin(roleId) 
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
        onlyRoleAdmin(roleId)
        restricted()
    {
        _revokeRoleFromAccount(roleId, account);
    }

    function renounceRole(
        RoleId roleId
    )
        external
        virtual
        onlyRoleMember(roleId)
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
        bool checkAuthoritiy = true;
        bool custom = true;
        _createTarget(target, name, checkAuthoritiy, custom);
    }

    function authorizeFunctions(
        address target, 
        RoleId roleId, 
        FunctionInfo[] memory functions
    )
        external
        virtual
        onlyExistingRole(roleId, false)
        onlyExistingTarget(target)
        restricted()
    {
        _authorizeTargetFunctions(target, roleId, functions);
    }

    function unauthorizeFunctions(
        address target, 
        FunctionInfo[] memory functions
    )
        external
        virtual
        restricted()
    {
        _unauthorizeTargetFunctions(target, functions);
    }


    function setTargetLocked(
        address target, 
        bool locked
    )
        external
        virtual
        restricted()
    {
        // TODO figure out if it important to call directlly
        //_authority.setTargetClosed(target, locked);
        _setTargetClosed(target, locked);

        // implizit logging: rely on OpenZeppelin log TargetClosed
    }

    function getManagerRole() public view returns (RoleId roleId) {
        return _managerRoleId;
    }

}

contract AccessAdminTest is Test {

    address public accessAdminDeployer = makeAddr("accessAdminDeployer");
    address public globalRegistry = makeAddr("globalRegistry");
    address public admin = makeAddr("admin");
    address public outsider = makeAddr("outsider");
    address public outsider2 = makeAddr("outsider2");

    RegistryAdmin public registryAdmin;
    Registry public registry;
    VersionPart release;
    AccessManagerCloneable public accessManager;
    AccessAdminForTesting public accessAdmin;

    AccessManagedMock public accessManaged;


    function setUp() public {

        vm.startPrank(accessAdminDeployer);

        // create access admin for testing
        accessAdmin = new AccessAdminForTesting();

        // create registry and release version
        registryAdmin = new RegistryAdmin();
        registry = new Registry(registryAdmin, globalRegistry);
        VersionPart release = VersionPartLib.toVersionPart(3);

        // complete setup (which links internal acccess manager to registry and release)
        // and grants manager role to deployer
        accessAdmin.completeSetup(
            address(registry), 
            release);

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

        // WHEN
        uint32 maxOneRoleMember = 1; // max 1 member allowed
        vm.prank(accessAdminDeployer);
        accessAdmin.createRoleExtended(
            newRoleId, 
            adminRoleId, 
            IAccess.RoleType.Contract,
            newRoleName,
            maxOneRoleMember); 

        // THEN
        _checkRole(
            accessAdmin,
            newRoleId, 
            adminRoleId,
            newRoleName,
            maxOneRoleMember,
            TimestampLib.blockTimestamp());

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
                IAccessAdmin.ErrorRoleMembersLimitReached.selector, 
                newRoleId,
                maxOneRoleMember));

        vm.prank(accessAdminDeployer);
        accessAdmin.grantRole(outsider, newRoleId);

        // WHEN + THEN - attempt to revoke role
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorRoleMemberRemovalDisabled.selector, 
                newRoleId,
                thisContract));

        vm.prank(accessAdminDeployer);
        accessAdmin.revokeRole(thisContract, newRoleId);

        // WHEN + THEN - attempt to renounce role
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorRoleMemberRemovalDisabled.selector, 
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
                IAccessAdmin.ErrorRoleAlreadyCreated.selector, 
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
                IAccessAdmin.ErrorRoleAlreadyCreated.selector, 
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
                IAccessAdmin.ErrorRoleAlreadyCreated.selector, 
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
        RoleId newRoleId = RoleIdLib.toRoleId(100);
        RoleId adminRoleId = accessAdmin.getManagerRole();
        string memory newRoleName = "NewRole";

        vm.startPrank(accessAdminDeployer);
        accessAdmin.createRole(
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
        accessAdmin.createRole(
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
        accessAdmin.createRole(
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
        accessAdmin.createRole(
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
        RoleId newAdminRoleId = RoleIdLib.toRoleId(100);
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
        assertTrue(accessAdmin.hasRole(roleAdmin, newAdminRoleId), "roleAdmin not having new role admin role");

        _checkRole(
            accessAdmin,
            newAdminRoleId, 
            adminRoleId,
            newRoleAdminName,
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
        assertTrue(accessAdmin.hasRole(roleAdmin, newAdminRoleId), "roleAdmin not having new role admin role");

        _checkRole(
            accessAdmin,
            newAdminRoleId, 
            adminRoleId,
            newAdminRoleName,
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
        uint64 roleIdInt = 42;
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
        uint64 roleIdInt = 42;
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


    function test_accessAdminCreateRole2LevelGrantRevokeRoleMultipleTimes() public {
        // GIVEN

        RoleId adminRoleId = accessAdmin.getManagerRole();
        uint64 roleIdInt = 42;
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

        accessAdmin.createRole(
            newRoleId, 
            adminRoleId, 
            newRoleName);

        vm.stopPrank();
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

        // solhint-disable next-line
        console.log("attempt to grant admin role");
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorRoleIsLocked.selector,
                adminRole));

        accessAdmin.grantRole(outsider, adminRole);

        // solhint-disable next-line
        console.log("attempt to revoke admin role");
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorRoleIsLocked.selector,
                adminRole));

        accessAdmin.revokeRole(outsider, adminRole);

        // solhint-disable next-line
        console.log("attempt to renounce admin role");
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessAdmin.ErrorRoleIsLocked.selector,
                adminRole));

        accessAdmin.renounceRole(adminRole);

        // public role
        vm.startPrank(address(accessAdmin));

        // solhint-disable next-line
        console.log("attempt to grant public role");
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessManager.AccessManagerLockedRole.selector,
                publicRole));

        accessAdmin.grantRole(outsider, publicRole);

        // solhint-disable next-line
        console.log("attempt to revoke public role");
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessManager.AccessManagerLockedRole.selector,
                publicRole));

        accessAdmin.revokeRole(outsider, publicRole);

        // solhint-disable next-line
        console.log("attempt to renounce public role");
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessManager.AccessManagerLockedRole.selector,
                publicRole));

        accessAdmin.renounceRole(publicRole);

        vm.stopPrank();
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
            1, // only one admin ! (aa contract is sole admin role member)
            TimestampLib.blockTimestamp());

        // check public role
        _checkRole(
            aa,
            aa.getPublicRole(), 
            aa.getAdminRole(),
            aa.PUBLIC_ROLE_NAME(),
            type(uint32).max, // every account is public role member
            TimestampLib.blockTimestamp());

        // check manager role
        _checkRole(
            aa,
            aa.getManagerRole(), 
            aa.getAdminRole(),
            aa.MANAGER_ROLE_NAME(),
            3,
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
    {
        // solhint-disable-next-line
        console.log("checking role", expectedName);

        assertTrue(aa.roleExists(roleId), "role does not exist");
        assertEq(aa.getRoleForName(StrLib.toStr(expectedName)).roleId.toInt(), roleId.toInt(), "unexpected roleId for getRoleForName");

        IAccessAdmin.RoleInfo memory info = aa.getRoleInfo(roleId);
        assertEq(info.adminRoleId.toInt(), expectedAdminRoleId.toInt(), "unexpected admin role (role info)");
        assertEq(info.name.toString(), expectedName, "unexpected role name");
        assertEq(info.maxMemberCount, expectedMaxMemberCount, "unexpected maxMemberCount");
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
