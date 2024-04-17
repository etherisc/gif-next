// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {console} from "../lib/forge-std/src/Test.sol";

import {Fee, FeeLib} from "../contracts/type/Fee.sol";
import {IBundle} from "../contracts/instance/module/IBundle.sol";
import {IComponents} from "../contracts/instance/module/IComponents.sol";
import {IKeyValueStore} from "../contracts/instance/base/IKeyValueStore.sol";
import {ILifecycle} from "../contracts/instance/base/ILifecycle.sol";
import {Key32} from "../contracts/type/Key32.sol";
import {NftId, NftIdLib} from "../contracts/type/NftId.sol";
import {ObjectType, BUNDLE} from "../contracts/type/ObjectType.sol";
import {Pool} from "../contracts/pool/Pool.sol";
import {POOL_OWNER_ROLE} from "../contracts/type/RoleId.sol";
import {SecondsLib} from "../contracts/type/Seconds.sol";
import {SimplePool} from "./mock/SimplePool.sol";
import {StateId, ACTIVE, PAUSED, CLOSED} from "../contracts/type/StateId.sol";
import {TimestampLib} from "../contracts/type/Timestamp.sol";
import {GifTest} from "./base/GifTest.sol";
import {UFixedLib} from "../contracts/type/UFixed.sol";

