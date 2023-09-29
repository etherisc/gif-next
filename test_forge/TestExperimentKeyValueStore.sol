// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {Test} from "../lib/forge-std/src/Test.sol";
import {console} from "../lib/forge-std/src/Script.sol";

import {IBundle} from "../contracts/experiment/kvstore/IBundle.sol";
import {KeyValueStore} from "../contracts/experiment/kvstore/KeyValueStore.sol";
import {BundleModuleStore} from "../contracts/experiment/kvstore/BundleModuleStore.sol";

contract TestExperimentRequireRevert is Test {

    BundleModuleStore public bm;
    KeyValueStore public kv;

    function setUp() external {
        bm = new BundleModuleStore();
        kv = bm.getStore();
    }

    function testExperimentBundleModuleStoreCreate() public returns (bytes32 key) {
        IBundle.BundleInfo memory bi = bm.createBundleInfo(654321, 10**(5+6), kv.s2b("some filter"));
        key = bm.createBundleInfo(bi);

        IBundle.BundleInfo memory biLoaded = bm.getBundleInfo(key);
        assertEq(bi.nftId.toInt(), biLoaded.nftId.toInt(), "bundle ids different");
    }

    function testExperimentBundleModuleStoreUpdate() public {
        bytes32 key = testExperimentBundleModuleStoreCreate();

        IBundle.BundleInfo memory biInitial = bm.getBundleInfo(key);
        assertEq(biInitial.lockedAmount, 0, "locked amount not 0");

        biInitial.lockedAmount = 42;
        bm.updateBundleInfo(biInitial);

        IBundle.BundleInfo memory biUpdated = bm.getBundleInfo(key);
        assertEq(biUpdated.lockedAmount, 42, "locked amount not updated (42)");
    }
}