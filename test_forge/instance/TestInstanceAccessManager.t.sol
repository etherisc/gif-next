// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";
import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {ShortString, ShortStrings} from "@openzeppelin/contracts/utils/ShortStrings.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

//import {Test, console} from "../../lib/forge-std/src/Test.sol";

import {PRODUCT} from "../../contracts/types/ObjectType.sol";
import {zeroNftId} from "../../contracts/types/NftId.sol";
import {FeeLib} from "../../contracts/types/Fee.sol";
import {RoleId} from "../../contracts/types/RoleId.sol";
import {TimestampLib} from "../../contracts/types/Timestamp.sol";
import {ADMIN_ROLE, PRODUCT_SERVICE_ROLE, PRODUCT_OWNER_ROLE, POOL_OWNER_ROLE, INSTANCE_OWNER_ROLE, INSTANCE_ROLE, RoleId, RoleIdLib} from "../../contracts/types/RoleId.sol";

import {IRegisterable} from "../../contracts/shared/IRegisterable.sol";

import {IComponent} from "../../contracts/components/IComponent.sol";

import {AccessManagerUpgradeableInitializeable} from "../../contracts/instance/AccessManagerUpgradeableInitializeable.sol";
import {IInstance} from "../../contracts/instance/IInstance.sol";
import {Instance} from "../../contracts/instance/Instance.sol";
import {InstanceAccessManager} from "../../contracts/instance/InstanceAccessManager.sol";
import {IAccess} from "../../contracts/instance/module/IAccess.sol";

import {TestGifBase} from "../base/TestGifBase.sol";
import {SimpleProduct, SPECIAL_ROLE_INT} from "../mock/SimpleProduct.sol";
import {AccessManagedMock} from "../mock/AccessManagedMock.sol";
import {RegisterableMock, SimpleAccessManagedRegisterableMock} from "../mock/RegisterableMock.sol";



function eqRoleInfo(IAccess.RoleInfo memory a, IAccess.RoleInfo memory b) pure returns (bool isSame) {
    return (
        (Strings.equal(ShortStrings.toString(a.name), ShortStrings.toString(b.name))) &&
        (a.rtype == b.rtype) &&
        (a.admin == b.admin) &&
        (a.createdAt == b.createdAt) &&
        (a.updatedAt == b.updatedAt)
    );
}

function eqTargetInfo(IAccess.TargetInfo memory a, IAccess.TargetInfo memory b) pure returns (bool isSame) {
    return (
        (Strings.equal(ShortStrings.toString(a.name), ShortStrings.toString(b.name))) &&
        (a.ttype == b.ttype) &&
        (a.isLocked == b.isLocked) &&
        (a.createdAt == b.createdAt) &&
        (a.updatedAt == b.updatedAt)
    );
}

