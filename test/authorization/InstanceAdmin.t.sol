// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {console} from "../../lib/forge-std/src/Script.sol";

import {GifTest} from "../base/GifTest.sol";
import {InstanceAdminNew} from "../../contracts/instance/InstanceAdminNew.sol";
import {InstanceAuthorizationV3} from "../../contracts/instance/InstanceAuthorizationV3.sol";
import {IModuleAuthorization} from "../../contracts/authorization/IModuleAuthorization.sol";
import {InstanceLinkedComponent} from "../../contracts/shared/InstanceLinkedComponent.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {NftId, NftIdLib} from "../../contracts/type/NftId.sol";
import {ObjectType} from "../../contracts/type/ObjectType.sol";
import {BUNDLE, COMPONENT, DISTRIBUTION, ORACLE, POOL, PRODUCT, POLICY, RISK, REQUEST, SERVICE, STAKING} from "../../contracts/type/ObjectType.sol";
import {RoleId, PRODUCT_OWNER_ROLE, POOL_OWNER_ROLE, ORACLE_OWNER_ROLE, DISTRIBUTION_OWNER_ROLE} from "../../contracts/type/RoleId.sol";

contract TestInstanceAdmin is
    GifTest
{
    InstanceAuthorizationV3 public instanceAuthz;
    InstanceAdminNew public instanceAdminMaster;

    function setUp() public override {
        super.setUp();

        instanceAuthz = new InstanceAuthorizationV3();
        instanceAdminMaster = new InstanceAdminNew(instanceAuthz);
        instanceAdminMaster.initialize(instanceAuthz);
    }

    function test_instanceAdminSetup() public {
        vm.startPrank(instanceOwner);
        InstanceAdminNew clonedAdmin = _cloneNewInstanceAdmin();
        vm.stopPrank();

        _printAuthz(clonedAdmin, "instance");
        assertTrue(true, "something is wrong");
    }

    function _cloneNewInstanceAdmin() internal returns (InstanceAdminNew clonedInstanceAdmin) {
        clonedInstanceAdmin = InstanceAdminNew(
            Clones.clone(
                address(instanceAdminMaster)));

        clonedInstanceAdmin.initialize(
            instanceAuthz);

        clonedInstanceAdmin.initializeInstanceAuthorization(address(instance));
    }
}