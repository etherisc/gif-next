// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {console} from "../lib/forge-std/src/Script.sol";
import {TestGifBase} from "./base/TestGifBase.sol";
import {NftId, toNftId, NftIdLib} from "../contracts/types/NftId.sol";
import {PRODUCT_OWNER_ROLE, POOL_OWNER_ROLE, DISTRIBUTION_OWNER_ROLE} from "../contracts/types/RoleId.sol";
import {Pool} from "../contracts/components/Pool.sol";
import {IRegistry} from "../contracts/registry/IRegistry.sol";
import {IBundle} from "../contracts/instance/module/IBundle.sol";
import {ISetup} from "../contracts/instance/module/ISetup.sol";
import {Fee, FeeLib} from "../contracts/types/Fee.sol";
import {UFixedLib} from "../contracts/types/UFixed.sol";

contract TestPool is TestGifBase {
    using NftIdLib for NftId;

    function test_Pool_setFees() public {
        vm.startPrank(instanceOwner);
        instanceAccessManager.grantRole(POOL_OWNER_ROLE().toInt(), poolOwner, 0);
        vm.stopPrank();

        vm.startPrank(poolOwner);

        pool = new Pool(
            address(registry),
            instanceNftId,
            address(token),
            false,
            false,
            UFixedLib.toUFixed(1),
            FeeLib.zeroFee(),
            FeeLib.zeroFee(),
            FeeLib.zeroFee(),
            poolOwner
        );

        NftId poolNftId = poolService.register(address(pool));

        ISetup.PoolSetupInfo memory poolSetupInfo = instanceReader.getPoolSetupInfo(poolNftId);
        Fee memory poolFee = poolSetupInfo.poolFee;
        Fee memory stakingFee = poolSetupInfo.stakingFee;
        Fee memory performanceFee = poolSetupInfo.performanceFee;
        assertEq(poolFee.fractionalFee.toInt(), 0, "pool fee not 0");
        assertEq(poolFee.fixedFee, 0, "pool fee not 0");
        assertEq(stakingFee.fractionalFee.toInt(), 0, "staking fee not 0");
        assertEq(stakingFee.fixedFee, 0, "staking fee not 0");
        assertEq(performanceFee.fractionalFee.toInt(), 0, "performance fee not 0");
        assertEq(performanceFee.fixedFee, 0, "performance fee not 0");
        
        Fee memory newPoolFee = FeeLib.toFee(UFixedLib.toUFixed(111,0), 222);
        Fee memory newStakingFee = FeeLib.toFee(UFixedLib.toUFixed(333,0), 444);
        Fee memory newPerformanceFee = FeeLib.toFee(UFixedLib.toUFixed(555,0), 666);

        pool.setFees(newPoolFee, newStakingFee, newPerformanceFee);

        poolSetupInfo = instanceReader.getPoolSetupInfo(poolNftId);
        poolFee = poolSetupInfo.poolFee;
        stakingFee = poolSetupInfo.stakingFee;
        performanceFee = poolSetupInfo.performanceFee;
        assertEq(poolFee.fractionalFee.toInt(), 111, "pool fee not 111");
        assertEq(poolFee.fixedFee, 222, "pool fee not 222");
        assertEq(stakingFee.fractionalFee.toInt(), 333, "staking fee not 333");
        assertEq(stakingFee.fixedFee, 444, "staking fee not 444");
        assertEq(performanceFee.fractionalFee.toInt(), 555, "performance fee not 555");
        assertEq(performanceFee.fixedFee, 666, "performance fee not 666");

        vm.stopPrank();
    }

    function test_Pool_createBundle() public {
        vm.startPrank(instanceOwner);
        instanceAccessManager.grantRole(POOL_OWNER_ROLE().toInt(), poolOwner, 0);
        vm.stopPrank();

        vm.startPrank(poolOwner);

        pool = new Pool(
            address(registry),
            instanceNftId,
            address(token),
            false,
            false,
            UFixedLib.toUFixed(1),
            FeeLib.zeroFee(),
            FeeLib.zeroFee(),
            FeeLib.zeroFee(),
            poolOwner
        );

        NftId poolNftId = poolService.register(address(pool));

        NftId bundleNftId = pool.createBundle(
            FeeLib.zeroFee(), 
            10000, 
            604800, 
            ""
        );

        assertTrue(!bundleNftId.eqz(), "bundle nft id is zero");
    }

    function test_Pool_setBundleFee() public {
        vm.startPrank(instanceOwner);
        instanceAccessManager.grantRole(POOL_OWNER_ROLE().toInt(), poolOwner, 0);
        vm.stopPrank();

        vm.startPrank(poolOwner);

        pool = new Pool(
            address(registry),
            instanceNftId,
            address(token),
            false,
            false,
            UFixedLib.toUFixed(1),
            FeeLib.zeroFee(),
            FeeLib.zeroFee(),
            FeeLib.zeroFee(),
            poolOwner
        );

        NftId poolNftId = poolService.register(address(pool));

        NftId bundleNftId = pool.createBundle(
            FeeLib.zeroFee(), 
            10000, 
            604800, 
            ""
        );

        Fee memory fee = FeeLib.toFee(UFixedLib.toUFixed(111,0), 222);
        pool.setBundleFee(bundleNftId, fee);

        IBundle.BundleInfo memory bundleInfo = instanceReader.getBundleInfo(bundleNftId);
        Fee memory bundleFee = bundleInfo.fee;
        assertEq(bundleFee.fractionalFee.toInt(), 111, "bundle fee not 111");
        assertEq(bundleFee.fixedFee, 222, "bundle fee not 222");

        vm.stopPrank();
    }

}