contract TestInstanceAccessManager is TestGifBase {

    uint256 public constant INITIAL_BALANCE = 100000;
    uint256 public constant CUSTOM_ROLE_ID_MIN = 10000;

    RoleId customRoleId;
    RoleId customRoleAdmin;


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
        (customRoleId, customRoleAdmin) = instance.createRole("SpecialRole", "SpecialRoleAdmin");
        // set special role for product custom product function 
        bytes4[] memory fcts = new bytes4[](1);
        fcts[0] = SimpleProduct.doSomethingSpecial.selector;
        instance.setTargetFunctionRole(product.getName(), fcts, customRoleId);
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
        instance.setTargetFunctionRole(product.getName(), fctSelectors, PRODUCT_OWNER_ROLE());
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



    //--- Create core role -----------------------------------------------//

    function test_InstanceAccessManager_createCoreRole_HappyCase() public 
    {
        RoleId coreRoleId = RoleIdLib.toRoleId(6666);
        IAccess.RoleInfo memory info = IAccess.RoleInfo({
            name: ShortStrings.toShortString("CoreRole"),
            rtype: IAccess.Type.Core,
            admin: ADMIN_ROLE(),
            updatedAt: TimestampLib.blockTimestamp(),
            createdAt: TimestampLib.blockTimestamp()
        });

        vm.startPrank(address(instanceAccessManager));
        instanceAccessManager.createCoreRole(coreRoleId, "CoreRole");
        vm.stopPrank();

        assertTrue(instanceAccessManager.roleExists(coreRoleId), "created core role not exists");
        assertEq(instanceAccessManager.roleMembers(coreRoleId), 0, "created core role have members");

        assertTrue(eqRoleInfo(info, instanceAccessManager.getRoleInfo(coreRoleId)), "created role info is invalid");
    }

    function test_InstanceAccessManager_createCoreRole_byNotAdminRole() public
    {
        RoleId coreRoleId = RoleIdLib.toRoleId(6666);
        vm.startPrank(instanceOwner);

        vm.expectRevert(abi.encodeWithSelector(
            IAccessManaged.AccessManagedUnauthorized.selector, 
            instanceOwner));
        instanceAccessManager.createCoreRole(coreRoleId, "CoreRole");

        vm.stopPrank();
    }

    function test_InstanceAccessManager_createCoreRole_withExistingRoleId() public
    {
        RoleId coreRoleId = RoleIdLib.toRoleId(6666);
        vm.startPrank(address(instanceAccessManager));
        instanceAccessManager.createCoreRole(coreRoleId, "CoreRole1");

        vm.expectRevert(abi.encodeWithSelector(
            IAccess.ErrorIAccessRoleIdExists.selector,
            coreRoleId));
        instanceAccessManager.createCoreRole(coreRoleId, "CoreRole2");

        vm.stopPrank();
    }

    function test_InstanceAccessManager_createCoreRole_withTooBigRoleId() public
    {
        RoleId coreRoleId = RoleIdLib.toRoleId(type(uint64).max - 1);
        vm.startPrank(address(instanceAccessManager));
        vm.expectRevert(abi.encodeWithSelector(
            IAccess.ErrorIAccessRoleIdTooBig.selector,
            coreRoleId));
        instanceAccessManager.createCoreRole(coreRoleId, "CoreRole");
        vm.stopPrank();
    }

    function test_InstanceAccessManager_createCoreRole_withExistingRoleName() public
    {
        RoleId coreRoleId_1 = RoleIdLib.toRoleId(6666);
        RoleId coreRoleId_2 = RoleIdLib.toRoleId(6667);
        vm.startPrank(address(instanceAccessManager));
        instanceAccessManager.createCoreRole(coreRoleId_1, "CoreRole");

        vm.expectRevert(abi.encodeWithSelector(
            IAccess.ErrorIAccessRoleNameExists.selector,
            coreRoleId_2,
            coreRoleId_1,
            ShortStrings.toShortString("CoreRole")));
        instanceAccessManager.createCoreRole(coreRoleId_2, "CoreRole");

        vm.stopPrank();
    }

    function test_InstanceAccessManager_createCoreRole_withEmptyRoleName() public
    {
        RoleId coreRoleId = RoleIdLib.toRoleId(6666);
        vm.startPrank(address(instanceAccessManager));
        vm.expectRevert(abi.encodeWithSelector(
            IAccess.ErrorIAccessRoleNameEmpty.selector,
            coreRoleId));
        instanceAccessManager.createCoreRole(coreRoleId, "");
        vm.stopPrank();
    }


    //--- Create gif role -----------------------------------------------//

    function test_InstanceAccessManager_createGifRole_HappyCase() public
    {
        RoleId gifRoleId = RoleIdLib.toRoleId(5555);
        IAccess.RoleInfo memory info = IAccess.RoleInfo({
            name: ShortStrings.toShortString("GifRole"),
            rtype: IAccess.Type.Gif,
            admin: INSTANCE_OWNER_ROLE(),
            updatedAt: TimestampLib.blockTimestamp(),
            createdAt: TimestampLib.blockTimestamp()
        });

        vm.startPrank(address(instanceAccessManager));
        instanceAccessManager.createGifRole(gifRoleId, "GifRole", INSTANCE_OWNER_ROLE());
        vm.stopPrank();

        assertTrue(instanceAccessManager.roleExists(gifRoleId), "created gif role not exists");
        assertEq(instanceAccessManager.roleMembers(gifRoleId), 0, "created gif role have members");

        assertTrue(eqRoleInfo(info, instanceAccessManager.getRoleInfo(gifRoleId)), "created role info is invalid");
    }

    function test_InstanceAccessManager_createGifRole_byNotAdminRole() public
    {
        RoleId gifRoleId = RoleIdLib.toRoleId(5555);
        RoleId gifRoleAdmin = INSTANCE_OWNER_ROLE();

        vm.startPrank(instanceOwner);
        vm.expectRevert(abi.encodeWithSelector(
            IAccessManaged.AccessManagedUnauthorized.selector, 
            instanceOwner));
        instanceAccessManager.createGifRole(gifRoleId, "GifRole", gifRoleAdmin);
        vm.stopPrank();
    }

    function test_InstanceAccessManager_createGifRole_withExistingRoleId() public
    {
        RoleId gifRoleId = RoleIdLib.toRoleId(5555);
        RoleId gifRoleAdmin = INSTANCE_OWNER_ROLE();

        vm.startPrank(address(instanceAccessManager));
        instanceAccessManager.createGifRole(gifRoleId, "GifRole1", gifRoleAdmin);
        vm.expectRevert(abi.encodeWithSelector(
            IAccess.ErrorIAccessRoleIdExists.selector,
            gifRoleId));
        instanceAccessManager.createGifRole(gifRoleId, "GifRole2", gifRoleAdmin);
        vm.stopPrank();
    }

    function test_InstanceAccessManager_createGifRole_withTooBigRoleId() public
    {
        RoleId gifRoleId = RoleIdLib.toRoleId(type(uint64).max - 1);
        RoleId gifRoleAdmin = INSTANCE_OWNER_ROLE();

        vm.startPrank(address(instanceAccessManager));
        vm.expectRevert(abi.encodeWithSelector(
            IAccess.ErrorIAccessRoleIdTooBig.selector,
            gifRoleId));
        instanceAccessManager.createGifRole(gifRoleId, "GifRole", gifRoleAdmin);
        vm.stopPrank();
    }

    function test_InstanceAccessManager_createGifRole_withExistingRoleName() public
    {
        RoleId gifRoleId_1 = RoleIdLib.toRoleId(5555);
        RoleId gifRoleId_2 = RoleIdLib.toRoleId(5556);
        RoleId gifRoleAdmin = INSTANCE_OWNER_ROLE();

        vm.startPrank(address(instanceAccessManager));

        instanceAccessManager.createGifRole(gifRoleId_1, "GifRole", gifRoleAdmin);

        vm.expectRevert(abi.encodeWithSelector(
            IAccess.ErrorIAccessRoleNameExists.selector,
            gifRoleId_2,
            gifRoleId_1,
            ShortStrings.toShortString("GifRole")));
        instanceAccessManager.createGifRole(gifRoleId_2, "GifRole", gifRoleAdmin);

        vm.stopPrank();
    }

    function test_InstanceAccessManager_createGifRole_withEmptyName() public
    {
        RoleId gifRoleId = RoleIdLib.toRoleId(5555);
        RoleId gifRoleAdmin = INSTANCE_OWNER_ROLE();

        vm.startPrank(address(instanceAccessManager));
        vm.expectRevert(abi.encodeWithSelector(
            IAccess.ErrorIAccessRoleNameEmpty.selector,
            gifRoleId));
        instanceAccessManager.createGifRole(gifRoleId, "", gifRoleAdmin);
        vm.stopPrank();
    }


    //--- Create custom role -----------------------------------------------//

    function test_InstanceAccessManager_createRole_HappyCase() public
    {
        // first pair
        IAccess.RoleInfo memory customRoleInfo = IAccess.RoleInfo({
            name: ShortStrings.toShortString("Role1234"),
            rtype: IAccess.Type.Custom,
            admin: RoleIdLib.toRoleId(CUSTOM_ROLE_ID_MIN + 1),
            updatedAt: TimestampLib.blockTimestamp(),
            createdAt: TimestampLib.blockTimestamp()
        });

        IAccess.RoleInfo memory customRoleAdminInfo = IAccess.RoleInfo({
            name: ShortStrings.toShortString("RoleAdmin1234"),
            rtype: IAccess.Type.Custom,
            admin: INSTANCE_OWNER_ROLE(),
            updatedAt: TimestampLib.blockTimestamp(),
            createdAt: TimestampLib.blockTimestamp()
        });
        vm.startPrank(address(instance));    

        (customRoleId, customRoleAdmin) = instanceAccessManager.createRole("Role1234", "RoleAdmin1234");

        assertEq(customRoleId.toInt(), CUSTOM_ROLE_ID_MIN, "first custom role id is not CUSTOM_ROLE_ID_MIN");
        assertEq(customRoleAdmin.toInt(), CUSTOM_ROLE_ID_MIN + 1, "first custom role id is not CUSTOM_ROLE_ID_MIN + 1");

        assertTrue(instanceAccessManager.roleExists(customRoleId), "first created custom role not exists");
        assertTrue(instanceAccessManager.roleExists(customRoleAdmin),"first created custom role admin not exists");

        assertEq(instanceAccessManager.roleMembers(customRoleId), 0, "first created custom role have members");
        assertEq(instanceAccessManager.roleMembers(customRoleAdmin), 0, "first created custom role admin have members");

        assertEq(customRoleAdmin.toInt(), instanceAccessManager.getRoleAdmin(customRoleId).toInt(), "first created custom role has invalid admin");
        assertEq(INSTANCE_OWNER_ROLE().toInt(), instanceAccessManager.getRoleAdmin(customRoleAdmin).toInt(), "first created custom role admin has invalid admin");

        assertTrue(eqRoleInfo(customRoleInfo, instanceAccessManager.getRoleInfo(customRoleId)), "first created custom role info is invalid");
        assertTrue(eqRoleInfo(customRoleAdminInfo, instanceAccessManager.getRoleInfo(customRoleAdmin)), "first created custom admin role info is invalid");

        // second pair
        customRoleInfo = IAccess.RoleInfo({
            name: ShortStrings.toShortString("Role5678"),
            rtype: IAccess.Type.Custom,
            admin: RoleIdLib.toRoleId(CUSTOM_ROLE_ID_MIN + 3),
            updatedAt: TimestampLib.blockTimestamp(),
            createdAt: TimestampLib.blockTimestamp()
        });

        customRoleAdminInfo = IAccess.RoleInfo({
            name: ShortStrings.toShortString("RoleAdmin5678"),
            rtype: IAccess.Type.Custom,
            admin: INSTANCE_OWNER_ROLE(),
            updatedAt: TimestampLib.blockTimestamp(),
            createdAt: TimestampLib.blockTimestamp()
        });

        (customRoleId, customRoleAdmin) = instanceAccessManager.createRole("Role5678", "RoleAdmin5678");

        assertEq(customRoleId.toInt(), CUSTOM_ROLE_ID_MIN + 2, "second custom role id is not CUSTOM_ROLE_ID_MIN + 2");
        assertEq(customRoleAdmin.toInt(), CUSTOM_ROLE_ID_MIN + 3, "second custom role id is not CUSTOM_ROLE_ID_MIN + 3");

        assertTrue(instanceAccessManager.roleExists(customRoleId), "second created custom role not exists");
        assertTrue(instanceAccessManager.roleExists(customRoleAdmin),"second created custom role admin not exists");

        assertEq(instanceAccessManager.roleMembers(customRoleId), 0, "second created custom role have members");
        assertEq(instanceAccessManager.roleMembers(customRoleAdmin), 0, "second created custom role admin have members");

        assertEq(customRoleAdmin.toInt(), instanceAccessManager.getRoleAdmin(customRoleId).toInt(), "second created custom role has invalid admin");
        assertEq(INSTANCE_OWNER_ROLE().toInt(), instanceAccessManager.getRoleAdmin(customRoleAdmin).toInt(), "second created custom role admin has invalid admin");

        assertTrue(eqRoleInfo(customRoleInfo, instanceAccessManager.getRoleInfo(customRoleId)), "second created custom role info is invalid");
        assertTrue(eqRoleInfo(customRoleAdminInfo, instanceAccessManager.getRoleInfo(customRoleAdmin)), "second created custom role admin info is invalid");

        vm.stopPrank();
    }

    function test_InstanceAccessManager_createRole_byNotInstanceOwnerRole() public
    {
        vm.startPrank(outsider);
        vm.expectRevert(abi.encodeWithSelector(
            IAccessManaged.AccessManagedUnauthorized.selector, 
            outsider));
        instanceAccessManager.createRole("Role1234", "RoleAdmin1234");
        vm.stopPrank();
    }

    function test_InstanceAccessManager_createRole_withExistingCustomRoleName() public
    {
        vm.startPrank(address(instance));    

        (customRoleId, customRoleAdmin) = instanceAccessManager.createRole("Role1234", "RoleAdmin1234");

        vm.expectRevert(abi.encodeWithSelector(
            IAccess.ErrorIAccessRoleNameExists.selector,
            RoleIdLib.toRoleId(customRoleId.toInt() + 2),
            customRoleId,
            ShortStrings.toShortString("Role1234")));
        (customRoleId, customRoleAdmin) = instanceAccessManager.createRole("Role1234", "RoleAdmin5678");

        vm.stopPrank();
    }

    function test_InstanceAccessManager_createRole_withExistingCustomRoleAdminName() public
    {
        vm.startPrank(address(instance));  

        (customRoleId, customRoleAdmin) = instanceAccessManager.createRole("Role1234", "RoleAdmin1234");

        vm.expectRevert(abi.encodeWithSelector(
            IAccess.ErrorIAccessRoleNameExists.selector,
            RoleIdLib.toRoleId(customRoleAdmin.toInt() + 2),
            customRoleAdmin,
            ShortStrings.toShortString("RoleAdmin1234")));
        (customRoleId, customRoleAdmin) = instanceAccessManager.createRole("Role5678", "RoleAdmin1234");

        vm.stopPrank();
    }

    function test_InstanceAccessManager_createRole_withEmptyRoleName() public
    {
        vm.startPrank(address(instance));

        vm.expectRevert(abi.encodeWithSelector(
            IAccess.ErrorIAccessRoleNameEmpty.selector,
            CUSTOM_ROLE_ID_MIN));
        (customRoleId, customRoleAdmin) = instanceAccessManager.createRole("", "RoleAdmin1234");

        vm.stopPrank();
    }

    function test_InstanceAccessManager_createRole_withEmptyRoleAdminName() public
    {
        vm.startPrank(address(instance));

        require(instanceAccessManager.hasRole(INSTANCE_ROLE(), address(instance)));

        vm.expectRevert(abi.encodeWithSelector(
            IAccess.ErrorIAccessRoleNameEmpty.selector,
            CUSTOM_ROLE_ID_MIN + 1));
        (customRoleId, customRoleAdmin) = instanceAccessManager.createRole("Role1234", "");

        vm.stopPrank();
    }

    //--- Grant role -----------------------------------------------//

    function test_InstanceAccessManager_grantRole_HappyCase() public
    {
        uint membersBefore = instanceAccessManager.roleMembers(PRODUCT_OWNER_ROLE());
        assertFalse(instanceAccessManager.hasRole(PRODUCT_OWNER_ROLE(), outsider));

        vm.startPrank(instanceOwner);
        assertTrue(instanceAccessManager.grantRole(PRODUCT_OWNER_ROLE(), outsider), "grantRole() by role admin failed");
        vm.stopPrank();

        assertEq(instanceAccessManager.roleMembers(PRODUCT_OWNER_ROLE()), membersBefore + 1, "role was granted to account but role members count is not encreased by 1");
        assertTrue(instanceAccessManager.hasRole(PRODUCT_OWNER_ROLE(), outsider), "role was granted to account but hasRole() returns false");
    }

    function test_InstanceAccessManager_grantRole_byNotRoleAdmin() public
    {
        vm.startPrank(instanceOwner);

        RoleId roleId = INSTANCE_OWNER_ROLE();
        vm.expectRevert(abi.encodeWithSelector(
            IAccess.ErrorIAccessCallerIsNotRoleAdmin.selector, 
            instanceOwner,
            roleId));
        instanceAccessManager.grantRole(roleId, outsider);

        vm.stopPrank();
    }

    function test_InstanceAccessManager_grantRole_nonExistingRole() public
    {
        RoleId nonExistingRole = RoleIdLib.toRoleId(type(uint64).max - 1);
        vm.startPrank(address(instanceAccessManager));
        vm.expectRevert(abi.encodeWithSelector(
            IAccess.ErrorIAccessRoleIdDoesNotExist.selector,
            nonExistingRole));
        instanceAccessManager.grantRole(nonExistingRole, outsider);
        vm.stopPrank();
    }


    //--- Revoke role -----------------------------------------------//

    function test_InstanceAccessManager_revokeRole_HappyCase() public
    {
        uint membersBefore = instanceAccessManager.roleMembers(PRODUCT_OWNER_ROLE());
        assertFalse(instanceAccessManager.hasRole(PRODUCT_OWNER_ROLE(), outsider));

        vm.startPrank(instanceOwner);
        assertTrue(instanceAccessManager.grantRole(PRODUCT_OWNER_ROLE(), outsider), "grantRole() by role admin failed");
        assertTrue(instanceAccessManager.revokeRole(PRODUCT_OWNER_ROLE(), outsider), "revokeRole() by role admin failed");
        vm.stopPrank();

        assertEq(instanceAccessManager.roleMembers(PRODUCT_OWNER_ROLE()), membersBefore, "role was revoked from account but role members count is not decreased by 1");
        assertFalse(instanceAccessManager.hasRole(PRODUCT_OWNER_ROLE(), outsider), "role was revoked from account but hasRole() returns true");
    }

    function test_InstanceAccessManager_revokeRole_byNotRoleAdmin() public
    {
        vm.startPrank(instanceOwner);
        assertTrue(instanceAccessManager.grantRole(PRODUCT_OWNER_ROLE(), outsider));
        vm.stopPrank();

        vm.startPrank(outsider);
        RoleId roleId = PRODUCT_OWNER_ROLE();
        vm.expectRevert(abi.encodeWithSelector(
            IAccess.ErrorIAccessCallerIsNotRoleAdmin.selector, 
            outsider,
            PRODUCT_OWNER_ROLE()));
        instanceAccessManager.revokeRole(roleId, outsider);
    }

    function test_InstanceAccessManager_revokeRole_nonExistingRole() public
    {
        RoleId nonExistingRole = RoleIdLib.toRoleId(type(uint64).max - 1);
        vm.startPrank(address(instanceAccessManager));
        vm.expectRevert(abi.encodeWithSelector(
            IAccess.ErrorIAccessRoleIdDoesNotExist.selector,
            nonExistingRole));
        instanceAccessManager.revokeRole(nonExistingRole, outsider);
        vm.stopPrank();
    }

    //--- Renounce custom role -----------------------------------------------//

    function test_InstanceAccessManager_renounceCustomRole_HappyCase() public
    {
        vm.startPrank(address(instance));
        (customRoleId, customRoleAdmin) = instanceAccessManager.createRole("Role1234", "RoleAdmin1234");
        vm.stopPrank();

        vm.startPrank(instanceOwner);   
        assertTrue(instanceAccessManager.grantRole(customRoleAdmin, instanceOwner), "grantRole() by role admin failed #1");
        assertTrue(instanceAccessManager.grantRole(customRoleId, outsider), "grantRole() by role admin failed #2");
        assertTrue(instanceAccessManager.grantRole(customRoleAdmin, productOwner), "grantRole() by role admin failed #3");

        vm.stopPrank();
        vm.startPrank(outsider);

        assertTrue(instanceAccessManager.renounceRole(customRoleId), "renounce custom role by member failed #1");

        vm.stopPrank();
        vm.startPrank(productOwner);

        assertTrue(instanceAccessManager.renounceRole(customRoleAdmin), "renounce custom role by member failed #2");

        vm.stopPrank();
        vm.startPrank(instanceOwner);

        assertTrue(instanceAccessManager.renounceRole(customRoleAdmin), "renounce custom role by member failed #3");

        vm.stopPrank();
    }

    function test_InstanceAccessManager_renounceCustomRole_byNotMember() public
    {
        vm.startPrank(address(instance));
        (customRoleId, customRoleAdmin) = instanceAccessManager.createRole("Role1234", "RoleAdmin1234");
        vm.stopPrank();
        
        vm.startPrank(instanceOwner);  
        assertFalse(instanceAccessManager.renounceRole(customRoleId), "renounce custom role by not member succeeded");
        assertFalse(instanceAccessManager.renounceRole(customRoleAdmin), "renounce custom role admin by not member succeeded");
        vm.stopPrank();
    }

    function test_InstanceAccessManager_renounceRole_nonExistingRole() public
    {
        RoleId nonExistingRole = RoleIdLib.toRoleId(type(uint64).max - 1);
        vm.startPrank(address(poolOwner));
        vm.expectRevert(abi.encodeWithSelector(
            IAccess.ErrorIAccessRoleIdDoesNotExist.selector,
            nonExistingRole));
        instanceAccessManager.renounceRole(nonExistingRole);
        vm.stopPrank();
    }

    //--- Renounce gif role -----------------------------------------------//

    function test_InstanceAccessManager_renounceGifRole() public
    {
        vm.startPrank(instanceOwner);
        assertTrue(instanceAccessManager.grantRole(PRODUCT_OWNER_ROLE(), productOwner));
        vm.stopPrank();

        vm.startPrank(productOwner);
        RoleId roleId = PRODUCT_OWNER_ROLE();
        vm.expectRevert(abi.encodeWithSelector(
            IAccess.ErrorIAccessRoleTypeInvalid.selector,
            roleId,
            IAccess.Type.Gif));
        instanceAccessManager.renounceRole(roleId);
        vm.stopPrank();
    }

    function test_InstanceAccessManager_renounceGifRole_byNotMember() public
    {
        assertFalse(instanceAccessManager.hasRole(PRODUCT_OWNER_ROLE(), instanceOwner), "account must not have this role");

        vm.startPrank(instanceOwner);

        RoleId roleId = PRODUCT_OWNER_ROLE();
        vm.expectRevert(abi.encodeWithSelector(
            IAccess.ErrorIAccessRoleTypeInvalid.selector,
            PRODUCT_OWNER_ROLE(),
            IAccess.Type.Gif));
        instanceAccessManager.renounceRole(roleId);

        vm.stopPrank();
    }

    //--- Renounce core role -----------------------------------------------//

    function test_InstanceAccessManager_renounceCoreRole() public
    {
        assertTrue(instanceAccessManager.hasRole(PRODUCT_SERVICE_ROLE(), address(productService)), "account has no required role to start with");

        vm.startPrank(address(productService));

        RoleId roleId = PRODUCT_SERVICE_ROLE();
        vm.expectRevert(abi.encodeWithSelector(
            IAccess.ErrorIAccessRoleTypeInvalid.selector,
            roleId,
            IAccess.Type.Core));
        instanceAccessManager.renounceRole(roleId);

        vm.stopPrank();
    }

    function test_InstanceAccessManager_renounceCoreRole_byNotMember() public
    {
        assertTrue(instanceAccessManager.hasRole(PRODUCT_SERVICE_ROLE(), address(productService)), "account has no required role to start with");

        vm.startPrank(instanceOwner);

        RoleId roleId = PRODUCT_SERVICE_ROLE();
        vm.expectRevert(abi.encodeWithSelector(
            IAccess.ErrorIAccessRoleTypeInvalid.selector,
            roleId,
            IAccess.Type.Core));
        instanceAccessManager.renounceRole(roleId);

        vm.stopPrank();
    }

    //--- Create core target  -----------------------------------------------------//

    function test_InstanceAccessManager_createCoreTarget_HappyCase() public
    {
        IAccessManaged coreTarget = new AccessManagedMock(address(ozAccessManager));
        address coreTargetAddress = address(coreTarget);
    
        IAccess.TargetInfo memory info = IAccess.TargetInfo({
            name: ShortStrings.toShortString("CoreTarget1234"),
            ttype: IAccess.Type.Core,
            isLocked: false,
            createdAt: TimestampLib.blockTimestamp(),
            updatedAt: TimestampLib.blockTimestamp()
        });

        vm.startPrank(address(instanceAccessManager));
        instanceAccessManager.createCoreTarget(coreTargetAddress, "CoreTarget1234");
        vm.stopPrank();

        assertFalse(instanceAccessManager.isTargetLocked(coreTargetAddress), "created core target is locked");
        assertTrue(instanceAccessManager.targetExists(coreTargetAddress), "created core target not exists");
        assertTrue(eqTargetInfo(info, instanceAccessManager.getTargetInfo(coreTargetAddress)), "created target info is invalid");
    }

    function test_InstanceAccessManager_createCoreTarget_byNotAdminRole() public
    {
        IAccessManaged coreTarget = new AccessManagedMock(address(ozAccessManager));
        address coreTargetAddress = address(coreTarget);

        vm.startPrank(instanceOwner);
        vm.expectRevert(abi.encodeWithSelector(
            IAccessManaged.AccessManagedUnauthorized.selector, 
            instanceOwner));
        instanceAccessManager.createCoreTarget(coreTargetAddress, "CoreTarget1234");
        vm.stopPrank();
    }

    function test_InstanceAccessManager_createCoreTarget_withExistingTargetAddress() public
    {
        IAccessManaged coreTarget = new AccessManagedMock(address(ozAccessManager));
        address coreTargetAddress = address(coreTarget);

        vm.startPrank(address(instanceAccessManager));

        instanceAccessManager.createCoreTarget(coreTargetAddress, "CoreTarget1234");

        vm.expectRevert(abi.encodeWithSelector(
            IAccess.ErrorIAccessTargetExists.selector,
            coreTargetAddress,
            ShortStrings.toShortString("CoreTarget1234")));
        instanceAccessManager.createCoreTarget(coreTargetAddress, "CoreTarget5678");

        vm.stopPrank();
    }

    function test_InstanceAccessManager_createCoreTarget_withZeroTargetAddress() public
    {
        vm.startPrank(address(instanceAccessManager));
        vm.expectRevert();
        instanceAccessManager.createCoreTarget(address(0), "CoreTarget1234");
        vm.stopPrank();
    }

    function test_InstanceAccessManager_createCoreTarget_withExistingTargetName() public
    {
        IAccessManaged coreTarget1 = new AccessManagedMock(address(ozAccessManager));
        address coreTargetAddress1 = address(coreTarget1);

        IAccessManaged coreTarget2 = new AccessManagedMock(address(ozAccessManager));
        address coreTargetAddress2 = address(coreTarget2);

        vm.startPrank(address(instanceAccessManager));

        instanceAccessManager.createCoreTarget(coreTargetAddress1, "CoreTarget1234");

        vm.expectRevert(abi.encodeWithSelector(
            IAccess.ErrorIAccessTargetNameExists.selector,
            coreTargetAddress2,
            coreTargetAddress1,
            ShortStrings.toShortString("CoreTarget1234")));
        instanceAccessManager.createCoreTarget(coreTargetAddress2, "CoreTarget1234");

        vm.stopPrank();
    }

    function test_InstanceAccessManager_createCoreTarget_withEmptyTargetName() public
    {
        IAccessManaged coreTarget = new AccessManagedMock(address(ozAccessManager));
        address coreTargetAddress = address(coreTarget);

        vm.startPrank(address(instanceAccessManager));

        vm.expectRevert(abi.encodeWithSelector(
            IAccess.ErrorIAccessTargetNameEmpty.selector,
            coreTargetAddress));
        instanceAccessManager.createCoreTarget(coreTargetAddress, "");

        vm.stopPrank();
    }

    function test_InstanceAccessManager_createCoreTarget_withInvalidTargetAuthority() public
    {
        IAccessManager accessManager = new AccessManager(address(this));
        IAccessManaged coreTarget = new AccessManagedMock(address(accessManager));
        address coreTargetAddress = address(coreTarget);

        vm.startPrank(address(instanceAccessManager));

        vm.expectRevert(abi.encodeWithSelector(
            IAccess.ErrorIAccessTargetAuthorityInvalid.selector,
            coreTargetAddress,
            address(accessManager)));
        instanceAccessManager.createCoreTarget(coreTargetAddress, "CoreTarget1234");

        vm.stopPrank();
    }

    //--- Create gif target  --------------------------------------------------//

    function test_InstanceAccessManager_createGifTarget_HappyCase() public
    {
        vm.startPrank(instanceOwner);
        IRegisterable gifTarget = new SimpleAccessManagedRegisterableMock(instanceNftId, PRODUCT(), address(ozAccessManager));
        address gifTargetAddress = address(gifTarget);
        vm.stopPrank();

        vm.startPrank(address(registryService));
        registry.register(gifTarget.getInitialInfo());
        vm.stopPrank();
    
        IAccess.TargetInfo memory info = IAccess.TargetInfo({
            name: ShortStrings.toShortString("GifTarget1234"),
            ttype: IAccess.Type.Gif,
            isLocked: false,
            createdAt: TimestampLib.blockTimestamp(),
            updatedAt: TimestampLib.blockTimestamp()
        });

        vm.startPrank(address(instanceService));
        instanceAccessManager.createGifTarget(gifTargetAddress, "GifTarget1234");
        vm.stopPrank();

        assertFalse(instanceAccessManager.isTargetLocked(gifTargetAddress), "created gif target is locked");
        assertTrue(instanceAccessManager.targetExists(gifTargetAddress), "created gif target not exists");
        assertTrue(eqTargetInfo(info, instanceAccessManager.getTargetInfo(gifTargetAddress)), "created target info is invalid");
    }

    function test_InstanceAccessManager_createGifTarget_byNotInstanceService() public
    {
        IAccessManaged gifTarget = new AccessManagedMock(address(ozAccessManager));
        address gifTargetAddress = address(gifTarget);

        vm.startPrank(instanceOwner);
        vm.expectRevert(abi.encodeWithSelector(
            IAccessManaged.AccessManagedUnauthorized.selector, 
            instanceOwner));
        instanceAccessManager.createGifTarget(gifTargetAddress, "GifTarget1234");
        vm.stopPrank();
    }

    function test_InstanceAccessManager_createGifTarget_withNotRegisteredTarget() public
    {
        vm.startPrank(instanceOwner);
        IRegisterable gifTarget = new SimpleAccessManagedRegisterableMock(instanceNftId, PRODUCT(), address(ozAccessManager));
        address gifTargetAddress = address(gifTarget);
        vm.stopPrank();

        vm.startPrank(address(instanceService));
        vm.expectRevert(abi.encodeWithSelector(
            IAccess.ErrorIAccessTargetNotRegistered.selector,
            gifTargetAddress));
        instanceAccessManager.createGifTarget(gifTargetAddress, "GifTarget1234");
        vm.stopPrank();
    }

    function test_InstanceAccessManager_createGifTarget_withNotIAccessManagedTarget() public
    {
        IRegisterable gifTarget = new RegisterableMock(
            zeroNftId(), 
            instanceNftId, 
            PRODUCT(),
            false,
            instanceOwner,
            ""
        );
        address gifTargetAddress = address(gifTarget);

        vm.startPrank(address(instanceService));
        vm.expectRevert(abi.encodeWithSelector(
            IAccess.ErrorIAccessTargetNotRegistered.selector,
            gifTargetAddress));
        instanceAccessManager.createGifTarget(gifTargetAddress, "GifTarget1234");
        vm.stopPrank();
    }

    function test_InstanceAccessManager_createGifTarget_withExistingTargetAddress() public
    {
        vm.startPrank(instanceOwner);
        IRegisterable gifTarget = new SimpleAccessManagedRegisterableMock(instanceNftId, PRODUCT(), address(ozAccessManager));
        address gifTargetAddress = address(gifTarget);
        vm.stopPrank();

        vm.startPrank(address(registryService));
        registry.register(gifTarget.getInitialInfo());
        vm.stopPrank();

        vm.startPrank(address(instanceService));
        instanceAccessManager.createGifTarget(gifTargetAddress, "GifTarget1234");
        vm.expectRevert(abi.encodeWithSelector(
            IAccess.ErrorIAccessTargetExists.selector,
            gifTargetAddress,
            ShortStrings.toShortString("GifTarget1234")));
        instanceAccessManager.createGifTarget(gifTargetAddress, "GifTarget5678");
        vm.stopPrank();
    }

    function test_InstanceAccessManager_createGifTarget_withZeroTargetAddress() public
    {
        vm.startPrank(address(instanceService));
        vm.expectRevert(abi.encodeWithSelector(
            IAccess.ErrorIAccessTargetNotRegistered.selector,
            address(0)));
        instanceAccessManager.createGifTarget(address(0), "GifTarget1234");
        vm.stopPrank();
    }

    function test_InstanceAccessManager_createGifTarget_withExistingTargetName() public
    {
        vm.startPrank(instanceOwner);
        IRegisterable gifTarget1 = new SimpleAccessManagedRegisterableMock(instanceNftId, PRODUCT(), address(ozAccessManager));
        address gifTargetAddress1 = address(gifTarget1);

        IRegisterable gifTarget2 = new SimpleAccessManagedRegisterableMock(instanceNftId, PRODUCT(), address(ozAccessManager));
        address gifTargetAddress2 = address(gifTarget2);
        vm.stopPrank();

        vm.startPrank(address(registryService));
        registry.register(gifTarget1.getInitialInfo());
        registry.register(gifTarget2.getInitialInfo());
        vm.stopPrank();

        vm.startPrank(address(instanceService));

        instanceAccessManager.createGifTarget(gifTargetAddress1, "GifTarget1234");

        vm.expectRevert(abi.encodeWithSelector(
            IAccess.ErrorIAccessTargetNameExists.selector,
            gifTargetAddress2,
            gifTargetAddress1,
            ShortStrings.toShortString("GifTarget1234")));
        instanceAccessManager.createGifTarget(gifTargetAddress2, "GifTarget1234");

        vm.stopPrank();
    }

    function test_InstanceAccessManager_createGifTarget_withEmptyTargetName() public
    {
        vm.startPrank(instanceOwner);
        IRegisterable gifTarget = new SimpleAccessManagedRegisterableMock(instanceNftId, PRODUCT(), address(ozAccessManager));
        address gifTargetAddress = address(gifTarget);
        vm.stopPrank();

        vm.startPrank(address(registryService));
        registry.register(gifTarget.getInitialInfo());
        vm.stopPrank();

        vm.startPrank(address(instanceService));
        vm.expectRevert(abi.encodeWithSelector(
            IAccess.ErrorIAccessTargetNameEmpty.selector,
            gifTargetAddress));
        instanceAccessManager.createGifTarget(gifTargetAddress, "");
        vm.stopPrank();
    }

    function test_InstanceAccessManager_createGifTarget_withInvalidTargetAuthority() public
    {
        vm.startPrank(instanceOwner);
        IAccessManager accessManager = new AccessManager(address(this));
        IRegisterable gifTarget = new SimpleAccessManagedRegisterableMock(instanceNftId, PRODUCT(), address(accessManager));
        address gifTargetAddress = address(gifTarget);
        vm.stopPrank();

        vm.startPrank(address(registryService));
        registry.register(gifTarget.getInitialInfo());
        vm.stopPrank();

        vm.startPrank(address(instanceService));

        vm.expectRevert(abi.encodeWithSelector(
            IAccess.ErrorIAccessTargetAuthorityInvalid.selector,
            gifTargetAddress,
            address(accessManager)));
        instanceAccessManager.createGifTarget(gifTargetAddress, "GifTarget1234");

        vm.stopPrank();
    }

    //--- Create target  --------------------------------------------------------//

    function test_InstanceAccessManager_createTarget_HappyCase() public
    {
        IAccessManaged target = new AccessManagedMock(address(ozAccessManager));
        address targetAddress = address(target);
    
        IAccess.TargetInfo memory info = IAccess.TargetInfo({
            name: ShortStrings.toShortString("CustomTarget1234"),
            ttype: IAccess.Type.Custom,
            isLocked: false,
            createdAt: TimestampLib.blockTimestamp(),
            updatedAt: TimestampLib.blockTimestamp()
        });

        vm.startPrank(address(instance));
        instanceAccessManager.createTarget(targetAddress, "CustomTarget1234");
        vm.stopPrank();

        assertFalse(instanceAccessManager.isTargetLocked(targetAddress), "created gif target is locked");
        assertTrue(instanceAccessManager.targetExists(targetAddress), "created gif target not exists");
        assertTrue(eqTargetInfo(info, instanceAccessManager.getTargetInfo(targetAddress)), "created target info is invalid");
    }

    function test_InstanceAccessManager_createfTarget_byNotInstanceOwner() public
    {
        IAccessManaged target = new AccessManagedMock(address(ozAccessManager));
        address targetAddress = address(target);

        vm.startPrank(outsider);
        vm.expectRevert(abi.encodeWithSelector(
            IAccessManaged.AccessManagedUnauthorized.selector, 
            outsider));
        instanceAccessManager.createTarget(targetAddress, "CustomTarget1234");
        vm.stopPrank();
    }

    function test_InstanceAccessManager_createTarget_withExistingTargetAddress() public
    {
        IAccessManaged target = new AccessManagedMock(address(ozAccessManager));
        address targetAddress = address(target);

        vm.startPrank(address(instance));

        instanceAccessManager.createTarget(targetAddress, "CustomTarget1234");

        vm.expectRevert(abi.encodeWithSelector(
            IAccess.ErrorIAccessTargetExists.selector,
            targetAddress,
            ShortStrings.toShortString("CustomTarget1234")));
        instanceAccessManager.createTarget(targetAddress, "CustomTarget5678");

        vm.stopPrank();
    }

    function test_InstanceAccessManager_createTarget_withZeroTargetAddress() public
    {
        vm.startPrank(address(instance));
        vm.expectRevert();
        instanceAccessManager.createTarget(address(0), "CustomTarget1234");
        vm.stopPrank();
    }

    function test_InstanceAccessManager_createTarget_withExistingTargetName() public
    {
        IAccessManaged target1 = new AccessManagedMock(address(ozAccessManager));
        address targetAddress1 = address(target1);

        IAccessManaged target2 = new AccessManagedMock(address(ozAccessManager));
        address targetAddress2 = address(target2);

        vm.startPrank(address(instance));

        instanceAccessManager.createTarget(targetAddress1, "CustomTarget1234");

        vm.expectRevert(abi.encodeWithSelector(
            IAccess.ErrorIAccessTargetNameExists.selector,
            targetAddress2,
            targetAddress1,
            ShortStrings.toShortString("CustomTarget1234")));
        instanceAccessManager.createTarget(targetAddress2, "CustomTarget1234");

        vm.stopPrank();
    }

    function test_InstanceAccessManager_createTarget_withEmptyTargetName() public
    {
        IAccessManaged target = new AccessManagedMock(address(ozAccessManager));
        address targetAddress = address(target);

        vm.startPrank(address(instance));

        vm.expectRevert(abi.encodeWithSelector(
            IAccess.ErrorIAccessTargetNameEmpty.selector,
            targetAddress));
        instanceAccessManager.createTarget(targetAddress, "");

        vm.stopPrank();
    }

    function test_InstanceAccessManager_createTarget_withInvalidTargetAuthority() public
    {
        IAccessManager accessManager = new AccessManager(address(this));
        IAccessManaged target = new AccessManagedMock(address(accessManager));
        address targetAddress = address(target);

        vm.startPrank(address(instance));

        vm.expectRevert(abi.encodeWithSelector(
            IAccess.ErrorIAccessTargetAuthorityInvalid.selector,
            targetAddress,
            address(accessManager)));
        instanceAccessManager.createTarget(targetAddress, "CustomTarget1234");

        vm.stopPrank();
    }

    //--- Set target locked -----------------------------------------------------//

    function test_InstanceAccessManager_setTargetLocked_ToggleCoreTarget() public
    {
        vm.startPrank(address(instanceService));

        vm.expectRevert(abi.encodeWithSelector(
            IAccess.ErrorIAccessTargetTypeInvalid.selector, 
            ShortStrings.toShortString("Instance"),
            IAccess.Type.Core));
        instanceAccessManager.setTargetLockedByService("Instance", true);

        vm.expectRevert(abi.encodeWithSelector(
            IAccess.ErrorIAccessTargetTypeInvalid.selector, 
            ShortStrings.toShortString("Instance"),
            IAccess.Type.Core));
        instanceAccessManager.setTargetLockedByService("Instance", false);

        vm.stopPrank();
    }

    function test_InstanceAccessManager_setTargetLocked_ToggleGifTarget() public
    {
        vm.startPrank(instanceOwner);
        IRegisterable gifTarget = new SimpleAccessManagedRegisterableMock(instanceNftId, PRODUCT(), address(ozAccessManager));
        address gifTargetAddress = address(gifTarget);
        vm.stopPrank();

        vm.startPrank(address(registryService));
        registry.register(gifTarget.getInitialInfo());
        vm.stopPrank();

        vm.startPrank(address(instanceService));
        instanceAccessManager.createGifTarget(gifTargetAddress, "GifTarget1234");

        instanceAccessManager.setTargetLockedByService("GifTarget1234", true);

        assertTrue(instanceAccessManager.isTargetLocked(gifTargetAddress), "gif target is not locked");

        instanceAccessManager.setTargetLockedByService("GifTarget1234", false);
        vm.stopPrank();

        assertFalse(instanceAccessManager.isTargetLocked(gifTargetAddress), "gif target is locked");
    }

    function test_InstanceAccessManager_setTargetLocked_ToggleCustomTargetHappyCase() public
    {
        IAccessManaged customTarget = new AccessManagedMock(address(ozAccessManager));
        address customTargetAddress = address(customTarget);

        vm.startPrank(address(instance));
        instanceAccessManager.createTarget(customTargetAddress, "CustomTarget1234");
        vm.stopPrank();

        vm.startPrank(address(instanceService));
        instanceAccessManager.setTargetLockedByService("CustomTarget1234", true);

        assertTrue(instanceAccessManager.isTargetLocked(customTargetAddress), "custom target is not locked");

        instanceAccessManager.setTargetLockedByService("CustomTarget1234", false);
        vm.stopPrank();

        assertFalse(instanceAccessManager.isTargetLocked(customTargetAddress), "custom target is locked");
    }

    function test_InstanceAccessManager_setTargetLocked_withNonExitingTarget() public
    {
        vm.startPrank(address(instanceService));
        vm.expectRevert(abi.encodeWithSelector(
            IAccess.ErrorIAccessTargetDoesNotExist.selector, 
            ShortStrings.toShortString("NonExistingTarget")));
        instanceAccessManager.setTargetLockedByService("NonExistingTarget", true);
        vm.stopPrank();
    }

    //--- Instance NFT interception ------------------------------------------//

    function test_InstanceAccessManager_instanceNftMint_HappyCase() public 
    {
        // create new instance setup
        AccessManagerUpgradeableInitializeable newOzAccessManager = new AccessManagerUpgradeableInitializeable();
        newOzAccessManager.initialize(address(this));

        Instance newInstance = new Instance();
        newInstance.initialize(address(newOzAccessManager), registryAddress, outsider);

        InstanceAccessManager newInstanceAccessManager = new InstanceAccessManager();
        newOzAccessManager.grantRole(ADMIN_ROLE().toInt(), address(newInstanceAccessManager), 0);
        newInstanceAccessManager.initialize(address(newInstance));
        newInstance.setInstanceAccessManager(newInstanceAccessManager);

        assertFalse(newInstanceAccessManager.hasRole(INSTANCE_OWNER_ROLE(), outsider), "instance owner has role before instance nft is minted");
        assertEq(newInstanceAccessManager.roleMembers(INSTANCE_OWNER_ROLE()), 0, "roleMembers(INSTANCE_OWNER_ROLE) != 0");

        vm.startPrank(address(registry));
        uint256 tokenId = chainNft.mint(outsider, address(newInstance), "");
        vm.stopPrank();

        assertTrue(outsider == chainNft.ownerOf(tokenId), "instance owner is not instance nft owner after minting");
        assertTrue(newInstanceAccessManager.hasRole(INSTANCE_OWNER_ROLE(), outsider), "instance owner has no role after minting");
        assertEq(newInstanceAccessManager.roleMembers(INSTANCE_OWNER_ROLE()), 1, "roleMembers(INSTANCE_OWNER_ROLE) != 1");
    }

    function test_InstanceAccessManager_instanceNftTransfer_HappyCase() public 
    {
        assertEq(registry.ownerOf(instanceNftId), instanceOwner);
        assertTrue(instanceAccessManager.hasRole(INSTANCE_OWNER_ROLE(), instanceOwner));
        assertFalse(instanceAccessManager.hasRole(INSTANCE_OWNER_ROLE(), outsider));
        assertEq(instanceAccessManager.roleMembers(INSTANCE_OWNER_ROLE()), 1, "roleMembers(INSTANCE_OWNER_ROLE) != 1 #3");

        vm.startPrank(instanceOwner);

        chainNft.approve(outsider, instanceNftId.toInt());
        chainNft.transferFrom(instanceOwner, outsider, instanceNftId.toInt());

        vm.stopPrank();

        assertEq(registry.ownerOf(instanceNftId), outsider, "instance nft owner is not new owner");
        assertFalse(instanceAccessManager.hasRole(INSTANCE_OWNER_ROLE(), instanceOwner));
        assertTrue(instanceAccessManager.hasRole(INSTANCE_OWNER_ROLE(), outsider));
        assertEq(instanceAccessManager.roleMembers(INSTANCE_OWNER_ROLE()), 1, "roleMembers(INSTANCE_OWNER_ROLE) != 1 #4");        
    }

    //--- Set core target function role ---------------------------------------//

    /*function test_InstanceAccessManager_setCoreTargetFunctionRole_setCoreTargetCoreRoleHappyCase() public
    function test_InstanceAccessManager_setCoreTargetFunctionRole_setCoreTargetGifRoleHappyCase() public
    function test_InstanceAccessManager_setCoreTargetFunctionRole_setCoreTargetCustomRole() public
    function test_InstanceAccessManager_setCoreTargetFunctionRole_setCoreTargetNonExistingRole() public

    function test_InstanceAccessManager_setCoreTargetFunctionRole_setGifTargetCoreRole() public
    function test_InstanceAccessManager_setCoreTargetFunctionRole_setGifTargetGifRoleHappyCase() public
    function test_InstanceAccessManager_setCoreTargetFunctionRole_setGifTargetCustomRoleHappyCase() public
    function test_InstanceAccessManager_setCoreTargetFunctionRole_setGifTargetNonExistingRole() public

    function test_InstanceAccessManager_setCoreTargetFunctionRole_setCustomTargetCoreRole() public
    function test_InstanceAccessManager_setCoreTargetFunctionRole_setCustomTargetGifRole() public
    function test_InstanceAccessManager_setCoreTargetFunctionRole_setCustomTargetCustomRole() public
    function test_InstanceAccessManager_setCoreTargetFunctionRole_setCustomTargetNonExistingRole() public

    function test_InstanceAccessManager_setCoreTargetFunctionRole_setNonExitingTargetCoreRole() public
    function test_InstanceAccessManager_setCoreTargetFunctionRole_setNonExitingTargetGifRole() public
    function test_InstanceAccessManager_setCoreTargetFunctionRole_setNonExitingTargetCustomRole() public
    function test_InstanceAccessManager_setCoreTargetFunctionRole_setNonExitingTargetNonExistingRole() public*/


    //--- Set target function role ---------------------------------------//

    /*function test_InstanceAccessManager_setTargetFunctionRole_setCoreTargetCoreRoleHappyCase() public
    function test_InstanceAccessManager_setCoreTargetFunctionRole_setCoreTargetGifRoleHappyCase() public
    function test_InstanceAccessManager_setCoreTargetFunctionRole_setCoreTargetCustomRole() public 

    function test_InstanceAccessManager_setCoreTargetFunctionRole_setGifTargetCoreRole() public
    function test_InstanceAccessManager_setCoreTargetFunctionRole_setGifTargetGifRole() public
    function test_InstanceAccessManager_setCoreTargetFunctionRole_setGifTargetCustomRole() public

    function test_InstanceAccessManager_setCoreTargetFunctionRole_setCustomTargetCoreRole() public
    function test_InstanceAccessManager_setCoreTargetFunctionRole_setCustomTargetGifRoleHappyCase() public
    function test_InstanceAccessManager_setCoreTargetFunctionRole_setCustomTargetCustomRoleHappyCase() public*/

}