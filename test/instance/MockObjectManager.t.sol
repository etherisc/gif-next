// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {console} from "../../lib/forge-std/src/Script.sol";
import {TestGifBase} from "../base/TestGifBase.sol";
import {NftId, toNftId, NftIdLib} from "../../contracts/type/NftId.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {MockAuthority} from "../mock/MockAuthority.sol";
import {MockObjectManager} from "../mock/MockObjectManager.sol";

contract MockObjectManagerTest is TestGifBase {

    MockObjectManager public masterObjectManager;
    MockObjectManager public objectManager;

    // FIX ME
    //MockAuthority public authority;

    function setUp() public override {
        super.setUp();

        // deploy master
        masterObjectManager = new MockObjectManager();

        // create clone
        objectManager = MockObjectManager(Clones.clone(address(masterObjectManager)));

        // create authority mock
        //authority = new MockAuthority();

        // initialize clone
        objectManager.initialize(address(instance));
    }


    function test_MockObjectManagerSetup() public {

        // solhint-disable no-console
        console.log("====================");
        //console.log("authority", address(authority));
        console.log("registry address", address(registry));
        console.log("instance nft id", address(instance));
        console.log("instanceReader", address(instanceReader));
        console.log("masterObjectManager", address(masterObjectManager));
        console.log("objectManager", address(objectManager));
        // solhint-enable

        assertTrue(address(masterObjectManager) != address(0), "master object manager zero");
        assertTrue(address(objectManager) != address(0), "object manager zero");
        assertTrue(address(objectManager) != address(masterObjectManager), "object manager and master object manager identical");

        assertEq(objectManager.authority(), instance.authority(), "unexpected authority");
        assertEq(address(objectManager.getRegistry()), address(registry), "unexpected registry");

        NftId fakeComponentNftId = toNftId(13);
        NftId fakeObjectNftId = toNftId(17);
        assertEq(objectManager.objects(fakeComponentNftId), 0, "> 0 objects");
        assertFalse(objectManager.contains(fakeComponentNftId, fakeObjectNftId), "contains fake object");
    }


    function test_MockObjectManagerAddObjectHappyCase1() public {

        NftId componentNftId = toNftId(1);
        NftId objectNftId = toNftId(42);

        objectManager.add(componentNftId, objectNftId);

        assertEq(objectManager.objects(componentNftId), 1, "!= 1 objects");
        assertTrue(objectManager.contains(componentNftId, objectNftId), "doesn't contain added object");
        assertEq(objectManager.getObject(componentNftId, 0).toInt(), objectNftId.toInt(), "unexpected object id");

        assertEq(objectManager.activeObjects(componentNftId), 1, "!= 1 active objects");
        assertTrue(objectManager.isActive(componentNftId, objectNftId), "added object isn't active");
        assertEq(objectManager.getActiveObject(componentNftId, 0).toInt(), objectNftId.toInt(), "unexpected object id");
    }


    function test_MockObjectManagerAddAndDeactivateSingle() public {

        NftId componentNftId = toNftId(1);
        NftId objectNftId = toNftId(42);

        objectManager.add(componentNftId, objectNftId);
        objectManager.deactivate(componentNftId, objectNftId);

        assertEq(objectManager.objects(componentNftId), 1, "!= 1 objects");
        assertTrue(objectManager.contains(componentNftId, objectNftId), "doesn't contain added object");
        assertEq(objectManager.getObject(componentNftId, 0).toInt(), objectNftId.toInt(), "unexpected object id");

        assertEq(objectManager.activeObjects(componentNftId), 0, "!= 0 active objects");
        assertFalse(objectManager.isActive(componentNftId, objectNftId), "added object is active");
    }


    function test_MockObjectManagerAddManyAndDeactivateSome() public {

        NftId componentNftId = toNftId(1);
        NftId objectNftId10 = toNftId(10);
        NftId objectNftId11 = toNftId(11);
        NftId objectNftId12 = toNftId(12);
        NftId objectNftId13 = toNftId(13);
        NftId objectNftId14 = toNftId(14);
        NftId objectNftId15 = toNftId(15);

        objectManager.add(componentNftId, objectNftId10);
        objectManager.add(componentNftId, objectNftId11);
        objectManager.add(componentNftId, objectNftId12);
        objectManager.add(componentNftId, objectNftId13); // deactivate
        objectManager.add(componentNftId, objectNftId14);
        objectManager.add(componentNftId, objectNftId15); // deactivate

        objectManager.deactivate(componentNftId, objectNftId13);
        objectManager.deactivate(componentNftId, objectNftId15);

        assertEq(objectManager.objects(componentNftId), 6, "unexpected number of objects");
        assertEq(objectManager.getObject(componentNftId, 0).toInt(), objectNftId10.toInt(), "unexpected object (all) id for idx 0");
        assertEq(objectManager.getObject(componentNftId, 3).toInt(), objectNftId13.toInt(), "unexpected object (all) id for idx 3");
        assertEq(objectManager.getObject(componentNftId, 5).toInt(), objectNftId15.toInt(), "unexpected object (all) id for idx 5");

        assertEq(objectManager.activeObjects(componentNftId), 4, "unexpected number of active objects");
        assertTrue(objectManager.isActive(componentNftId, objectNftId10), "deactivated 10 object is active");
        assertTrue(objectManager.isActive(componentNftId, objectNftId11), "deactivated 11 object is active");
        assertTrue(objectManager.isActive(componentNftId, objectNftId12), "deactivated 12 object is active");
        assertFalse(objectManager.isActive(componentNftId, objectNftId13), "deactivated 13 object is active");
        assertTrue(objectManager.isActive(componentNftId, objectNftId14), "deactivated 14 object is active");
        assertFalse(objectManager.isActive(componentNftId, objectNftId15), "deactivated 15 object is active");
        assertEq(objectManager.getObject(componentNftId, 0).toInt(), objectNftId10.toInt(), "unexpected object id (active) for idx 0");
    }

    function test_MockObjectManagerAttemptDoubleInitialization() public {
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        objectManager.initialize(address(instance));
    }
}
