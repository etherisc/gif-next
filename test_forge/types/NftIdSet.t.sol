// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Test, console} from "../../lib/forge-std/src/Test.sol";

import {NftId, toNftId, zeroNftId} from "../../contracts/types/NftId.sol";
import {LibNftIdSet} from "../../contracts/types/NftIdSet.sol";
import {MockObjectManager} from "../mock/MockObjectManager.sol";
import {TestGifBase} from "../base/TestGifBase.sol";

contract NftIdSetTest is TestGifBase {

    LibNftIdSet.Set internal set;
    mapping(NftId setId => LibNftIdSet.Set objects) internal sets;
    MockObjectManager public objectManager;

    function setUp() public override {
        super.setUp();

        Dummy dummyAuthority = new Dummy();
        MockObjectManager master = new MockObjectManager();

        objectManager = MockObjectManager(Clones.clone(address(master)));
        objectManager.initialize(address(instance));
    }

    function test_addToSetHappyCase() public {
        NftId id = toNftId(42);

        assertEq(LibNftIdSet.size(set), 0, "set size not 0");
        assertFalse(LibNftIdSet.contains(set, id), "id in empty set");

        LibNftIdSet.add(set, id);

        assertEq(LibNftIdSet.size(set), 1, "set size not 1");
        assertTrue(LibNftIdSet.contains(set, id), "id not in set");
    }

    function test_addToSetsHappyCase() public {
        NftId setId = toNftId(7);
        NftId objectId = toNftId(42);

        assertEq(LibNftIdSet.size(sets[setId]), 0, "set size not 0");
        assertFalse(LibNftIdSet.contains(sets[setId], objectId), "id in empty set");

        LibNftIdSet.add(sets[setId], objectId);

        assertEq(LibNftIdSet.size(sets[setId]), 1, "set size not 1");
        assertTrue(LibNftIdSet.contains(sets[setId], objectId), "id not in set");
    }

    function test_addToObjectManagerHappyCase() public {
        NftId setId = toNftId(7);
        NftId objectId = toNftId(42);

        assertEq(objectManager.objects(setId), 0, "set size not 0");
        assertFalse(objectManager.contains(setId, objectId), "id in empty set");

        objectManager.add(setId, objectId);

        assertEq(objectManager.objects(setId), 1, "set size not 1");
        assertTrue(objectManager.contains(setId, objectId), "id not in set");
    }
}

contract Dummy { }
