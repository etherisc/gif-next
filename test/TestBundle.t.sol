// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../lib/forge-std/src/Test.sol";

import {Amount, AmountLib} from "../contracts/type/Amount.sol";
import {BasicPoolAuthorization} from "../contracts/pool/BasicPoolAuthorization.sol";
import {Fee, FeeLib} from "../contracts/type/Fee.sol";
import {IBundle} from "../contracts/instance/module/IBundle.sol";
import {IBundleService} from "../contracts/pool/IBundleService.sol";
import {IComponents} from "../contracts/instance/module/IComponents.sol";
import {IKeyValueStore} from "../contracts/shared/IKeyValueStore.sol";
import {ILifecycle} from "../contracts/shared/ILifecycle.sol";
import {IPoolComponent} from "../contracts/pool/IPoolComponent.sol";
import {Key32} from "../contracts/type/Key32.sol";
import {NftId, NftIdLib} from "../contracts/type/NftId.sol";
import {ObjectType, BUNDLE} from "../contracts/type/ObjectType.sol";
import {Pool} from "../contracts/pool/Pool.sol";
import {IPoolService} from "../contracts/pool/IPoolService.sol";
import {PUBLIC_ROLE} from "../contracts/type/RoleId.sol";
import {ReferralLib} from "../contracts/type/Referral.sol";
import {RiskId, RiskIdLib} from "../contracts/type/RiskId.sol";
import {Seconds, SecondsLib} from "../contracts/type/Seconds.sol";
import {SimplePool} from "../contracts/examples/unpermissioned/SimplePool.sol";
import {StateId, ACTIVE, PAUSED, CLOSED} from "../contracts/type/StateId.sol";
import {Timestamp, TimestampLib, toTimestamp} from "../contracts/type/Timestamp.sol";
import {TokenHandler} from "../contracts/shared/TokenHandler.sol";
import {GifTest} from "./base/GifTest.sol";
import {UFixedLib} from "../contracts/type/UFixed.sol";

