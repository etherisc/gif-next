// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {console} from "../lib/forge-std/src/Test.sol";

import {TestGifBase} from "./base/TestGifBase.sol";
import {NftId, NftIdLib} from "../contracts/types/NftId.sol";
import {POOL_OWNER_ROLE} from "../contracts/types/RoleId.sol";
import {Pool} from "../contracts/components/Pool.sol";
import {IBundle} from "../contracts/instance/module/IBundle.sol";
import {ISetup} from "../contracts/instance/module/ISetup.sol";
import {Fee, FeeLib} from "../contracts/types/Fee.sol";
import {UFixedLib} from "../contracts/types/UFixed.sol";
import {SimplePool} from "./mock/SimplePool.sol";

contract TestPool is TestGifBase {
    using NftIdLib for NftId;

    function test_Pool_contractLocations() public {
        pool = new SimplePool(
            address(registry),
            instanceNftId,
            address(token),
            false,
            false,
            UFixedLib.toUFixed(1),
            UFixedLib.toUFixed(1),
            poolOwner
        );

        bytes32 locationHash = getLocationHash("gif-next.contracts.component.Pool.sol");
        assertEq(locationHash, 0xecf35607b7e822969ee3625cd815bfc27031f3a93d0be2676e5bde943e2e2300, "check hash");

        getLocationHash("etherisc.storage.Pool");
        getLocationHash("etherisc.storage.NftOwnable");
        getLocationHash("etherisc.storage.PolicyHolder");
        getLocationHash("etherisc.storage.Distribution");
        getLocationHash("etherisc.storage.Pool");
        getLocationHash("etherisc.storage.Product");
        getLocationHash("etherisc.storage.Oracle");
    }

    function getLocationHash(string memory location) public returns (bytes32 locationHash) {
        locationHash = pool.getContractLocation(bytes(location));
        console.log(location);
        console.logBytes32(locationHash);
    }

    function test_Pool_setupInfo() public {
        vm.startPrank(instanceOwner);
        instanceAccessManager.grantRole(POOL_OWNER_ROLE(), poolOwner);
        vm.stopPrank();

        vm.startPrank(poolOwner);

        pool = new SimplePool(
            address(registry),
            instanceNftId,
            address(token),
            false,
            false,
            UFixedLib.toUFixed(1),
            UFixedLib.toUFixed(1),
            poolOwner
        );
        
        NftId poolNftId = poolService.register(address(pool));
        ISetup.PoolSetupInfo memory poolSetupInfo = instanceReader.getPoolSetupInfo(poolNftId);

        // check nftid
        assertTrue(poolSetupInfo.productNftId.eqz(), "product nft not zero");

        // check token handler
        assertTrue(address(poolSetupInfo.tokenHandler) != address(0), "token handler zero");
        assertEq(address(poolSetupInfo.tokenHandler.getToken()), address(pool.getToken()), "unexpected token for token handler");

        // check fees
        Fee memory poolFee = poolSetupInfo.poolFee;
        Fee memory stakingFee = poolSetupInfo.stakingFee;
        Fee memory performanceFee = poolSetupInfo.performanceFee;
        assertEq(poolFee.fractionalFee.toInt(), 0, "pool fee not 0");
        assertEq(poolFee.fixedFee, 0, "pool fee not 0");
        assertEq(stakingFee.fractionalFee.toInt(), 0, "staking fee not 0");
        assertEq(stakingFee.fixedFee, 0, "staking fee not 0");
        assertEq(performanceFee.fractionalFee.toInt(), 0, "performance fee not 0");
        assertEq(performanceFee.fixedFee, 0, "performance fee not 0");
    }


    function test_Pool_setFees() public {
        vm.startPrank(instanceOwner);
        instanceAccessManager.grantRole(POOL_OWNER_ROLE(), poolOwner);
        vm.stopPrank();

        vm.startPrank(poolOwner);

        pool = new SimplePool(
            address(registry),
            instanceNftId,
            address(token),
            false,
            false,
            UFixedLib.toUFixed(1),
            UFixedLib.toUFixed(1),
            poolOwner
        );
        
        NftId poolNftId = poolService.register(address(pool));
        Fee memory newPoolFee = FeeLib.toFee(UFixedLib.toUFixed(111,0), 222);
        Fee memory newStakingFee = FeeLib.toFee(UFixedLib.toUFixed(333,0), 444);
        Fee memory newPerformanceFee = FeeLib.toFee(UFixedLib.toUFixed(555,0), 666);
        pool.setFees(newPoolFee, newStakingFee, newPerformanceFee);

        ISetup.PoolSetupInfo memory poolSetupInfo = instanceReader.getPoolSetupInfo(poolNftId);
        Fee memory poolFee = poolSetupInfo.poolFee;
        Fee memory stakingFee = poolSetupInfo.stakingFee;
        Fee memory performanceFee = poolSetupInfo.performanceFee;
        assertEq(poolFee.fractionalFee.toInt(), 111, "pool fee not 111");
        assertEq(poolFee.fixedFee, 222, "pool fee not 222");
        assertEq(stakingFee.fractionalFee.toInt(), 333, "staking fee not 333");
        assertEq(stakingFee.fixedFee, 444, "staking fee not 444");
        assertEq(performanceFee.fractionalFee.toInt(), 555, "performance fee not 555");
        assertEq(performanceFee.fixedFee, 666, "performance fee not 666");

        vm.stopPrank();
    }

    function test_Pool_createBundle() public {
        // GIVEN
        _fundInvestor();

        vm.startPrank(instanceOwner);
        instanceAccessManager.grantRole(POOL_OWNER_ROLE(), poolOwner);
        vm.stopPrank();

        vm.startPrank(poolOwner);

        pool = new SimplePool(
            address(registry),
            instanceNftId,
            address(token),
            false,
            false,
            UFixedLib.toUFixed(1),
            UFixedLib.toUFixed(1),
            poolOwner
        );
        
        poolNftId = poolService.register(address(pool));
        vm.stopPrank();

        vm.startPrank(investor);

        ISetup.PoolSetupInfo memory poolSetupInfo = instanceReader.getPoolSetupInfo(poolNftId);
        token.approve(address(poolSetupInfo.tokenHandler), 10000);

        // WHEN
        SimplePool spool = SimplePool(address(pool));
        bundleNftId = spool.createBundle(
            FeeLib.zeroFee(), 
            10000, 
            604800, 
            ""
        );

        // THEN
        assertTrue(!bundleNftId.eqz(), "bundle nft id is zero");

        assertEq(token.balanceOf(poolOwner), 0, "pool owner balance not 0");
        assertEq(token.balanceOf(poolSetupInfo.wallet), 10000, "pool wallet balance not 10000");

        assertEq(instanceBundleManager.bundles(poolNftId), 1, "expected only 1 bundle");
        assertTrue(instanceBundleManager.getBundleNftId(poolNftId, 0).eq(bundleNftId), "bundle nft id in bundle manager not equal to bundle nft id");
        assertEq(instanceBundleManager.activeBundles(poolNftId), 1, "expected one active bundle");
        assertTrue(instanceBundleManager.getActiveBundleNftId(poolNftId, 0).eq(bundleNftId), "active bundle nft id in bundle manager not equal to bundle nft id");
    }

    function test_Pool_setBundleFee() public {
        _fundInvestor();

        vm.startPrank(instanceOwner);
        instanceAccessManager.grantRole(POOL_OWNER_ROLE(), poolOwner);
        vm.stopPrank();

        vm.startPrank(poolOwner);

        pool = new SimplePool(
            address(registry),
            instanceNftId,
            address(token),
            false,
            false,
            UFixedLib.toUFixed(1),
            UFixedLib.toUFixed(1),
            poolOwner
        );
        
        NftId poolNftId = poolService.register(address(pool));

        vm.stopPrank();
        vm.startPrank(investor);

        ISetup.PoolSetupInfo memory poolSetupInfo = instanceReader.getPoolSetupInfo(poolNftId);
        token.approve(address(poolSetupInfo.tokenHandler), 10000);

        SimplePool spool = SimplePool(address(pool));
        NftId bundleNftId = spool.createBundle(
            FeeLib.zeroFee(), 
            10000, 
            604800, 
            ""
        );

        Fee memory fee = FeeLib.toFee(UFixedLib.toUFixed(111,0), 222);
        spool.setBundleFee(bundleNftId, fee);

        IBundle.BundleInfo memory bundleInfo = instanceReader.getBundleInfo(bundleNftId);
        Fee memory bundleFee = bundleInfo.fee;
        assertEq(bundleFee.fractionalFee.toInt(), 111, "bundle fee not 111");
        assertEq(bundleFee.fixedFee, 222, "bundle fee not 222");

        vm.stopPrank();
    }

    function _fundInvestor() internal {
        vm.startPrank(registryOwner);
        token.transfer(investor, 10000);
        vm.stopPrank();
    }

}
