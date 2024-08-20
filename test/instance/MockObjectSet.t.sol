// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {console} from "../../lib/forge-std/src/Script.sol";
import {GifTest} from "../base/GifTest.sol";
import {NftId, NftIdLib} from "../../contracts/type/NftId.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {MockAuthority} from "../mock/MockAuthority.sol";
import {MockObjectSet} from "../mock/MockObjectSet.sol";

contract MockObjectSetTest is GifTest {

    MockObjectSet public masterObjectSet;
    MockObjectSet public objectSet;

    // FIX ME
    //MockAuthority public authority;

    function setUp() public override {
        super.setUp();

        // deploy master
        masterObjectSet = new MockObjectSet();

        // create clone
        objectSet = MockObjectSet(Clones.clone(address(masterObjectSet)));

        // create authority mock
        //authority = new MockAuthority();

        // initialize clone
        objectSet.initialize(instance.getInstanceAdmin().authority(), address(instance.getRegistry()), address(instance));
    }


    function test_MockObjectSetSetup() public {

        // solhint-disable no-console
        console.log("====================");
        //console.log("authority", address(authority));
        console.log("registry address", address(registry));
        console.log("instance nft id", address(instance));
        console.log("instanceReader", address(instanceReader));
        console.log("masterObjectSet", address(masterObjectSet));
        console.log("objectSet", address(objectSet));
        // solhint-enable

        assertTrue(address(masterObjectSet) != address(0), "master object manager zero");
        assertTrue(address(objectSet) != address(0), "object manager zero");
        assertTrue(address(objectSet) != address(masterObjectSet), "object manager and master object manager identical");

        assertEq(objectSet.authority(), instance.authority(), "unexpected authority");
        assertEq(address(objectSet.getRegistry()), address(registry), "unexpected registry");

        NftId fakeComponentNftId = NftIdLib.toNftId(13);
        NftId fakeObjectNftId = NftIdLib.toNftId(17);
        assertEq(objectSet.objects(fakeComponentNftId), 0, "> 0 objects");
        assertFalse(objectSet.contains(fakeComponentNftId, fakeObjectNftId), "contains fake object");
    }


    function test_MockObjectSetAddObjectHappyCase1() public {

        NftId componentNftId = NftIdLib.toNftId(1);
        NftId objectNftId = NftIdLib.toNftId(42);

        objectSet.add(componentNftId, objectNftId);

        assertEq(objectSet.objects(componentNftId), 1, "!= 1 objects");
        assertTrue(objectSet.contains(componentNftId, objectNftId), "doesn't contain added object");
        assertEq(objectSet.getObject(componentNftId, 0).toInt(), objectNftId.toInt(), "unexpected object id");

        assertEq(objectSet.activeObjects(componentNftId), 1, "!= 1 active objects");
        assertTrue(objectSet.isActive(componentNftId, objectNftId), "added object isn't active");
        assertEq(objectSet.getActiveObject(componentNftId, 0).toInt(), objectNftId.toInt(), "unexpected object id");
    }


    function test_MockObjectSetAddAndDeactivateSingle() public {

        NftId componentNftId = NftIdLib.toNftId(1);
        NftId objectNftId = NftIdLib.toNftId(42);

        objectSet.add(componentNftId, objectNftId);
        objectSet.deactivate(componentNftId, objectNftId);

        assertEq(objectSet.objects(componentNftId), 1, "!= 1 objects");
        assertTrue(objectSet.contains(componentNftId, objectNftId), "doesn't contain added object");
        assertEq(objectSet.getObject(componentNftId, 0).toInt(), objectNftId.toInt(), "unexpected object id");

        assertEq(objectSet.activeObjects(componentNftId), 0, "!= 0 active objects");
        assertFalse(objectSet.isActive(componentNftId, objectNftId), "added object is active");
    }


    function test_MockObjectSetAddManyAndDeactivateSome() public {

        NftId componentNftId = NftIdLib.toNftId(1);
        NftId objectNftId10 = NftIdLib.toNftId(10);
        NftId objectNftId11 = NftIdLib.toNftId(11);
        NftId objectNftId12 = NftIdLib.toNftId(12);
        NftId objectNftId13 = NftIdLib.toNftId(13);
        NftId objectNftId14 = NftIdLib.toNftId(14);
        NftId objectNftId15 = NftIdLib.toNftId(15);

        objectSet.add(componentNftId, objectNftId10);
        objectSet.add(componentNftId, objectNftId11);
        objectSet.add(componentNftId, objectNftId12);
        objectSet.add(componentNftId, objectNftId13); // deactivate
        objectSet.add(componentNftId, objectNftId14);
        objectSet.add(componentNftId, objectNftId15); // deactivate

        objectSet.deactivate(componentNftId, objectNftId13);
        objectSet.deactivate(componentNftId, objectNftId15);

        assertEq(objectSet.objects(componentNftId), 6, "unexpected number of objects");
        assertEq(objectSet.getObject(componentNftId, 0).toInt(), objectNftId10.toInt(), "unexpected object (all) id for idx 0");
        assertEq(objectSet.getObject(componentNftId, 3).toInt(), objectNftId13.toInt(), "unexpected object (all) id for idx 3");
        assertEq(objectSet.getObject(componentNftId, 5).toInt(), objectNftId15.toInt(), "unexpected object (all) id for idx 5");

        assertEq(objectSet.activeObjects(componentNftId), 4, "unexpected number of active objects");
        assertTrue(objectSet.isActive(componentNftId, objectNftId10), "deactivated 10 object is active");
        assertTrue(objectSet.isActive(componentNftId, objectNftId11), "deactivated 11 object is active");
        assertTrue(objectSet.isActive(componentNftId, objectNftId12), "deactivated 12 object is active");
        assertFalse(objectSet.isActive(componentNftId, objectNftId13), "deactivated 13 object is active");
        assertTrue(objectSet.isActive(componentNftId, objectNftId14), "deactivated 14 object is active");
        assertFalse(objectSet.isActive(componentNftId, objectNftId15), "deactivated 15 object is active");
        assertEq(objectSet.getObject(componentNftId, 0).toInt(), objectNftId10.toInt(), "unexpected object id (active) for idx 0");
    }

    // TODO: fix me
    function skip_test_MockObjectSetAttemptDoubleInitialization() public {
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        objectSet.initialize(instance.getInstanceAdmin().authority(), address(instance.getRegistry()), address(instance));
    }
}
