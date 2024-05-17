// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../lib/forge-std/src/Test.sol";

import {Fee, FeeLib} from "../contracts/type/Fee.sol";
import {IBundle} from "../contracts/instance/module/IBundle.sol";
import {IComponents} from "../contracts/instance/module/IComponents.sol";
import {IKeyValueStore} from "../contracts/shared/IKeyValueStore.sol";
import {ILifecycle} from "../contracts/shared/ILifecycle.sol";
import {Key32} from "../contracts/type/Key32.sol";
import {NftId, NftIdLib} from "../contracts/type/NftId.sol";
import {ObjectType, BUNDLE} from "../contracts/type/ObjectType.sol";
import {Pool} from "../contracts/pool/Pool.sol";
import {POOL_OWNER_ROLE, PUBLIC_ROLE} from "../contracts/type/RoleId.sol";
import {SecondsLib} from "../contracts/type/Seconds.sol";
import {SimplePool} from "./mock/SimplePool.sol";
import {StateId, ACTIVE, PAUSED, CLOSED} from "../contracts/type/StateId.sol";
import {TimestampLib} from "../contracts/type/Timestamp.sol";
import {GifTest} from "./base/GifTest.sol";
import {UFixedLib} from "../contracts/type/UFixed.sol";

contract TestPool is GifTest {

    function test_PoolContractLocations() public {
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

    function test_PoolComponentAndPoolInfo() public {
        vm.startPrank(instanceOwner);
        instanceAccessManager.grantRole(POOL_OWNER_ROLE().toInt(), poolOwner, 0);
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

        pool.register();
        NftId poolNftId = pool.getNftId();

        // solhint-disable
        console.log("pool nft id: ", poolNftId.toInt());
        console.log("pool deployed at: ", address(pool));
        // solhint-enable

        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(poolNftId);
        // solhint-disable
        console.log("pool name: ", componentInfo.name);
        console.log("pool token: ", componentInfo.token.symbol());
        console.log("pool token handler at: ", address(componentInfo.tokenHandler));
        console.log("pool wallet: ", componentInfo.wallet);
        // solhint-enable

        // check pool
        assertTrue(pool.getNftId().gtz(), "pool nft id zero");
        assertEq(pool.getName(), "SimplePool", "unexpected pool name (1)");
        assertEq(address(pool.getToken()), address(token), "unexpected token address (1)");

        // check token
        assertEq(componentInfo.name, "SimplePool", "unexpected pool name (2)");
        assertEq(address(componentInfo.token), address(token), "unexpected token address (2)");

        // check token handler
        assertTrue(address(componentInfo.tokenHandler) != address(0), "token handler zero");
        assertEq(address(componentInfo.tokenHandler.getToken()), address(pool.getToken()), "unexpected token for token handler");

        // check wallet
        assertEq(componentInfo.wallet, address(pool), "unexpected wallet address");

        IComponents.PoolInfo memory poolInfo = instanceReader.getPoolInfo(poolNftId);

        // check nftid
        assertTrue(poolInfo.productNftId.eqz(), "product nft not zero (not yet linked to product)");
        assertEq(poolInfo.bundleOwnerRole.toInt(), PUBLIC_ROLE().toInt(), "unexpected bundle owner role");

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

        // check pool balance
        assertTrue(instanceReader.getBalanceAmount(poolNftId).eqz(), "initial pool balance not zero");
        assertTrue(instanceReader.getFeeAmount(poolNftId).eqz(), "initial pool fee not zero");
    }


    function test_PoolSetFees() public {
        // GIVEN
        _prepareProduct(); // includes pool and product

        IComponents.ProductInfo memory productInfo = instanceReader.getProductInfo(productNftId);

        Fee memory poolFee = productInfo.poolFee;
        assertEq(poolFee.fractionalFee.toInt(), 0, "pool fee not 0 (fractional)");
        assertEq(poolFee.fixedFee, 0, "pool fee not 0 (fixed)");

        Fee memory stakingFee = productInfo.stakingFee;
        assertEq(stakingFee.fractionalFee.toInt(), 0, "staking fee not 0 (fractional)");
        assertEq(stakingFee.fixedFee, 0, "staking fee not 0 (fixed)");

        Fee memory performanceFee = productInfo.performanceFee;
        assertEq(performanceFee.fractionalFee.toInt(), 0, "performance fee not 0 (fractional)");
        assertEq(performanceFee.fixedFee, 0, "performance fee fee not 0 (fixed)");

        Fee memory newPoolFee = FeeLib.toFee(UFixedLib.toUFixed(111,0), 222);
        Fee memory newStakingFee = FeeLib.toFee(UFixedLib.toUFixed(333,0), 444);
        Fee memory newPerformanceFee = FeeLib.toFee(UFixedLib.toUFixed(555,0), 666);

        vm.startPrank(poolOwner);
        pool.setFees(newPoolFee, newStakingFee, newPerformanceFee);
        vm.stopPrank();

        productInfo = instanceReader.getProductInfo(productNftId);
        poolFee = productInfo.poolFee;
        stakingFee = productInfo.stakingFee;
        performanceFee = productInfo.performanceFee;

        assertEq(poolFee.fractionalFee.toInt(), 111, "pool fee not 111 (fractional)");
        assertEq(poolFee.fixedFee, 222, "pool fee not 222 (fixed)");
        assertEq(stakingFee.fractionalFee.toInt(), 333, "staking fee not 333 (fractional)");
        assertEq(stakingFee.fixedFee, 444, "staking fee not 444 (fixed)");
        assertEq(performanceFee.fractionalFee.toInt(), 555, "performance fee not 555 (fractional)");
        assertEq(performanceFee.fixedFee, 666, "performance fee not 666 (fixed)");
    }

    function test_PoolCreateBundle() public {
        // GIVEN
        _prepareProduct(false);
        _fundInvestor();

        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(poolNftId);

        // WHEN
        // SimplePool spool = SimplePool(address(pool));
        vm.startPrank(investor);
        token.approve(address(pool.getTokenHandler()), 10000);

        bundleNftId = pool.createBundle(
            FeeLib.zero(), 
            10000, 
            SecondsLib.toSeconds(604800), 
            ""
        );
        vm.stopPrank();

        // THEN
        assertTrue(!bundleNftId.eqz(), "bundle nft id is zero");

        assertEq(token.balanceOf(poolOwner), 0, "pool owner balance not 0");
        assertEq(token.balanceOf(componentInfo.wallet), 10000, "pool wallet balance not 10000");

        assertEq(instanceBundleManager.bundles(poolNftId), 1, "expected only 1 bundle");
        assertEq(instanceBundleManager.getBundleNftId(poolNftId, 0).toInt(), bundleNftId.toInt(), "bundle nft id in bundle manager not equal to bundle nft id");
        assertEq(instanceBundleManager.activeBundles(poolNftId), 1, "expected one active bundle");
        assertEq(instanceBundleManager.getActiveBundleNftId(poolNftId, 0).toInt(), bundleNftId.toInt(), "active bundle nft id in bundle manager not equal to bundle nft id");

        IBundle.BundleInfo memory bundleInfo = instanceReader.getBundleInfo(bundleNftId);
        assertEq(
            bundleInfo.expiredAt.toInt(), 
            TimestampLib.blockTimestamp().toInt() + bundleInfo.lifetime.toInt(),
            "unexpected expired at");
    }


    function test_PoolBundleInitialState() public {
        // GIVEN
        _prepareProduct(false);
        _fundInvestor();

        // WHEN
        bundleNftId = _createBundle();

        // THEN
        assertTrue(!bundleNftId.eqz(), "bundle nft id is zero");

        // metadata checks
        IKeyValueStore.Metadata memory metadata = instanceReader.getMetadata(bundleNftId.toKey32(BUNDLE()));
        assertEq(metadata.objectType.toInt(), BUNDLE().toInt(), "unexpected bundle type");
        assertEq(metadata.state.toInt(), ACTIVE().toInt(), "unexpected bundle state");

        // bundle manager checks
        assertEq(instanceBundleManager.bundles(poolNftId), 1, "expected only 1 bundle");
        assertEq(instanceBundleManager.getBundleNftId(poolNftId, 0).toInt(), bundleNftId.toInt(), "bundle nft id in bundle manager not equal to bundle nft id");
        assertEq(instanceBundleManager.activeBundles(poolNftId), 1, "expected one active bundle");
        assertEq(instanceBundleManager.getActiveBundleNftId(poolNftId, 0).toInt(), bundleNftId.toInt(), "active bundle nft id in bundle manager not equal to bundle nft id");
    }


    function test_PoolBundleLockUnlockLockHappyCase() public {
        // GIVEN
        _prepareProduct(false);
        _fundInvestor();

        // WHEN lock bundle
        bundleNftId = _createBundle();
        Key32 bundleKey = bundleNftId.toKey32(BUNDLE());

        IKeyValueStore.Metadata memory metadata = instanceReader.getMetadata(bundleKey);
        assertEq(metadata.state.toInt(), ACTIVE().toInt(), "bundle state not active");

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
        _prepareProduct();
        _fundInvestor();

        bundleNftId = _createBundle();
        Key32 bundleKey = bundleNftId.toKey32(BUNDLE());

        IKeyValueStore.Metadata memory metadata = instanceReader.getMetadata(bundleKey);
        assertEq(metadata.state.toInt(), ACTIVE().toInt(), "bundle state not active");

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


    function test_PoolSetBundleFee() public {
        // GIVEN
        _prepareProduct();

        // WHEN
        Fee memory fee = FeeLib.toFee(UFixedLib.toUFixed(111,0), 222);
        vm.startPrank(investor);
        pool.setBundleFee(bundleNftId, fee);
        vm.stopPrank();

        // THEN
        IBundle.BundleInfo memory bundleInfo = instanceReader.getBundleInfo(bundleNftId);
        Fee memory bundleFee = bundleInfo.fee;
        assertEq(bundleFee.fractionalFee.toInt(), 111, "bundle fee not 111");
        assertEq(bundleFee.fixedFee, 222, "bundle fee not 222");
    }

    function _createBundle() internal returns (NftId bundleNftId) {
        vm.startPrank(investor);
        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(poolNftId);
        token.approve(address(componentInfo.tokenHandler), 10000);

        bundleNftId = pool.createBundle(
            FeeLib.zero(), 
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