contract TestBundle is GifTest {


    /// @dev test staking of an existing bundle 
    function test_Bundle_stakeBundle() public {
        // GIVEN
        initialStakingFee = FeeLib.percentageFee(4);
        _prepareProduct(false);
        
        IComponents.ComponentInfo memory poolComponentInfo = instanceReader.getComponentInfo(poolNftId);

        vm.startPrank(investor);
        token.approve(address(pool.getTokenHandler()), 2000);

        Seconds lifetime = SecondsLib.toSeconds(604800);
        (bundleNftId,) = pool.createBundle(
            FeeLib.zero(), 
            1000, 
            lifetime, 
            ""
        );
        vm.stopPrank();

        assertTrue(!bundleNftId.eqz(), "bundle nft id is zero");

        assertEq(token.balanceOf(poolComponentInfo.wallet), 1000, "pool wallet token balance not 1000");
        uint256 investorBalanceBefore = token.balanceOf(investor);

        assertEq(instanceReader.getBalanceAmount(poolNftId).toInt(), 1000, "pool balance not 1000");
        assertEq(instanceReader.getFeeAmount(poolNftId).toInt(), 40, "pool fees not 40");

        assertEq(instanceReader.getBalanceAmount(bundleNftId).toInt(), 960, "bundle balance not 960");
        assertEq(instanceReader.getFeeAmount(bundleNftId).toInt(), 0, "bundle fees 0");

        uint256 stakeAmount = 1000;
        Amount stakeAmt = AmountLib.toAmount(stakeAmount);
        Amount stakeNetAmt = AmountLib.toAmount(960);
        vm.startPrank(investor);

        // THEN - expect log event
        vm.expectEmit();
        emit IPoolService.LogPoolServiceBundleStaked(instanceNftId, poolNftId, bundleNftId, stakeAmt, stakeNetAmt);

        // WHEN - pool is staked with another 1000 tokens
        pool.stake(bundleNftId, stakeAmt);
        
        // THEN - assert all counters are updated
        assertEq(token.balanceOf(poolComponentInfo.wallet), 2000, "pool wallet token balance not 2000");
        assertEq(token.balanceOf(investor), investorBalanceBefore - stakeAmount, "investor token balance not 0");

        assertEq(instanceReader.getBalanceAmount(poolNftId).toInt(), 2000, "pool balance not 2000");
        assertEq(instanceReader.getFeeAmount(poolNftId).toInt(), 80, "pool fees not 80");

        assertEq(instanceReader.getBalanceAmount(bundleNftId).toInt(), 1920, "bundle balance not 1920");
        assertEq(instanceReader.getFeeAmount(bundleNftId).toInt(), 0, "bundle fees 0");
    }

    /// @dev test staking of an existing locked bundle 
    function test_Bundle_stakeBundle_lockedBundle() public {
        // GIVEN
        initialStakingFee = FeeLib.percentageFee(4);
        _prepareProduct(false);
        
        IComponents.ComponentInfo memory poolComponentInfo = instanceReader.getComponentInfo(poolNftId);

        vm.startPrank(investor);
        token.approve(address(pool.getTokenHandler()), 2000);

        Seconds lifetime = SecondsLib.toSeconds(604800);
        (bundleNftId,) = pool.createBundle(
            FeeLib.zero(), 
            1000, 
            lifetime, 
            ""
        );

        assertTrue(!bundleNftId.eqz(), "bundle nft id is zero");

        assertEq(token.balanceOf(poolComponentInfo.wallet), 1000, "pool wallet token balance not 1000");
        uint256 investorBalanceBefore = token.balanceOf(investor);

        assertEq(instanceReader.getBalanceAmount(poolNftId).toInt(), 1000, "pool balance not 1000");
        assertEq(instanceReader.getFeeAmount(poolNftId).toInt(), 40, "pool fees not 40");

        assertEq(instanceReader.getBalanceAmount(bundleNftId).toInt(), 960, "bundle balance not 960");
        assertEq(instanceReader.getFeeAmount(bundleNftId).toInt(), 0, "bundle fees 0");

        uint256 stakeAmount = 1000;
        Amount stakeAmt = AmountLib.toAmount(stakeAmount);
        Amount stakeNetAmt = AmountLib.toAmount(960);

        pool.lockBundle(bundleNftId);

        // THEN - expect log event
        vm.expectEmit();
        emit IPoolService.LogPoolServiceBundleStaked(instanceNftId, poolNftId, bundleNftId, stakeAmt, stakeNetAmt);

        // WHEN - pool is staked with another 1000 tokens
        pool.stake(bundleNftId, stakeAmt);
        
        // THEN - assert all counters are updated
        assertEq(token.balanceOf(poolComponentInfo.wallet), 2000, "pool wallet token balance not 2000");
        assertEq(token.balanceOf(investor), investorBalanceBefore - stakeAmount, "investor token balance not 0");

        assertEq(instanceReader.getBalanceAmount(poolNftId).toInt(), 2000, "pool balance not 2000");
        assertEq(instanceReader.getFeeAmount(poolNftId).toInt(), 80, "pool fees not 80");

        assertEq(instanceReader.getBalanceAmount(bundleNftId).toInt(), 1920, "bundle balance not 1920");
        assertEq(instanceReader.getFeeAmount(bundleNftId).toInt(), 0, "bundle fees 0");
    }

    function test_Bundle_stakeBundle_maxBalanceExceeded() public {
        // GIVEN
        initialStakingFee = FeeLib.percentageFee(4);
        _prepareProduct(false);
        
        IComponents.ComponentInfo memory poolComponentInfo = instanceReader.getComponentInfo(poolNftId);
        vm.startPrank(poolOwner);
        pool.setMaxBalanceAmount(AmountLib.toAmount(1500));
        vm.stopPrank();

        vm.startPrank(investor);
        token.approve(address(pool.getTokenHandler()), 2000);

        Seconds lifetime = SecondsLib.toSeconds(604800);
        (bundleNftId,) = pool.createBundle(
            FeeLib.zero(), 
            1000, 
            lifetime, 
            ""
        );

        assertTrue(!bundleNftId.eqz(), "bundle nft id is zero");

        uint256 stakeAmount = 1001;
        Amount stakeAmt = AmountLib.toAmount(stakeAmount);
        Amount stakeNetAmt = AmountLib.toAmount(960);

        pool.lockBundle(bundleNftId);

        // THEN - expect revert
        vm.expectRevert(abi.encodeWithSelector(
            IPoolService.ErrorPoolServiceMaxBalanceAmountExceeded.selector, 
            poolNftId,
            AmountLib.toAmount(1500),
            AmountLib.toAmount(1000),
            AmountLib.toAmount(1001)));

        // WHEN - pool is staked with more tokens
        pool.stake(bundleNftId, stakeAmt);
    }

    /// @dev test staking when the allowance is too small
    function test_Bundle_stakeBundle_allowanceTooSmall() public {
        // GIVEN
        initialStakingFee = FeeLib.percentageFee(4);
        _prepareProduct(false);
        
        IComponents.ComponentInfo memory poolComponentInfo = instanceReader.getComponentInfo(poolNftId);

        vm.startPrank(investor);
        token.approve(address(pool.getTokenHandler()), 1000);

        Seconds lifetime = SecondsLib.toSeconds(604800);
        (bundleNftId,) = pool.createBundle(
            FeeLib.zero(), 
            1000, 
            lifetime, 
            ""
        );
        
        Amount stakeAmount = AmountLib.toAmount(1000);

        // THEN  
        vm.expectRevert(abi.encodeWithSelector(
            TokenHandler.ErrorTokenHandlerAllowanceTooSmall.selector, 
            address(token),
            investor,
            address(pool.getTokenHandler()),
            0,
            1000
            ));

        // WHEN 
        pool.stake(bundleNftId, stakeAmount);
    }

    /// @dev test staking amount of zero
    function test_Bundle_stakeBundle_amountIsZero() public {
        // GIVEN
        initialStakingFee = FeeLib.percentageFee(4);
        _prepareProduct(false);
        
        IComponents.ComponentInfo memory poolComponentInfo = instanceReader.getComponentInfo(poolNftId);

        vm.startPrank(investor);
        token.approve(address(pool.getTokenHandler()), 2000);

        Seconds lifetime = SecondsLib.toSeconds(604800);
        (bundleNftId,) = pool.createBundle(
            FeeLib.zero(), 
            1000, 
            lifetime, 
            ""
        );
        
        Amount stakeAmount = AmountLib.toAmount(0);

        // THEN  
        vm.expectRevert(abi.encodeWithSelector(
            TokenHandler.ErrorTokenHandlerAmountIsZero.selector));

        // WHEN 
        pool.stake(bundleNftId, stakeAmount);
    }

    /// @dev test staking into an expired bundle
    function test_Bundle_stakeBundle_bundleExpired() public {
        // GIVEN
        initialStakingFee = FeeLib.percentageFee(4);
        _prepareProduct(false);
        
        IComponents.ComponentInfo memory poolComponentInfo = instanceReader.getComponentInfo(poolNftId);

        vm.startPrank(investor);
        token.approve(address(pool.getTokenHandler()), 2000);

        Seconds lifetime = SecondsLib.toSeconds(604800);
        (bundleNftId,) = pool.createBundle(
            FeeLib.zero(), 
            1000, 
            lifetime, 
            ""
        );
        uint256 createdAt = vm.getBlockTimestamp();
        
        Amount stakeAmount = AmountLib.toAmount(1000);
        
        // fast forward time to after bundle expiration
        skip(lifetime.toInt() + 1000);

        // THEN - revert
        vm.expectRevert(abi.encodeWithSelector(IBundleService.ErrorBundleServiceBundleNotOpen.selector,
            bundleNftId,
            ACTIVE(),
            createdAt + lifetime.toInt()
        ));

        // WHEN - bundle is expired
        pool.stake(bundleNftId, stakeAmount);
    }

    /// @dev test staking into a closed bundle
    function test_Bundle_stakeBundle_bundleClosed() public {
        // GIVEN
        initialStakingFee = FeeLib.percentageFee(4);
        _prepareProduct(false);
        
        IComponents.ComponentInfo memory poolComponentInfo = instanceReader.getComponentInfo(poolNftId);

        vm.startPrank(investor);
        token.approve(address(pool.getTokenHandler()), 2000);

        Seconds lifetime = SecondsLib.toSeconds(604800);
        (bundleNftId,) = pool.createBundle(
            FeeLib.zero(), 
            1000, 
            lifetime, 
            ""
        );
        uint256 createdAt = vm.getBlockTimestamp();
        
        Amount stakeAmount = AmountLib.toAmount(1000);
        
        pool.closeBundle(bundleNftId);

        // THEN - revert
        vm.expectRevert(abi.encodeWithSelector(IBundleService.ErrorBundleServiceBundleNotOpen.selector,
            bundleNftId,
            CLOSED(),
            createdAt + lifetime.toInt()
        ));

        // WHEN - bundle is expired
        pool.stake(bundleNftId, stakeAmount);
    }

    /// @dev test unstaking of a bundle 
    function test_Bundle_unstakeBundle() public {
        // GIVEN
        initialStakingFee = FeeLib.percentageFee(4);
        _prepareProduct(false);
        
        IComponents.ComponentInfo memory poolComponentInfo = instanceReader.getComponentInfo(poolNftId);

        vm.startPrank(investor);
        token.approve(address(pool.getTokenHandler()), 2000);

        Seconds lifetime = SecondsLib.toSeconds(604800);
        (bundleNftId,) = pool.createBundle(
            FeeLib.zero(), 
            1000, 
            lifetime, 
            ""
        );

        assertTrue(!bundleNftId.eqz(), "bundle nft id is zero");

        assertEq(token.balanceOf(poolComponentInfo.wallet), 1000, "pool wallet token balance not 1000");
        uint256 investorBalanceBefore = token.balanceOf(investor);

        assertEq(instanceReader.getBalanceAmount(poolNftId).toInt(), 1000, "pool balance not 1000");
        assertEq(instanceReader.getFeeAmount(poolNftId).toInt(), 40, "pool fees not 40");

        assertEq(instanceReader.getBalanceAmount(bundleNftId).toInt(), 960, "bundle balance not 960");
        assertEq(instanceReader.getFeeAmount(bundleNftId).toInt(), 0, "bundle fees 0");

        uint256 unstakeAmount = 500;
        Amount unstakeAmt = AmountLib.toAmount(unstakeAmount);

        // THEN - expect log event
        vm.expectEmit();
        emit IPoolService.LogPoolServiceBundleUnstaked(instanceNftId, poolNftId, bundleNftId, unstakeAmt);

        // WHEN - 500 tokens are unstaked
        pool.unstake(bundleNftId, unstakeAmt);
        
        // THEN - assert all counters are updated
        assertEq(token.balanceOf(poolComponentInfo.wallet), 500, "pool wallet token balance not 500");
        assertEq(token.balanceOf(investor), investorBalanceBefore + unstakeAmount, "investor token balance not 500");

        assertEq(instanceReader.getBalanceAmount(poolNftId).toInt(), 500, "pool balance not 500");
        assertEq(instanceReader.getFeeAmount(poolNftId).toInt(), 40, "pool fees not 40");

        assertEq(instanceReader.getBalanceAmount(bundleNftId).toInt(), 460, "bundle balance not 460");
        assertEq(instanceReader.getFeeAmount(bundleNftId).toInt(), 0, "bundle fees 0");
    }

    /// @dev test unstaking of all available staked tokens
    function test_Bundle_unstakeBundle_maxAmount() public {
        // GIVEN
        initialStakingFee = FeeLib.percentageFee(4);
        _prepareProduct(false);
        
        IComponents.ComponentInfo memory poolComponentInfo = instanceReader.getComponentInfo(poolNftId);

        vm.startPrank(investor);
        token.approve(address(pool.getTokenHandler()), 2000);

        Seconds lifetime = SecondsLib.toSeconds(604800);
        (bundleNftId,) = pool.createBundle(
            FeeLib.zero(), 
            1000, 
            lifetime, 
            ""
        );

        assertTrue(!bundleNftId.eqz(), "bundle nft id is zero");

        assertEq(token.balanceOf(poolComponentInfo.wallet), 1000, "pool wallet token balance not 1000");
        uint256 investorBalanceBefore = token.balanceOf(investor);

        assertEq(instanceReader.getBalanceAmount(poolNftId).toInt(), 1000, "pool balance not 1000");
        assertEq(instanceReader.getFeeAmount(poolNftId).toInt(), 40, "pool fees not 40");

        assertEq(instanceReader.getBalanceAmount(bundleNftId).toInt(), 960, "bundle balance not 960");
        assertEq(instanceReader.getFeeAmount(bundleNftId).toInt(), 0, "bundle fees 0");

        Amount unstakeAmount = AmountLib.max();
        uint256 expectedUnstakeAmt = 960;
        Amount expectedUnstakeAmount = AmountLib.toAmount(expectedUnstakeAmt);
        
        // THEN - expect log event
        vm.expectEmit();
        emit IPoolService.LogPoolServiceBundleUnstaked(instanceNftId, poolNftId, bundleNftId, expectedUnstakeAmount);

        // WHEN - max tokens are unstaked
        pool.unstake(bundleNftId, unstakeAmount);
        
        // THEN - assert all counters are updated
        assertEq(token.balanceOf(poolComponentInfo.wallet), 40, "pool wallet token balance not 40");
        assertEq(token.balanceOf(investor), investorBalanceBefore + expectedUnstakeAmt, "investor token balance not 960");

        assertEq(instanceReader.getBalanceAmount(poolNftId).toInt(), 40, "pool balance not 40");
        assertEq(instanceReader.getFeeAmount(poolNftId).toInt(), 40, "pool fees not 40");

        assertEq(instanceReader.getBalanceAmount(bundleNftId).toInt(), 0, "bundle balance not 0");
        assertEq(instanceReader.getFeeAmount(bundleNftId).toInt(), 0, "bundle fees 0");
    }

    /// @dev test unstaking of an amount that exceeds the available balance
    function test_Bundle_unstakeBundle_exceedsAvailable() public {
        // GIVEN
        initialStakingFee = FeeLib.percentageFee(4);
        _prepareProduct(false);
        
        IComponents.ComponentInfo memory poolComponentInfo = instanceReader.getComponentInfo(poolNftId);

        vm.startPrank(investor);
        token.approve(address(pool.getTokenHandler()), 2000);

        Seconds lifetime = SecondsLib.toSeconds(604800);
        (bundleNftId,) = pool.createBundle(
            FeeLib.zero(), 
            1000, 
            lifetime, 
            ""
        );

        Amount unstakeAmount = AmountLib.toAmount(1000);
        
        // THEN - expect revert
        vm.expectRevert(abi.encodeWithSelector(
            IBundleService.ErrorBundleServiceUnstakeAmountExceedsLimit.selector,
            unstakeAmount,
            AmountLib.toAmount(960)
        ));

        // WHEN - more tokens are unstaked than available
        pool.unstake(bundleNftId, unstakeAmount);
    }

    /// @dev test unstaking of an amount that exceeds the available balance
    function test_Bundle_unstakeBundle_amountZero() public {
        // GIVEN
        initialStakingFee = FeeLib.percentageFee(4);
        _prepareProduct(false);
        
        IComponents.ComponentInfo memory poolComponentInfo = instanceReader.getComponentInfo(poolNftId);

        vm.startPrank(investor);
        token.approve(address(pool.getTokenHandler()), 2000);

        Seconds lifetime = SecondsLib.toSeconds(604800);
        (bundleNftId,) = pool.createBundle(
            FeeLib.zero(), 
            1000, 
            lifetime, 
            ""
        );

        Amount unstakeAmount = AmountLib.toAmount(0);
        
        // THEN - expect revert
        vm.expectRevert(abi.encodeWithSelector(
            TokenHandler.ErrorTokenHandlerAmountIsZero.selector));

        // WHEN - 0 tokens are unstaked
        pool.unstake(bundleNftId, unstakeAmount);
    }

    /// @dev test unstaking of an amount when allowance is too small
    function test_Bundle_unstakeBundle_allowanceTooSmall() public {
        // GIVEN
        initialStakingFee = FeeLib.percentageFee(4);
        _prepareProduct(false);
        
        IComponents.ComponentInfo memory poolComponentInfo = instanceReader.getComponentInfo(poolNftId);

        vm.startPrank(investor);
        token.approve(address(pool.getTokenHandler()), 2000);

        Seconds lifetime = SecondsLib.toSeconds(604800);
        (bundleNftId,) = pool.createBundle(
            FeeLib.zero(), 
            1000, 
            lifetime, 
            ""
        );

        vm.stopPrank();

        vm.startPrank(poolOwner);
        address externalWallet = makeAddr("externalWallet");
        pool.setWallet(externalWallet);
        vm.stopPrank();

        vm.startPrank(investor);

        Amount unstakeAmount = AmountLib.toAmount(500);
        
        // THEN - expect revert
        vm.expectRevert(abi.encodeWithSelector(
            TokenHandler.ErrorTokenHandlerAllowanceTooSmall.selector,
            address(token),
            externalWallet,
            address(pool.getTokenHandler()),
            0,
            500));

        // WHEN - tokens are unstaked
        pool.unstake(bundleNftId, unstakeAmount);
    }

    /// @dev test extension of a bundle
    function test_Bundle_extend() public {
        // GIVEN
        _prepareProduct(false);
        
        IComponents.ComponentInfo memory poolComponentInfo = instanceReader.getComponentInfo(poolNftId);

        vm.startPrank(investor);
        token.approve(address(pool.getTokenHandler()), 1000);

        Seconds lifetime = SecondsLib.toSeconds(604800);
        (bundleNftId,) = pool.createBundle(
            FeeLib.zero(), 
            1000, 
            lifetime, 
            ""
        );
        uint256 createdAtTs = vm.getBlockTimestamp();

        IBundle.BundleInfo memory bundleInfoBefore = instanceReader.getBundleInfo(bundleNftId);
        assertEq(bundleInfoBefore.activatedAt.toInt(), createdAtTs, "bundle activatedAt incorrect");
        assertEq(bundleInfoBefore.expiredAt.toInt(), createdAtTs + lifetime.toInt(), "bundle lockedAt incorrect");

        Timestamp expectedExpiredAt = bundleInfoBefore.expiredAt.addSeconds(lifetime);

        // THEN - expect a log event
        vm.expectEmit();
        emit IBundleService.LogBundleServiceBundleExtended(bundleNftId, lifetime, expectedExpiredAt);

        // WHEN - bundle is extended
        Timestamp newExpiredAt = pool.extend(bundleNftId, lifetime);

        // THEN - check the new expiration time is correct
        assertEq(newExpiredAt.toInt(), expectedExpiredAt.toInt(), "bundle expiredAt incorrect");

        IBundle.BundleInfo memory bundleInfoAfter = instanceReader.getBundleInfo(bundleNftId);
        assertEq(bundleInfoAfter.activatedAt.toInt(), createdAtTs, "bundle activatedAt incorrect");
        assertEq(bundleInfoAfter.expiredAt.toInt(), newExpiredAt.toInt(), "bundle expiredAt incorrect");
    }

    /// @dev test extension of an expired bundle
    function test_Bundle_extend_bundleExpired() public {
        // GIVEN
        _prepareProduct(false);
        
        IComponents.ComponentInfo memory poolComponentInfo = instanceReader.getComponentInfo(poolNftId);

        vm.startPrank(investor);
        token.approve(address(pool.getTokenHandler()), 1000);

        Seconds lifetime = SecondsLib.toSeconds(604800);
        (bundleNftId,) = pool.createBundle(
            FeeLib.zero(), 
            1000, 
            lifetime, 
            ""
        );
        uint256 createdAtTs = vm.getBlockTimestamp();

        IBundle.BundleInfo memory bundleInfoBefore = instanceReader.getBundleInfo(bundleNftId);
        assertEq(bundleInfoBefore.activatedAt.toInt(), createdAtTs, "bundle activatedAt incorrect");
        assertEq(bundleInfoBefore.expiredAt.toInt(), createdAtTs + lifetime.toInt(), "bundle lockedAt incorrect");

        Timestamp expectedExpiredAt = bundleInfoBefore.expiredAt.addSeconds(lifetime);

        // fast forward time to after bundle expiration
        skip(lifetime.toInt() + 1000);

        // THEN - expect a revert
        vm.expectRevert(abi.encodeWithSelector(IBundleService.ErrorBundleServiceBundleNotOpen.selector,
            bundleNftId,
            ACTIVE(),
            createdAtTs + lifetime.toInt()
        ));

        // WHEN - bundle is extended
        pool.extend(bundleNftId, lifetime);
    }

    /// @dev test extension of a closed bundle
    function test_Bundle_extend_bundleClosed() public {
        // GIVEN
        _prepareProduct(false);
        
        IComponents.ComponentInfo memory poolComponentInfo = instanceReader.getComponentInfo(poolNftId);

        vm.startPrank(investor);
        token.approve(address(pool.getTokenHandler()), 1000);

        Seconds lifetime = SecondsLib.toSeconds(604800);
        (bundleNftId,) = pool.createBundle(
            FeeLib.zero(), 
            1000, 
            lifetime, 
            ""
        );
        uint256 createdAtTs = vm.getBlockTimestamp();

        pool.closeBundle(bundleNftId);

        // THEN - expect a revert
        vm.expectRevert(abi.encodeWithSelector(IBundleService.ErrorBundleServiceBundleNotOpen.selector,
            bundleNftId,
            CLOSED(),
            createdAtTs + lifetime.toInt()
        ));
        
        // WHEN - bundle is extended
        pool.extend(bundleNftId, lifetime);
    }

    /// @dev test extension with lifetime is zero
    function test_Bundle_extend_lifetimeIsZero() public {
        // GIVEN
        _prepareProduct(false);
        
        IComponents.ComponentInfo memory poolComponentInfo = instanceReader.getComponentInfo(poolNftId);

        vm.startPrank(investor);
        token.approve(address(pool.getTokenHandler()), 1000);

        Seconds lifetime = SecondsLib.toSeconds(0);
        (bundleNftId,) = pool.createBundle(
            FeeLib.zero(), 
            1000, 
            lifetime, 
            ""
        );
        // THEN - expect a revert
        vm.expectRevert(abi.encodeWithSelector(IBundleService.ErrorBundleServiceExtensionLifetimeIsZero.selector));
        
        // WHEN - bundle is extended
        pool.extend(bundleNftId, lifetime);
    }

    /// @dev test closing of a bundle
    function test_Bundle_closeBundle() public {
        // GIVEN
        initialStakingFee = FeeLib.percentageFee(4);
        _prepareProduct(true);
        
        IComponents.ComponentInfo memory poolComponentInfo = instanceReader.getComponentInfo(poolNftId);

        assertTrue(!bundleNftId.eqz(), "bundle nft id is zero");

        assertEq(token.balanceOf(poolComponentInfo.wallet), DEFAULT_BUNDLE_CAPITALIZATION * 10 ** 6, "pool wallet token balance not 100000");
        uint256 investorBalanceBefore = token.balanceOf(investor);

        assertEq(instanceReader.getBalanceAmount(poolNftId).toInt(), DEFAULT_BUNDLE_CAPITALIZATION * 10 ** 6, "pool balance not 100000");
        assertEq(instanceReader.getFeeAmount(poolNftId).toInt(), 4000 * 10 ** 6, "pool fees not 4000");

        assertEq(instanceReader.getBalanceAmount(bundleNftId).toInt(), 96000 * 10 ** 6, "bundle balance not 96000");
        assertEq(instanceReader.getFeeAmount(bundleNftId).toInt(), 0, "bundle fees 0");

        vm.stopPrank(); 
        vm.startPrank(investor);

        // WHEN
        pool.closeBundle(bundleNftId);

        // THEN
        assertEq(token.balanceOf(poolComponentInfo.wallet), 4000 * 10 ** 6, "pool wallet token balance not 4000");
        uint256 investorBalanceAfter = token.balanceOf(investor);
        assertEq(investorBalanceAfter, investorBalanceBefore + 96000 * 10 ** 6, "investor token balance not increased by 96000");

        assertEq(instanceReader.getBalanceAmount(poolNftId).toInt(), 4000 * 10 ** 6, "pool balance not 4000");
        assertEq(instanceReader.getFeeAmount(poolNftId).toInt(), 4000 * 10 ** 6, "pool fees not 4000");

        assertEq(instanceReader.getBalanceAmount(bundleNftId).toInt(), 0, "bundle balance not 0");
        assertEq(instanceReader.getFeeAmount(bundleNftId).toInt(), 0, "bundle fees 0");

        assertTrue(instanceReader.getBundleState(bundleNftId) == CLOSED(), "bundle not closed");
        assertTrue(instanceBundleSet.activeBundles(poolNftId) == 0, "active bundles not 0");
    }

    /// @dev test closing of a bundle with a closed policy (no staking fee)
    function test_Bundle_closeBundle_withClosedPolicy() public {
        // GIVEN - pool (no staking fee), a bundle with 3% fee and a closed policy
        initialBundleFee = FeeLib.percentageFee(3);
        _prepareProduct(true);
        vm.stopPrank();

        RiskId riskId = _createRisk("the risk");
        _sellCollateralizeAndClosePolicy(riskId, 1000 * 10 ** 6, 30 * 24 * 60 * 60);
        
        IComponents.ComponentInfo memory poolComponentInfo = instanceReader.getComponentInfo(poolNftId);

        assertTrue(!bundleNftId.eqz(), "bundle nft id is zero");

        assertEq(token.balanceOf(poolComponentInfo.wallet), (DEFAULT_BUNDLE_CAPITALIZATION + 100 + 3 + 3)* 10 ** 6 , "pool wallet token balance not 100000 + 100 + 3");
        uint256 investorBalanceBefore = token.balanceOf(investor);

        assertEq(instanceReader.getBalanceAmount(poolNftId).toInt(), (DEFAULT_BUNDLE_CAPITALIZATION + 100 + 3 + 3) * 10 ** 6, "pool balance not 100000 + 100 + 3");
        assertEq(instanceReader.getFeeAmount(poolNftId).toInt(), (3) * 10 ** 6, "pool fees not 3");

        assertEq(instanceReader.getBalanceAmount(bundleNftId).toInt(), (100000 + 100 + 3) * 10 ** 6, "bundle balance not 96100");
        assertEq(instanceReader.getFeeAmount(bundleNftId).toInt(), 3 * 10 ** 6, "bundle fees 3");

        vm.startPrank(investor);

        // WHEN - bundle is closed
        pool.closeBundle(bundleNftId);

        // THEN - assert all counters are updated and tokens moved
        assertEq(token.balanceOf(poolComponentInfo.wallet), 3 * 10 ** 6, "pool wallet token balance not 3 (2)");
        uint256 investorBalanceAfter = token.balanceOf(investor);
        assertEq(investorBalanceAfter, investorBalanceBefore + (100000 + 100 + 3) * 10 ** 6, "investor token balance not increased by 100000 + 100 + 3");

        assertEq(instanceReader.getBalanceAmount(poolNftId).toInt(), 3 * 10 ** 6, "pool balance not 3 (2)");
        assertEq(instanceReader.getFeeAmount(poolNftId).toInt(), 3 * 10 ** 6, "pool fees not 3 (2)");

        assertEq(instanceReader.getBalanceAmount(bundleNftId).toInt(), 0, "bundle balance not 0 (2)");
        assertEq(instanceReader.getFeeAmount(bundleNftId).toInt(), 0, "bundle fees 0 (2)");

        assertTrue(instanceReader.getBundleState(bundleNftId) == CLOSED(), "bundle not closed");
        assertTrue(instanceBundleSet.activeBundles(poolNftId) == 0, "active bundles not 0");
    }

    /// @dev test closing of a bundle without any balance (full unstake before)
    function test_Bundle_closeBundle_unstakeFullAmountBeforeClose() public {
        // GIVEN - pool (3% staking fee), a bundle and no policy
        initialStakingFee = FeeLib.percentageFee(3);
        _prepareProduct(true);
        vm.stopPrank();

        vm.startPrank(investor);
        pool.unstake(bundleNftId, AmountLib.max());
        
        IComponents.ComponentInfo memory poolComponentInfo = instanceReader.getComponentInfo(poolNftId);

        assertTrue(!bundleNftId.eqz(), "bundle nft id is zero");

        assertEq(token.balanceOf(poolComponentInfo.wallet), 3000 * 10 ** 6 , "pool wallet token balance not 3");
        uint256 investorBalanceBefore = token.balanceOf(investor);

        assertEq(instanceReader.getBalanceAmount(poolNftId).toInt(), 3000 * 10 ** 6, "pool balance not 3000");
        assertEq(instanceReader.getFeeAmount(poolNftId).toInt(), 3000 * 10 ** 6, "pool fees not 3000");

        assertEq(instanceReader.getBalanceAmount(bundleNftId).toInt(), 0, "bundle balance not 0");
        assertEq(instanceReader.getFeeAmount(bundleNftId).toInt(), 0, "bundle fees 0");

        vm.startPrank(investor);

        // WHEN - bundle is closed
        pool.closeBundle(bundleNftId);

        // THEN - assert all counters are updated, but no tokens moved
        assertEq(token.balanceOf(poolComponentInfo.wallet), 3000 * 10 ** 6, "pool wallet token balance not 3 (2)");
        uint256 investorBalanceAfter = token.balanceOf(investor);
        assertEq(investorBalanceAfter, investorBalanceBefore, "investor token balance should not change");

        assertEq(instanceReader.getBalanceAmount(poolNftId).toInt(), 3000 * 10 ** 6, "pool balance not 3000");
        assertEq(instanceReader.getFeeAmount(poolNftId).toInt(), 3000 * 10 ** 6, "pool fees not 3000");

        assertEq(instanceReader.getBalanceAmount(bundleNftId).toInt(), 0, "bundle balance not 0");
        assertEq(instanceReader.getFeeAmount(bundleNftId).toInt(), 0, "bundle fees 0");

        assertTrue(instanceReader.getBundleState(bundleNftId) == CLOSED(), "bundle not closed");
        assertTrue(instanceBundleSet.activeBundles(poolNftId) == 0, "active bundles not 0");
    }

    /// @dev test closing of a bundle with a closed policy and no balance (full unstake before close)
    function test_Bundle_closeBundle_withClosedPolicyUnstakeFullAmountBeforeClose() public {
        // GIVEN - pool (3% staking fee), a bundle (6% bundle fee) and a closed policy
        initialStakingFee = FeeLib.percentageFee(3);
        initialBundleFee = FeeLib.percentageFee(6);
        _prepareProduct(true);
        vm.stopPrank();

        RiskId riskId = _createRisk("the risk");
        _sellCollateralizeAndClosePolicy(riskId, 1000 * 10 ** 6, 30 * 24 * 60 * 60);

        vm.startPrank(investor);
        pool.unstake(bundleNftId, AmountLib.max());
        
        IComponents.ComponentInfo memory poolComponentInfo = instanceReader.getComponentInfo(poolNftId);

        assertTrue(!bundleNftId.eqz(), "bundle nft id is zero");

        assertEq(token.balanceOf(poolComponentInfo.wallet), (3000 + 6 + 3) * 10 ** 6 , "pool wallet token balance not 3009");
        uint256 investorBalanceBefore = token.balanceOf(investor);

        assertEq(instanceReader.getBalanceAmount(poolNftId).toInt(), (3000 + 6 + 3) * 10 ** 6, "pool balance not 3009");
        assertEq(instanceReader.getFeeAmount(poolNftId).toInt(), (3000 + 3) * 10 ** 6, "pool fees not 3009");

        assertEq(instanceReader.getBalanceAmount(bundleNftId).toInt(), 6 * 10 ** 6, "bundle balance not 6");
        assertEq(instanceReader.getFeeAmount(bundleNftId).toInt(), 6 * 10 ** 6, "bundle fees 6");

        vm.startPrank(investor);

        // WHEN - bundle is closed
        pool.closeBundle(bundleNftId);

        // THEN - assert all counters are updated
        assertEq(token.balanceOf(poolComponentInfo.wallet), (3000 + 3) * 10 ** 6, "pool wallet token balance not 3003 (2)");
        uint256 investorBalanceAfter = token.balanceOf(investor);
        assertEq(investorBalanceAfter, investorBalanceBefore + 6 * 10 ** 6, "investor token balance should be increased by 6");

        assertEq(instanceReader.getBalanceAmount(poolNftId).toInt(), (3000 + 3) * 10 ** 6, "pool balance not 3003 (2)");
        assertEq(instanceReader.getFeeAmount(poolNftId).toInt(), (3000 + 3) * 10 ** 6, "pool fees not 3003 (2)");

        assertEq(instanceReader.getBalanceAmount(bundleNftId).toInt(), 0, "bundle balance not 0 (2)");
        assertEq(instanceReader.getFeeAmount(bundleNftId).toInt(), 0, "bundle fees 0 (2)");

        assertTrue(instanceReader.getBundleState(bundleNftId) == CLOSED(), "bundle not closed");
        assertTrue(instanceBundleSet.activeBundles(poolNftId) == 0, "active bundles not 0");
    }

    /// @dev test closing of a bundle with a closed policy and no fees (fee withdrawal before close)
    function test_Bundle_closeBundle_withClosedPolicyWithdrawFeesBeforeClose() public {
        // GIVEN - pool (3% staking fee), a bundle (6% fee) and a closed policy
        initialStakingFee = FeeLib.percentageFee(3);
        initialBundleFee = FeeLib.percentageFee(6);
        _prepareProduct(true);
        vm.stopPrank();

        RiskId riskId = _createRisk("the risk");
        _sellCollateralizeAndClosePolicy(riskId, 1000 * 10 ** 6, 30 * 24 * 60 * 60);

        vm.startPrank(investor);
        pool.withdrawBundleFees(bundleNftId, AmountLib.max());
        
        IComponents.ComponentInfo memory poolComponentInfo = instanceReader.getComponentInfo(poolNftId);

        assertTrue(!bundleNftId.eqz(), "bundle nft id is zero");

        assertEq(token.balanceOf(poolComponentInfo.wallet), (97000 + 100 + 3000 + 3) * 10 ** 6 , "pool wallet token balance not 100103");
        uint256 investorBalanceBefore = token.balanceOf(investor);

        assertEq(instanceReader.getBalanceAmount(poolNftId).toInt(), (97000 + 100 + 3000 + 3) * 10 ** 6, "pool balance not 100103");
        assertEq(instanceReader.getFeeAmount(poolNftId).toInt(), (3000 + 3) * 10 ** 6, "pool fees not 3009");

        assertEq(instanceReader.getBalanceAmount(bundleNftId).toInt(), (97100) * 10 ** 6, "bundle balance not 97100");
        assertEq(instanceReader.getFeeAmount(bundleNftId).toInt(), 0, "bundle fees 0");

        vm.startPrank(investor);

        // WHEN - bundle is closed
        pool.closeBundle(bundleNftId);

        // THEN - assert all counters are updated
        assertEq(token.balanceOf(poolComponentInfo.wallet), (3000 + 3) * 10 ** 6, "pool wallet token balance not 3003 (2)");
        uint256 investorBalanceAfter = token.balanceOf(investor);
        assertEq(investorBalanceAfter, investorBalanceBefore + 97100 * 10 ** 6, "investor token balance should be increased by 97100");

        assertEq(instanceReader.getBalanceAmount(poolNftId).toInt(), (3000 + 3) * 10 ** 6, "pool balance not 3003 (2)");
        assertEq(instanceReader.getFeeAmount(poolNftId).toInt(), (3000 + 3) * 10 ** 6, "pool fees not 3003 (2)");

        assertEq(instanceReader.getBalanceAmount(bundleNftId).toInt(), 0, "bundle balance not 0 (2)");
        assertEq(instanceReader.getFeeAmount(bundleNftId).toInt(), 0, "bundle fees 0 (2)");

        assertTrue(instanceReader.getBundleState(bundleNftId) == CLOSED(), "bundle not closed");
        assertTrue(instanceBundleSet.activeBundles(poolNftId) == 0, "active bundles not 0");
    }

    /// @dev test closing of a bundle with a closed policy and no fees (fee withdrawal before close)
    function test_Bundle_closeBundle_withClosedPolicyUnstakedAndWithdrawFeesBeforeClose() public {
        // GIVEN - pool (3% staking fee), a bundle (6% fee) and a closed policy
        initialStakingFee = FeeLib.percentageFee(3);
        initialBundleFee = FeeLib.percentageFee(6);
        _prepareProduct(true);
        vm.stopPrank();

        RiskId riskId = _createRisk("the risk");
        _sellCollateralizeAndClosePolicy(riskId, 1000 * 10 ** 6, 30 * 24 * 60 * 60);

        vm.startPrank(investor);
        pool.withdrawBundleFees(bundleNftId, AmountLib.max());
        pool.unstake(bundleNftId, AmountLib.max());
        
        IComponents.ComponentInfo memory poolComponentInfo = instanceReader.getComponentInfo(poolNftId);

        assertTrue(!bundleNftId.eqz(), "bundle nft id is zero");

        assertEq(token.balanceOf(poolComponentInfo.wallet), (3000 + 3) * 10 ** 6 , "pool wallet token balance not 3003");
        uint256 investorBalanceBefore = token.balanceOf(investor);

        assertEq(instanceReader.getBalanceAmount(poolNftId).toInt(), (3000 + 3) * 10 ** 6, "pool balance not 3003");
        assertEq(instanceReader.getFeeAmount(poolNftId).toInt(), (3000 + 3) * 10 ** 6, "pool fees not 3009");

        assertEq(instanceReader.getBalanceAmount(bundleNftId).toInt(), 0, "bundle balance not 0");
        assertEq(instanceReader.getFeeAmount(bundleNftId).toInt(), 0, "bundle fees 0");

        vm.startPrank(investor);

        // WHEN - bundle is closed
        pool.closeBundle(bundleNftId);

        // THEN - assert all counters are updated
        assertEq(token.balanceOf(poolComponentInfo.wallet), (3000 + 3) * 10 ** 6, "pool wallet token balance not 3003 (2)");
        uint256 investorBalanceAfter = token.balanceOf(investor);
        assertEq(investorBalanceAfter, investorBalanceBefore, "investor token balance should not change");

        assertEq(instanceReader.getBalanceAmount(poolNftId).toInt(), (3000 + 3) * 10 ** 6, "pool balance not 3003 (2)");
        assertEq(instanceReader.getFeeAmount(poolNftId).toInt(), (3000 + 3) * 10 ** 6, "pool fees not 3003 (2)");

        assertEq(instanceReader.getBalanceAmount(bundleNftId).toInt(), 0, "bundle balance not 0 (2)");
        assertEq(instanceReader.getFeeAmount(bundleNftId).toInt(), 0, "bundle fees 0 (2)");

        assertTrue(instanceReader.getBundleState(bundleNftId) == CLOSED(), "bundle not closed");
        assertTrue(instanceBundleSet.activeBundles(poolNftId) == 0, "active bundles not 0");
    }

    /// @dev test closing of a bundle with an open policy
    function test_Bundle_closeBundle_openPolicy() public {
        // GIVEN
        initialBundleFee = FeeLib.percentageFee(3);
        _prepareProduct(true);
        vm.stopPrank();

        RiskId riskId = _createRisk("the risk");

        vm.startPrank(customer);
        NftId policyNftId = product.createApplication(
            customer, 
            riskId, 
            1000 * 10 ** 6, 
            SecondsLib.toSeconds(30 * 24 * 60 * 60), 
            "", 
            bundleNftId, 
            ReferralLib.zero());
        token.approve(address(product.getTokenHandler()), 1000 * 10 ** 6);
        vm.stopPrank();

        vm.startPrank(productOwner);
        product.createPolicy(policyNftId, true, TimestampLib.blockTimestamp());
        vm.stopPrank();

        vm.startPrank(investor);

        // THEN
        vm.expectRevert(abi.encodeWithSelector(
            IBundleService.ErrorBundleServiceBundleWithOpenPolicies.selector, 
            bundleNftId,
            1));

        // WHEN
        pool.closeBundle(bundleNftId);
    }

    /// @dev test closing of a bundle when allowance is too small
    function test_Bundle_closeBundle_allowanceTooSmall() public {
        // GIVEN
        initialStakingFee = FeeLib.percentageFee(4);
        _prepareProduct(true);
        
        IComponents.ComponentInfo memory poolComponentInfo = instanceReader.getComponentInfo(poolNftId);

        assertTrue(!bundleNftId.eqz(), "bundle nft id is zero");

        address externalWallet = makeAddr("externalWallet");

        vm.startPrank(poolOwner);
        pool.setWallet(externalWallet);
        vm.stopPrank();
        
        vm.startPrank(investor);

        // THEN - expect revert
        vm.expectRevert(abi.encodeWithSelector(
            TokenHandler.ErrorTokenHandlerAllowanceTooSmall.selector, 
            address(token),
            externalWallet,
            address(pool.getTokenHandler()),
            0,
            96000 * 10 ** 6));

        // WHEN
        pool.closeBundle(bundleNftId);
    }

    /// @dev test closing of a bundle when caller is not the owner
    function test_Bundle_closeBundle_notOwner() public {
        // GIVEN
        initialStakingFee = FeeLib.percentageFee(4);
        _prepareProduct(true);
        
        IComponents.ComponentInfo memory poolComponentInfo = instanceReader.getComponentInfo(poolNftId);

        assertTrue(!bundleNftId.eqz(), "bundle nft id is zero");
        
        vm.startPrank(customer);

        // THEN - expect revert
        vm.expectRevert(abi.encodeWithSelector(
            IPoolComponent.ErrorPoolNotBundleOwner.selector, 
            bundleNftId,
            customer));

        // WHEN
        pool.closeBundle(bundleNftId);
    }

    function _fundInvestor(uint256 amount) internal {
        vm.startPrank(registryOwner);
        token.transfer(investor, amount);
        vm.stopPrank();
    }

    function _createRisk(string memory riskIdStr) internal returns (RiskId riskId) {
        vm.startPrank(productOwner);
        riskId = RiskIdLib.toRiskId(riskIdStr);
        product.createRisk(riskId, "");
        vm.stopPrank();
    }

    function _sellCollateralizeAndClosePolicy(RiskId riskId, uint256 sumInsured, uint256 lifetime) internal {
        vm.startPrank(customer);
        NftId policyNftId = product.createApplication(
            customer, 
            riskId, 
            sumInsured, 
            SecondsLib.toSeconds(lifetime), 
            "", 
            bundleNftId, 
            ReferralLib.zero());
        token.approve(address(product.getTokenHandler()), sumInsured);
        vm.stopPrank();

        vm.startPrank(productOwner);
        product.createPolicy(policyNftId, true, TimestampLib.blockTimestamp());
        product.expire(policyNftId, TimestampLib.zero());
        product.close(policyNftId);
        vm.stopPrank();
    }

}
