// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../lib/forge-std/src/Test.sol";

import {Amount, AmountLib} from "../contracts/type/Amount.sol";
import {BasicPoolAuthorization} from "../contracts/pool/BasicPoolAuthorization.sol";
import {Fee, FeeLib} from "../contracts/type/Fee.sol";
import {IBundle} from "../contracts/instance/module/IBundle.sol";
import {IComponents} from "../contracts/instance/module/IComponents.sol";
import {IKeyValueStore} from "../contracts/shared/IKeyValueStore.sol";
import {ILifecycle} from "../contracts/shared/ILifecycle.sol";
import {IPoolService} from "../contracts/pool/IPoolService.sol";
import {Key32} from "../contracts/type/Key32.sol";
import {NftId, NftIdLib} from "../contracts/type/NftId.sol";
import {ObjectType, BUNDLE} from "../contracts/type/ObjectType.sol";
import {Pool} from "../contracts/pool/Pool.sol";
import {PUBLIC_ROLE} from "../contracts/type/RoleId.sol";
import {Seconds, SecondsLib} from "../contracts/type/Seconds.sol";
import {SimplePool} from "../contracts/examples/unpermissioned/SimplePool.sol";
import {SimpleProduct} from "../contracts/examples/unpermissioned/SimpleProduct.sol";
import {StateId, ACTIVE, PAUSED, CLOSED} from "../contracts/type/StateId.sol";
import {TimestampLib} from "../contracts/type/Timestamp.sol";
import {GifTest} from "./base/GifTest.sol";
import {UFixedLib} from "../contracts/type/UFixed.sol";

