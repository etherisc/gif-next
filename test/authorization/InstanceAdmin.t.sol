// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {console} from "../../lib/forge-std/src/Script.sol";

import {AccessManagerCloneable} from "../../contracts/authorization/AccessManagerCloneable.sol";
import {GifTest} from "../base/GifTest.sol";
import {InstanceAdmin} from "../../contracts/instance/InstanceAdmin.sol";
import {InstanceAuthorizationV3} from "../../contracts/instance/InstanceAuthorizationV3.sol";
import {IModuleAuthorization} from "../../contracts/authorization/IModuleAuthorization.sol";
import {InstanceLinkedComponent} from "../../contracts/shared/InstanceLinkedComponent.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {NftId, NftIdLib} from "../../contracts/type/NftId.sol";
import {ObjectType} from "../../contracts/type/ObjectType.sol";
import {BUNDLE, COMPONENT, DISTRIBUTION, ORACLE, POOL, PRODUCT, POLICY, RISK, REQUEST, SERVICE, STAKING} from "../../contracts/type/ObjectType.sol";
import {RoleId} from "../../contracts/type/RoleId.sol";

contract TestInstanceAdmin is
    GifTest
{
    AccessManagerCloneable public someAccessManager;
    InstanceAuthorizationV3 public someInstanceAuthz;
    InstanceAdmin public someInstanceAdminMaster;

    function setUp() public override {
        super.setUp();

        someAccessManager = new AccessManagerCloneable();
        someInstanceAuthz = new InstanceAuthorizationV3();
        someInstanceAdminMaster = new InstanceAdmin(someInstanceAuthz);
        someAccessManager = AccessManagerCloneable(someInstanceAdminMaster.authority());
    }

    function test_instanceAdminSetup() public {
        vm.startPrank(instanceOwner);
        InstanceAdmin clonedAdmin = _cloneNewInstanceAdmin();
        vm.stopPrank();

        _printAuthz(clonedAdmin, "instance");
        assertTrue(true, "something is wrong");
    }

    function _cloneNewInstanceAdmin() internal returns (InstanceAdmin clonedInstanceAdmin) {
        clonedInstanceAdmin = InstanceAdmin(
            Clones.clone(
                address(someInstanceAdminMaster)));

        // create OZ AccessManager and assign admin role to clonedInstanceAdmin
        AccessManagerCloneable ozAccessManager = new AccessManagerCloneable();
        ozAccessManager.initialize(address(clonedInstanceAdmin));

        clonedInstanceAdmin.initialize(
            ozAccessManager,
            someInstanceAuthz);

        clonedInstanceAdmin.initializeInstanceAuthorization(
            address(instance));
    }
}