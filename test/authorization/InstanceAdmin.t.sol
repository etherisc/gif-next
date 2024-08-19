// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {console} from "../../lib/forge-std/src/Script.sol";

import {AccessManagerCloneable} from "../../contracts/authorization/AccessManagerCloneable.sol";
import {GifTest} from "../base/GifTest.sol";
import {InstanceAdmin} from "../../contracts/instance/InstanceAdmin.sol";
import {InstanceAuthorizationV3} from "../../contracts/instance/InstanceAuthorizationV3.sol";
import {InstanceLinkedComponent} from "../../contracts/shared/InstanceLinkedComponent.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {NftId, NftIdLib} from "../../contracts/type/NftId.sol";
import {ObjectType} from "../../contracts/type/ObjectType.sol";
import {BUNDLE, COMPONENT, DISTRIBUTION, ORACLE, POOL, PRODUCT, POLICY, RISK, REQUEST, SERVICE, STAKING} from "../../contracts/type/ObjectType.sol";
import {RoleId} from "../../contracts/type/RoleId.sol";
import {VersionPartLib} from "../../contracts/type/Version.sol";


contract TestInstanceAdminMockInstance {
    address public authority;

    constructor(address auth) {
        authority = auth;
    }
}


contract TestInstanceAdmin is
    GifTest
{
    // address public someInstanceAuthz;
    InstanceAdmin public someInstanceAdmin;
    AccessManagerCloneable public someAccessManager;

    function setUp() public override {
        super.setUp();

        someAccessManager = AccessManagerCloneable(
            Clones.clone(instance.authority()));
        
        someInstanceAdmin = InstanceAdmin(
            Clones.clone(
                address(instance.getInstanceAdmin())));

        someInstanceAdmin.initialize(
            someAccessManager,
            instance.getRegistry(),
            instance.getRelease());
    }

    function test_instanceAdminSetup() public {
        _printAuthz(someInstanceAdmin, "instance");
        assertTrue(true, "something is wrong");
    }
}