contract TestPool is GifTest {

    SimpleProduct public newProduct;
    SimplePool public newPool;

    NftId public newProductNftId;

    function setUp() public override {
        super.setUp();

        _prepareProduct(false);
    }

    function test_poolContractLocations() public {
        newPool = new SimplePool(
            address(registry),
            productNftId,
            address(token),
            _getDefaultSimplePoolInfo(),
            new BasicPoolAuthorization("NewSimplePool"),
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

    function test_poolComponentAndPoolInfo() public {

        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(poolNftId);

        // solhint-disable
        console.log("pool name: ", componentInfo.name);
        console.log("pool token: ", componentInfo.token.symbol());
        console.log("pool token handler at: ", address(componentInfo.tokenHandler));
        console.log("pool wallet: ", componentInfo.tokenHandler.getWallet());
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
        assertEq(address(componentInfo.tokenHandler.TOKEN()), address(pool.getToken()), "unexpected token for token handler");

        // check wallet
        assertEq(componentInfo.tokenHandler.getWallet(), address(pool.getTokenHandler()), "unexpected wallet address");

        IComponents.PoolInfo memory poolInfo = instanceReader.getPoolInfo(poolNftId);

        // check nftid
        assertEq(poolInfo.maxBalanceAmount.toInt(), AmountLib.max().toInt(), "unexpected max balance amount");
        assertFalse(poolInfo.isInterceptingBundleTransfers, "unexpected is intercepting");
        assertFalse(poolInfo.isProcessingConfirmedClaims, "unexpected is processing");
        assertFalse(poolInfo.isExternallyManaged, "unexpected is externally managed");
        assertFalse(poolInfo.isVerifyingApplications, "unexpected is verifing");
        assertEq(poolInfo.collateralizationLevel.toInt(), UFixedLib.one().toInt(), "unexpected collateralization level");
        assertEq(poolInfo.retentionLevel.toInt(), UFixedLib.one().toInt(), "unexpected retention level");

        // check pool balance
        assertTrue(instanceReader.getBalanceAmount(poolNftId).eqz(), "initial pool balance not zero");
        assertTrue(instanceReader.getFeeAmount(poolNftId).eqz(), "initial pool fee not zero");
    }


    function test_poolSetFees() public {
        // GIVEN setup includes pool and product

        IComponents.FeeInfo memory feeInfo = instanceReader.getFeeInfo(productNftId);

        Fee memory poolFee = feeInfo.poolFee;
        assertEq(poolFee.fractionalFee.toInt(), 0, "pool fee not 0 (fractional)");
        assertEq(poolFee.fixedFee, 0, "pool fee not 0 (fixed)");

        Fee memory stakingFee = feeInfo.stakingFee;
        assertEq(stakingFee.fractionalFee.toInt(), 0, "staking fee not 0 (fractional)");
        assertEq(stakingFee.fixedFee, 0, "staking fee not 0 (fixed)");

        Fee memory performanceFee = feeInfo.performanceFee;
        assertEq(performanceFee.fractionalFee.toInt(), 0, "performance fee not 0 (fractional)");
        assertEq(performanceFee.fixedFee, 0, "performance fee fee not 0 (fixed)");

        Fee memory newPoolFee = FeeLib.toFee(UFixedLib.toUFixed(111,0), 222);
        Fee memory newStakingFee = FeeLib.toFee(UFixedLib.toUFixed(333,0), 444);
        Fee memory newPerformanceFee = FeeLib.toFee(UFixedLib.toUFixed(555,0), 666);

        vm.startPrank(poolOwner);
        pool.setFees(newPoolFee, newStakingFee, newPerformanceFee);
        vm.stopPrank();

        feeInfo = instanceReader.getFeeInfo(productNftId);
        poolFee = feeInfo.poolFee;
        stakingFee = feeInfo.stakingFee;
        performanceFee = feeInfo.performanceFee;

        assertEq(poolFee.fractionalFee.toInt(), 111, "pool fee not 111 (fractional)");
        assertEq(poolFee.fixedFee, 222, "pool fee not 222 (fixed)");
        assertEq(stakingFee.fractionalFee.toInt(), 333, "staking fee not 333 (fractional)");
        assertEq(stakingFee.fixedFee, 444, "staking fee not 444 (fixed)");
        assertEq(performanceFee.fractionalFee.toInt(), 555, "performance fee not 555 (fractional)");
        assertEq(performanceFee.fixedFee, 666, "performance fee not 666 (fixed)");
    }

    function test_poolCreateBundle() public {
        // GIVEN setup includes pool and product

        _fundInvestor();

        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(poolNftId);

        // WHEN
        // SimplePool spool = SimplePool(address(pool));
        vm.startPrank(investor);
        token.approve(address(pool.getTokenHandler()), 10000);

        Seconds lifetime = SecondsLib.toSeconds(604800);
        uint256 netStakedAmount;
        (bundleNftId, netStakedAmount) = pool.createBundle(
            FeeLib.zero(), 
            10000, 
            lifetime, 
            ""
        );
        vm.stopPrank();

        // THEN
        assertTrue(!bundleNftId.eqz(), "bundle nft id is zero");
        assertEq(netStakedAmount, 10000, "net staked amount not 10000");

        assertEq(token.balanceOf(poolOwner), 0, "pool owner token balance not 0");
        assertEq(token.balanceOf(componentInfo.tokenHandler.getWallet()), 10000, "pool wallet token balance not 10000");

        assertEq(instanceReader.getBalanceAmount(poolNftId).toInt(), 10000, "pool balance not 10000");
        assertEq(instanceReader.getFeeAmount(poolNftId).toInt(), 0, "pool fee not 0");
        assertEq(instanceReader.getBalanceAmount(bundleNftId).toInt(), 10000, "bundle balance not 10000");
        assertEq(instanceReader.getFeeAmount(bundleNftId).toInt(), 0, "bundle fee not 0");

        assertEq(instanceBundleSet.bundles(poolNftId), 1, "expected only 1 bundle");
        assertEq(instanceBundleSet.getBundleNftId(poolNftId, 0).toInt(), bundleNftId.toInt(), "bundle nft id in bundle manager not equal to bundle nft id");
        assertEq(instanceBundleSet.activeBundles(poolNftId), 1, "expected one active bundle");
        assertEq(instanceBundleSet.getActiveBundleNftId(poolNftId, 0).toInt(), bundleNftId.toInt(), "active bundle nft id in bundle manager not equal to bundle nft id");

        IBundle.BundleInfo memory bundleInfo = instanceReader.getBundleInfo(bundleNftId);
        assertEq(
            bundleInfo.expiredAt.toInt(), 
            TimestampLib.blockTimestamp().addSeconds(lifetime).toInt(),
            "unexpected expired at");
        assertEq(
            bundleInfo.activatedAt.toInt(),
            vm.getBlockTimestamp(),
            "unexpected activatedAt");
    }

    function test_poolCreateBundleTwoBundlesMaxBalanceExceeded() public {
        // GIVEN setup includes pool and product

        vm.startPrank(poolOwner);
        pool.setMaxBalanceAmount(AmountLib.toAmount(5000));
        vm.stopPrank();

        // WHEN
        vm.startPrank(investor);

        Seconds lifetime = SecondsLib.toSeconds(604800);
        Fee memory zeroFee = FeeLib.zero();
        
        // THEN
        vm.expectRevert(abi.encodeWithSelector(
            IPoolService.ErrorPoolServiceMaxBalanceAmountExceeded.selector, 
            poolNftId,
            AmountLib.toAmount(5000),
            AmountLib.toAmount(0),
            AmountLib.toAmount(10000)));

        // WHEN
        pool.createBundle(
            zeroFee, 
            10000, 
            lifetime, 
            ""
        );
    }

    function test_poolCreateBundleMaxBalanceExceeded() public {
        // GIVEN setup includes pool and product

        uint256 maxBalance = 15000;
        uint256 bundleStake = 20000;

        vm.startPrank(poolOwner);
        pool.setMaxBalanceAmount(AmountLib.toAmount(maxBalance));
        vm.stopPrank();

        _fundInvestor(bundleStake);

        // WHEN
        vm.startPrank(investor);

        Seconds lifetime = SecondsLib.toSeconds(604800);
        Fee memory zeroFee = FeeLib.zero();
        
        // THEN
        vm.expectRevert(abi.encodeWithSelector(
            IPoolService.ErrorPoolServiceMaxBalanceAmountExceeded.selector, 
            poolNftId,
            AmountLib.toAmount(maxBalance),
            AmountLib.toAmount(0), // current bundle amount
            AmountLib.toAmount(bundleStake)));

        // WHEN
        pool.createBundle(
            zeroFee, 
            bundleStake, 
            lifetime, 
            ""
        );
    }

    function test_poolCreateBundleWithStakingFee() public {
        // GIVEN setup includes pool and product

        _fundInvestor();
        initialStakingFee = FeeLib.percentageFee(10);

        vm.startPrank(poolOwner);
        pool.setFees(
            FeeLib.zero(), // pool fee
            initialStakingFee,
            FeeLib.zero() // performance fee
        );
        vm.stopPrank();

        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(poolNftId);

        // WHEN
        // SimplePool spool = SimplePool(address(pool));
        vm.startPrank(investor);
        token.approve(address(pool.getTokenHandler()), 10000);

        Seconds lifetime = SecondsLib.toSeconds(604800);
        uint256 netStakedAmount;
        (bundleNftId, netStakedAmount) = pool.createBundle(
            initialStakingFee, 
            10000, 
            lifetime, 
            ""
        );
        vm.stopPrank();

        // THEN
        assertTrue(!bundleNftId.eqz(), "bundle nft id is zero");

        IBundle.BundleInfo memory bundleInfo = instanceReader.getBundleInfo(bundleNftId);
        assertEq(bundleInfo.poolNftId.toInt(), poolNftId.toInt(), "unexpected pool nft id");
        assertEq(bundleInfo.fee.fractionalFee.toInt(), initialStakingFee.fractionalFee.toInt(), "unexpected fractional bundle fee");
        assertEq(bundleInfo.fee.fixedFee, initialStakingFee.fixedFee, "unexpected fixed bundle fee");

        assertEq(netStakedAmount, 9000, "net staked amount not 9000");

        assertEq(token.balanceOf(poolOwner), 0, "pool owner token balance not 0");
        assertEq(token.balanceOf(componentInfo.tokenHandler.getWallet()), 10000, "pool wallet token balance not 10000");

        assertEq(instanceReader.getBalanceAmount(poolNftId).toInt(), 10000, "pool balance not 10000");
        assertEq(instanceReader.getFeeAmount(poolNftId).toInt(), 1000, "pool fee not 0");
        assertEq(instanceReader.getBalanceAmount(bundleNftId).toInt(), 9000, "bundle balance not 10000");
        assertEq(instanceReader.getFeeAmount(bundleNftId).toInt(), 0, "bundle fee not 0");
    }


    function test_poolBundleInitialState() public {
        // GIVEN setup includes pool and product

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
        assertEq(instanceBundleSet.bundles(poolNftId), 1, "expected only 1 bundle");
        assertEq(instanceBundleSet.getBundleNftId(poolNftId, 0).toInt(), bundleNftId.toInt(), "bundle nft id in bundle manager not equal to bundle nft id");
        assertEq(instanceBundleSet.activeBundles(poolNftId), 1, "expected one active bundle");
        assertEq(instanceBundleSet.getActiveBundleNftId(poolNftId, 0).toInt(), bundleNftId.toInt(), "active bundle nft id in bundle manager not equal to bundle nft id");
    }


    function test_poolBundleLockUnlockLockHappyCase() public {
        // GIVEN setup includes pool and product

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
        assertEq(instanceBundleSet.bundles(poolNftId), 1, "expected only 1 bundle");
        assertEq(instanceBundleSet.getBundleNftId(poolNftId, 0).toInt(), bundleNftId.toInt(), "bundle nft id in bundle manager not equal to bundle nft id");
        assertEq(instanceBundleSet.activeBundles(poolNftId), 0, "expected zero active bundle");

        // WHEN unlock bundle again
        vm.prank(investor);
        pool.unlockBundle(bundleNftId);

        metadata = instanceReader.getMetadata(bundleKey);
        assertEq(metadata.state.toInt(), ACTIVE().toInt(), "bundle state not active again");

        assertEq(instanceBundleSet.bundles(poolNftId), 1, "expected only 1 bundle");
        assertEq(instanceBundleSet.getBundleNftId(poolNftId, 0).toInt(), bundleNftId.toInt(), "bundle nft id in bundle manager not equal to bundle nft id");
        assertEq(instanceBundleSet.activeBundles(poolNftId), 1, "expected one active bundle");
        assertEq(instanceBundleSet.getActiveBundleNftId(poolNftId, 0).toInt(), bundleNftId.toInt(), "active bundle nft id in bundle manager not equal to bundle nft id");

        // WHEN close bundle
        vm.prank(investor);
        pool.closeBundle(bundleNftId);

        // THEN
        metadata = instanceReader.getMetadata(bundleKey);
        assertEq(metadata.state.toInt(), CLOSED().toInt(), "bundle state not closed");

        // bundle manager checks
        assertEq(instanceBundleSet.activeBundles(poolNftId), 0, "expected zero active bundle");
    }


    function test_poolBundleLockTwiceAttempt() public {
        // GIVEN setup includes pool and product

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
            address(instanceStore),
            BUNDLE(),
            PAUSED(),
            PAUSED()));

        vm.prank(investor);
        pool.lockBundle(bundleNftId);

        // THEN
        metadata = instanceReader.getMetadata(bundleKey);
        assertEq(metadata.state.toInt(), PAUSED().toInt(), "bundle state not paused");
    }


    function test_poolSetBundleFee() public {
        // GIVEN setup includes pool and product

        _fundInvestor();
        bundleNftId = _createBundle();

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

        (bundleNftId,) = pool.createBundle(
            FeeLib.zero(), 
            10000, 
            SecondsLib.toSeconds(604800), 
            ""
        );
        vm.stopPrank();
    }

    function _fundInvestor() internal {
        _fundInvestor(10000);
    }

    function _fundInvestor(uint256 amount) internal {
        vm.startPrank(registryOwner);
        token.transfer(investor, amount);
        vm.stopPrank();

        vm.startPrank(investor);
        token.approve(address(pool.getTokenHandler()), amount);
        vm.stopPrank();
    }

}