contract TestPool is GifTest {
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
        // solhint-disable
        console.log(location);
        console.logBytes32(locationHash);
        // solhint-enable
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
        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(poolNftId);
        IComponents.PoolInfo memory poolInfo = abi.decode(componentInfo.data, (IComponents.PoolInfo));

        // check nftid
        assertTrue(poolInfo.productNftId.eqz(), "product nft not zero (not yet linked to product)");

        // check token handler
        assertTrue(address(componentInfo.tokenHandler) != address(0), "token handler zero");
        assertEq(address(componentInfo.tokenHandler.getToken()), address(pool.getToken()), "unexpected token for token handler");

        // check fees
        Fee memory poolFee = poolInfo.poolFee;
        Fee memory stakingFee = poolInfo.stakingFee;
        Fee memory performanceFee = poolInfo.performanceFee;
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

        console.log(poolOwner, "poolOwner");
        console.log(pool.getOwner());

        NftId poolNftId = poolService.register(address(pool));

        Fee memory newPoolFee = FeeLib.toFee(UFixedLib.toUFixed(111,0), 222);
        Fee memory newStakingFee = FeeLib.toFee(UFixedLib.toUFixed(333,0), 444);
        Fee memory newPerformanceFee = FeeLib.toFee(UFixedLib.toUFixed(555,0), 666);
        pool.setFees(newPoolFee, newStakingFee, newPerformanceFee);

        vm.stopPrank();

        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(poolNftId);
        IComponents.PoolInfo memory poolInfo = abi.decode(componentInfo.data, (IComponents.PoolInfo));

        Fee memory poolFee = poolInfo.poolFee;
        Fee memory stakingFee = poolInfo.stakingFee;
        Fee memory performanceFee = poolInfo.performanceFee;
        assertEq(poolFee.fractionalFee.toInt(), 111, "pool fee not 111");
        assertEq(poolFee.fixedFee, 222, "pool fee not 222");
        assertEq(stakingFee.fractionalFee.toInt(), 333, "staking fee not 333");
        assertEq(stakingFee.fixedFee, 444, "staking fee not 444");
        assertEq(performanceFee.fractionalFee.toInt(), 555, "performance fee not 555");
        assertEq(performanceFee.fixedFee, 666, "performance fee not 666");
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
        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(poolNftId);
        token.approve(address(componentInfo.tokenHandler), 10000);

        // WHEN
        SimplePool spool = SimplePool(address(pool));
        bundleNftId = spool.createBundle(
            FeeLib.zeroFee(), 
            10000, 
            SecondsLib.toSeconds(604800), 
            ""
        );

        // THEN
        assertTrue(!bundleNftId.eqz(), "bundle nft id is zero");

        assertEq(token.balanceOf(poolOwner), 0, "pool owner balance not 0");
        assertEq(token.balanceOf(componentInfo.wallet), 10000, "pool wallet balance not 10000");

        assertEq(instanceBundleManager.bundles(poolNftId), 1, "expected only 1 bundle");
        assertTrue(instanceBundleManager.getBundleNftId(poolNftId, 0).eq(bundleNftId), "bundle nft id in bundle manager not equal to bundle nft id");
        assertEq(instanceBundleManager.activeBundles(poolNftId), 1, "expected one active bundle");
        assertTrue(instanceBundleManager.getActiveBundleNftId(poolNftId, 0).eq(bundleNftId), "active bundle nft id in bundle manager not equal to bundle nft id");

        IBundle.BundleInfo memory bundleInfo = instanceReader.getBundleInfo(bundleNftId);
        assertEq(
            bundleInfo.expiredAt.toInt(), 
            TimestampLib.blockTimestamp().toInt() + bundleInfo.lifetime.toInt(),
            "unexpected expired at");
    }


    function test_PoolBundleInitialState() public {
        // GIVEN
        _preparePool();
        _fundInvestor();

        // WHEN
        bundleNftId = _createBundle();

        // THEN
        assertTrue(!bundleNftId.eqz(), "bundle nft id is zero");

        // metadata checks
        IKeyValueStore.Metadata memory metadata = instanceReader.getMetadata(bundleNftId.toKey32(BUNDLE()));
        assertEq(metadata.objectType.toInt(), BUNDLE().toInt(), "unexpected bundle type");
        assertEq(metadata.state.toInt(), ACTIVE().toInt(), "unexpected bundle state");
        assertEq(metadata.updatedBy, address(bundleService), "unexpected updated by");

        // bundle manager checks
        assertEq(instanceBundleManager.bundles(poolNftId), 1, "expected only 1 bundle");
        assertEq(instanceBundleManager.getBundleNftId(poolNftId, 0).toInt(), bundleNftId.toInt(), "bundle nft id in bundle manager not equal to bundle nft id");
        assertEq(instanceBundleManager.activeBundles(poolNftId), 1, "expected one active bundle");
        assertEq(instanceBundleManager.getActiveBundleNftId(poolNftId, 0).toInt(), bundleNftId.toInt(), "active bundle nft id in bundle manager not equal to bundle nft id");
    }


    function test_PoolBundleLockUnlockLockHappyCase() public {
        // GIVEN
        _preparePool();
        _fundInvestor();

        // WHEN lock bundle
        bundleNftId = _createBundle();
        Key32 bundleKey = bundleNftId.toKey32(BUNDLE());

        IKeyValueStore.Metadata memory metadata = instanceReader.getMetadata(bundleKey);
        assertEq(metadata.state.toInt(), ACTIVE().toInt(), "bundle state not active");

        // stop some active prank ... 
        // TODO find out from where and remove this "hack"
        vm.stopPrank();

        vm.prank(investor);
        pool.lockBundle(bundleNftId);

        // THEN
        metadata = instanceReader.getMetadata(bundleKey);
        assertEq(metadata.state.toInt(), PAUSED().toInt(), "bundle state not paused");

        // bundle manager checks
        assertEq(instanceBundleManager.bundles(poolNftId), 1, "expected only 1 bundle");
        assertEq(instanceBundleManager.getBundleNftId(poolNftId, 0).toInt(), bundleNftId.toInt(), "bundle nft id in bundle manager not equal to bundle nft id");
        assertEq(instanceBundleManager.activeBundles(poolNftId), 0, "expected zero active bundle");

        // WHEN unlock bundle again
        vm.prank(investor);
        pool.unlockBundle(bundleNftId);

        metadata = instanceReader.getMetadata(bundleKey);
        assertEq(metadata.state.toInt(), ACTIVE().toInt(), "bundle state not active again");

        assertEq(instanceBundleManager.bundles(poolNftId), 1, "expected only 1 bundle");
        assertEq(instanceBundleManager.getBundleNftId(poolNftId, 0).toInt(), bundleNftId.toInt(), "bundle nft id in bundle manager not equal to bundle nft id");
        assertEq(instanceBundleManager.activeBundles(poolNftId), 1, "expected one active bundle");
        assertEq(instanceBundleManager.getActiveBundleNftId(poolNftId, 0).toInt(), bundleNftId.toInt(), "active bundle nft id in bundle manager not equal to bundle nft id");

        // WHEN close bundle
        vm.prank(investor);
        pool.close(bundleNftId);

        // THEN
        metadata = instanceReader.getMetadata(bundleKey);
        assertEq(metadata.state.toInt(), CLOSED().toInt(), "bundle state not closed");

        // bundle manager checks
        assertEq(instanceBundleManager.activeBundles(poolNftId), 0, "expected zero active bundle");
    }


    function test_PoolBundleLockTwiceAttempt() public {
        // GIVEN
        _preparePool();
        _fundInvestor();

        bundleNftId = _createBundle();
        Key32 bundleKey = bundleNftId.toKey32(BUNDLE());

        IKeyValueStore.Metadata memory metadata = instanceReader.getMetadata(bundleKey);
        assertEq(metadata.state.toInt(), ACTIVE().toInt(), "bundle state not active");

        // stop some active prank ... 
        // TODO find out from where and remove this "hack"
        vm.stopPrank();

        vm.prank(investor);
        pool.lockBundle(bundleNftId);

        // WHEN attepting to lock a locked bundle
        vm.expectRevert(abi.encodeWithSelector(
            ILifecycle.ErrorInvalidStateTransition.selector,
            BUNDLE(),
            PAUSED(),
            PAUSED()));

        vm.prank(investor);
        pool.lockBundle(bundleNftId);

        // THEN
        metadata = instanceReader.getMetadata(bundleKey);
        assertEq(metadata.state.toInt(), PAUSED().toInt(), "bundle state not paused");
    }


    // FIX ME
    /*function test_Pool_setBundleFee() public {
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

        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(poolNftId);
        token.approve(address(componentInfo.tokenHandler), 10000);

        SimplePool spool = SimplePool(address(pool));
        NftId bundleNftId = spool.createBundle(
            FeeLib.zeroFee(), 
            10000, 
            SecondsLib.toSeconds(604800), 
            ""
        );

        Fee memory fee = FeeLib.toFee(UFixedLib.toUFixed(111,0), 222);
        spool.setBundleFee(bundleNftId, fee);

        IBundle.BundleInfo memory bundleInfo = instanceReader.getBundleInfo(bundleNftId);
        Fee memory bundleFee = bundleInfo.fee;
        assertEq(bundleFee.fractionalFee.toInt(), 111, "bundle fee not 111");
        assertEq(bundleFee.fixedFee, 222, "bundle fee not 222");

        vm.stopPrank();
    }*/

    function _createBundle() internal returns (NftId bundleNftId) {
        vm.startPrank(investor);
        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(poolNftId);
        token.approve(address(componentInfo.tokenHandler), 10000);

        // WHEN
        SimplePool spool = SimplePool(address(pool));
        return spool.createBundle(
            FeeLib.zeroFee(), 
            10000, 
            SecondsLib.toSeconds(604800), 
            ""
        );
        vm.stopPrank();
    }

    function _fundInvestor() internal {
        vm.startPrank(registryOwner);
        token.transfer(investor, 10000);
        vm.stopPrank();
    }

}
