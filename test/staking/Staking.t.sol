// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../../lib/forge-std/src/Test.sol";

import {IInstance} from "../../contracts/instance/IInstance.sol";
import {INftOwnable} from "../../contracts/shared/INftOwnable.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {IStaking} from "../../contracts/staking/IStaking.sol";
import {IStakingService} from "../../contracts/staking/IStakingService.sol";

import {Amount, AmountLib} from "../../contracts/type/Amount.sol";
import {BlocknumberLib} from "../../contracts/type/Blocknumber.sol";
import {GifTest} from "../base/GifTest.sol";
import {NftId, NftIdLib} from "../../contracts/type/NftId.sol";
import {STAKE} from "../../contracts/type/ObjectType.sol";
import {Seconds, SecondsLib} from "../../contracts/type/Seconds.sol";
import {StakingLib} from "../../contracts/staking/StakingLib.sol";
import {StakingStore} from "../../contracts/staking/StakingStore.sol";
import {TargetManagerLib} from "../../contracts/staking/TargetManagerLib.sol";
import {Timestamp, TimestampLib} from "../../contracts/type/Timestamp.sol";
import {TokenHandler} from "../../contracts/shared/TokenHandler.sol";
import {UFixed, UFixedLib} from "../../contracts/type/UFixed.sol";


contract StakingTest is GifTest {

    uint256 public constant STAKING_WALLET_APPROVAL = 5000;
    address private instanceOwner2 = makeAddr("instanceOwner2");
    IInstance private instance2;
    NftId private instanceNftId2;

    function setUp() public override {
        super.setUp();

        // needs component service to be registered
        // can therefore only be called after service registration
        vm.startPrank(staking.getOwner());
        staking.approveTokenHandler(dip, AmountLib.max());
        vm.stopPrank();
    }

    function test_stakingSetUp() public {
        _printAuthz(registryAdmin, "registry setup");

        assertEq(staking.getWallet(), address(staking.getTokenHandler()), "unexpected staking wallet");
        assertEq(dip.allowance(staking.getWallet(), address(staking.getTokenHandler())), type(uint256).max, "unexpected allowance for staking token handler");
    }

    function test_stakingStakeCreateProtocolStake() public {

        NftId protocolNftId = stakingReader.getProtocolNftId();
        (, Amount dipAmount) = _prepareAccount(staker, 5000);

        // check balances before staking
        assertTrue(staker != staking.getWallet(), "staker and staking wallet the same");
        assertEq(dip.balanceOf(staker), dipAmount.toInt(), "staker: unexpected dip balance");
        assertEq(dip.balanceOf(staking.getWallet()), 0, "staking wallet: unexpected dip balance");

        vm.startPrank(staker);

        // create stake
        NftId stakeNftId = stakingService.create(
            protocolNftId, 
            dipAmount);

        vm.stopPrank();

        // check balances after staking
        assertEq(dip.balanceOf(staker), 0, "staker: unexpected dip balance (after staking)");
        assertEq(dip.balanceOf(staking.getWallet()), dipAmount.toInt(), "staking wallet: unexpected dip balance (after staking)");

        // check ownership
        assertTrue(stakeNftId.gtz(), "stake nft id zero");
        assertEq(registry.ownerOf(stakeNftId), staker, "unexpected stake nft owner");
        
        // check object info (registry entry)
        IRegistry.ObjectInfo memory objectInfo = registry.getObjectInfo(stakeNftId);
        assertEq(objectInfo.nftId.toInt(), stakeNftId.toInt(), "unexpected stake nft id");
        assertEq(objectInfo.parentNftId.toInt(), protocolNftId.toInt(), "unexpected parent nft id");
        assertEq(objectInfo.objectType.toInt(), STAKE().toInt(), "unexpected object type");
        assertFalse(objectInfo.isInterceptor, "stake as interceptor");
        assertEq(objectInfo.objectAddress, address(0), "stake object address non zero");
        assertEq(objectInfo.initialOwner, staker, "unexpected initial stake owner");
        assertEq(bytes(objectInfo.data).length, 0, "unexpected data size");

        NftId stakeTargetNftId;
        Seconds lockingPeriod;
        UFixed rewardRate;
        (stakeTargetNftId, lockingPeriod) = stakingReader.getTargetLockingPeriod(stakeNftId);
        assertEq(stakeTargetNftId.toInt(), stakingReader.getProtocolNftId().toInt(), "stake target not protocol (locking period)");
        assertEq(lockingPeriod.toInt(), TargetManagerLib.getDefaultLockingPeriod().toInt(), "unexpected locking period");
        (stakeTargetNftId, rewardRate) = stakingReader.getTargetRewardRate(stakeNftId);
        assertEq(stakeTargetNftId.toInt(), stakingReader.getProtocolNftId().toInt(), "stake target not protocol (reward rate)");
        assertTrue(rewardRate == TargetManagerLib.getDefaultRewardRate(), "unexpected reward rate");

        // check stake balance
        assertEq(stakingReader.getStakeInfo(stakeNftId).stakedAmount.toInt(), dipAmount.toInt(), "unexpected stake amount");
        assertEq(stakingReader.getStakeInfo(stakeNftId).rewardAmount.toInt(), 0, "unexpected reward amount");
        assertEq(stakingReader.getStakeInfo(stakeNftId).lastUpdatedIn.toInt(), block.number, "unexpected last updated in");

        // check state info
        IStaking.StakeInfo memory stakeInfo = stakingReader.getStakeInfo(stakeNftId);
        assertTrue(stakeInfo.lockedUntil.gtz(), "locked until zero");
        assertEq(stakeInfo.lockedUntil.toInt(), TimestampLib.current().toInt() + lockingPeriod.toInt(), "unexpected locked until");
    }


    function test_stakingStakeCreateInstanceStake() public {

        (, Amount dipAmount) = _prepareAccount(staker2, 3000);

        // check balances after staking
        assertEq(dip.balanceOf(staker2), dipAmount.toInt(), "staker2: unexpected dip balance (before staking)");
        assertEq(dip.balanceOf(staking.getWallet()), 0, "staking wallet: unexpected dip balance (before staking)");

        vm.startPrank(staker2);

        // create instance stake
        NftId stakeNftId = stakingService.create(
            instanceNftId, 
            dipAmount);

        vm.stopPrank();

        // check balances after staking
        assertEq(dip.balanceOf(staker2), 0, "staker: unexpected dip balance (after staking)");
        assertEq(dip.balanceOf(staking.getWallet()), dipAmount.toInt(), "staking wallet: unexpected dip balance (after staking)");

        // check ownership
        assertTrue(stakeNftId.gtz(), "stake nft id zero");
        assertEq(registry.ownerOf(stakeNftId), staker2, "unexpected stake nft owner");
        
        // check object info (registry entry)
        IRegistry.ObjectInfo memory objectInfo = registry.getObjectInfo(stakeNftId);
        assertEq(objectInfo.nftId.toInt(), stakeNftId.toInt(), "unexpected stake nft id");
        assertEq(objectInfo.parentNftId.toInt(), instanceNftId.toInt(), "unexpected parent nft id");
        assertEq(objectInfo.objectType.toInt(), STAKE().toInt(), "unexpected object type");
        assertFalse(objectInfo.isInterceptor, "stake as interceptor");
        assertEq(objectInfo.objectAddress, address(0), "stake object address non zero");
        assertEq(objectInfo.initialOwner, staker2, "unexpected initial stake owner");
        assertEq(bytes(objectInfo.data).length, 0, "unexpected data size");

        Seconds lockingPeriod = stakingReader.getTargetInfo(instanceNftId).lockingPeriod;
        assertEq(lockingPeriod.toInt(), TargetManagerLib.getDefaultLockingPeriod().toInt(), "unexpected locking period");

        // check stake balance
        assertEq(stakingReader.getStakeInfo(stakeNftId).stakedAmount.toInt(), dipAmount.toInt(), "unexpected stake amount");
        assertEq(stakingReader.getStakeInfo(stakeNftId).rewardAmount.toInt(), 0, "unexpected reward amount");
        assertEq(stakingReader.getStakeInfo(stakeNftId).lastUpdatedIn.toInt(), block.number, "unexpected last updated at");

        // check state info
        IStaking.StakeInfo memory stakeInfo = stakingReader.getStakeInfo(stakeNftId);
        assertTrue(stakeInfo.lockedUntil.gtz(), "locked until zero");
        assertEq(stakeInfo.lockedUntil.toInt(), TimestampLib.current().toInt() + lockingPeriod.toInt(), "unexpected locked until");

        // check accumulated stakes/rewards on instance
        assertEq(stakingReader.getTargetInfo(instanceNftId).stakedAmount.toInt(), dipAmount.toInt(), "unexpected instance stake amount");
        assertEq(stakingReader.getTargetInfo(instanceNftId).rewardAmount.toInt(), 0, "unexpected instance reward amount");
        assertEq(stakingReader.getTargetInfo(instanceNftId).lastUpdatedIn.toInt(), block.number, "unexpected instance last updated in");
    }


    function test_stakingExceedsMaxStakedAmount() public {
        // GIVEN
        (, Amount dipAmount) = _prepareAccount(staker2, 3000);

        vm.startPrank(instanceOwner);
        Amount maxStakedAmount = dipAmount - AmountLib.toAmount(500);
        instance.setStakingMaxAmount(maxStakedAmount);
        vm.stopPrank();

        vm.startPrank(staker2);

        // THEN
        vm.expectRevert(abi.encodeWithSelector(
            IStaking.ErrorStakingTargetMaxStakedAmountExceeded.selector, 
            instanceNftId,
            maxStakedAmount,
            dipAmount));

        // WHEN - create instance stake
        stakingService.create(
            instanceNftId, 
            dipAmount);
    }

    function test_stakingUpdateInstanceLockingPeriod() public {
        Seconds lockingPeriod = stakingReader.getTargetInfo(instanceNftId).lockingPeriod;
        assertEq(lockingPeriod.toInt(), TargetManagerLib.getDefaultLockingPeriod().toInt(), "unexpected locking period");

        Seconds hundredDays = SecondsLib.toSeconds(100 * 24 * 3600);
        vm.startPrank(instanceOwner);
        instance.setStakingLockingPeriod(hundredDays);
        vm.stopPrank();

        lockingPeriod = stakingReader.getTargetInfo(instanceNftId).lockingPeriod;
        assertEq(lockingPeriod.toInt(), hundredDays.toInt(), "unexpected locking period");
    }

    function test_stakingUpdateInstanceLockingPeriod_tooShort() public {
        Seconds lockingPeriod = stakingReader.getTargetInfo(instanceNftId).lockingPeriod;
        assertEq(lockingPeriod.toInt(), TargetManagerLib.getDefaultLockingPeriod().toInt(), "unexpected locking period");

        Seconds oneHour = SecondsLib.toSeconds(3600);
        vm.startPrank(instanceOwner);

        vm.expectRevert(abi.encodeWithSelector(
            IStaking.ErrorStakingLockingPeriodTooShort.selector,
            instanceNftId,
            TargetManagerLib.getMinimumLockingPeriod(),
            oneHour));
        instance.setStakingLockingPeriod(oneHour);
    }


    function test_stakingStakeUpdateRewardsAfterOneYear() public {

        (
            TokenHandler tokenHandler,
            Amount dipAmount,
            NftId stakeNftId
        ) = _prepareStake(staker, instanceNftId, 1000);

        // record time at stake creation
        uint256 lastUpdateAt = block.timestamp;
        uint256 lastUpdateIn = block.number;
        assertEq(stakingReader.getStakeInfo(stakeNftId).lastUpdatedIn.toInt(), lastUpdateAt, "unexpected last updated at for stake balance");

        // WHEN
        // wait a year
        _wait(SecondsLib.oneYear());

        assertTrue(lastUpdateIn < block.number, "blocknumber not increased");

        // THEN
        // check one year passed
        assertEq(block.timestamp - SecondsLib.oneYear().toInt(), lastUpdateAt, "unexpected year duration");

        // check reward calculations after one year
        uint256 expectedRewardIncrementInFullDip = 50; // 50 = 5% of 1000 for a year
        UFixed rewardRate = stakingReader.getRewardRate(instanceNftId);
        assertEq(_times1000(rewardRate), expectedRewardIncrementInFullDip, "unexpected instance reward rate");

        // check expected reward increase (version 1)
        Amount expectedRewardIncrease = StakingLib.calculateRewardAmount(
            rewardRate,
            SecondsLib.oneYear(),
            dipAmount);

        uint256 expectedRewardIncreaseInt = expectedRewardIncrementInFullDip * 10 ** dip.decimals();
        assertEq(expectedRewardIncrease.toInt(), expectedRewardIncreaseInt, "unexpected 'expected' reward increase");

        // check expected reward increase (version 2)
        Amount rewardIncrease = StakingLib.calculateRewardIncrease(
            stakingReader,
            stakeNftId,
            rewardRate);

        assertTrue(rewardIncrease.gtz(), "reward increase zero");
        assertEq(rewardIncrease.toInt(), expectedRewardIncreaseInt, "unexpected reward increase");

        // check stake/rewards balance (before calling update rewards)
        assertEq(stakingReader.getStakeInfo(stakeNftId).stakedAmount.toInt(), dipAmount.toInt(), "unexpected stake amount (before)");
        assertEq(stakingReader.getStakeInfo(stakeNftId).rewardAmount.toInt(), 0, "unexpected reward amount (before)");
        assertEq(stakingReader.getStakeInfo(stakeNftId).lastUpdatedIn.toInt(), lastUpdateAt, "unexpected last updated at (before)");

        // check accumulated stakes/rewards on instance
        assertEq(stakingReader.getTargetInfo(instanceNftId).stakedAmount.toInt(), dipAmount.toInt(), "unexpected instance stake amount (before)");
        assertEq(stakingReader.getTargetInfo(instanceNftId).rewardAmount.toInt(), 0, "unexpected instance reward amount (before)");
        assertEq(stakingReader.getTargetInfo(instanceNftId).lastUpdatedIn.toInt(), lastUpdateIn, "unexpected instance last updated at (before)");

        // WHEN
        // update rewards (unpermissioned)
        stakingService.updateRewards(stakeNftId);

        // THEN
        // re-check stake/rewards balance (after calling update rewards)
        assertEq(stakingReader.getStakeInfo(stakeNftId).stakedAmount.toInt(), dipAmount.toInt(), "unexpected stake amount (after)");
        assertEq(stakingReader.getStakeInfo(stakeNftId).rewardAmount.toInt(), expectedRewardIncrease.toInt(), "unexpected reward amount (after)");
        assertEq(stakingReader.getStakeInfo(stakeNftId).lastUpdatedIn.toInt(), block.number, "unexpected last updated at (after)");

        // re-check accumulated stakes/rewards on instance
        assertEq(stakingReader.getTargetInfo(instanceNftId).stakedAmount.toInt(), dipAmount.toInt(), "unexpected instance stake amount (after)");
        assertEq(stakingReader.getTargetInfo(instanceNftId).rewardAmount.toInt(), expectedRewardIncrease.toInt(), "unexpected instance reward amount (after)");
        assertEq(stakingReader.getTargetInfo(instanceNftId).lastUpdatedIn.toInt(), block.number, "unexpected instance last updated at (after)");
    }


    function test_stakingStakeIncreaseByZeroAfterOneYear() public {

        (
            ,
            Amount dipAmount,
            NftId stakeNftId
        ) = _prepareStake(staker, instanceNftId, 1000);

        // record time at stake creation
        uint256 lastUpdateAt = block.timestamp;
        uint256 lastUpdateIn = block.number;

        // wait a year
        _wait(SecondsLib.oneYear());

        // check one year passed
        assertEq(block.timestamp - SecondsLib.oneYear().toInt(), lastUpdateAt, "unexpected year duration");

        // check reward calculations after one year
        UFixed rewardRate = stakingReader.getTargetInfo(instanceNftId).rewardRate;
        Amount rewardIncrease = StakingLib.calculateRewardIncrease(
            stakingReader,
            stakeNftId,
            rewardRate);
        
        Amount expectedRewardIncrease = StakingLib.calculateRewardAmount(
            rewardRate,
            SecondsLib.oneYear(),
            dipAmount);

        assertEq(expectedRewardIncrease.toInt(), 50 * 10**dip.decimals(), "unexpected 'expected' reward increase");
        assertTrue(rewardIncrease.gtz(), "reward increase zero");
        assertEq(rewardIncrease.toInt(), expectedRewardIncrease.toInt(), "unexpected rewared increase");

        // check stake/rewards balance (before calling restake)
        assertEq(stakingReader.getStakeInfo(stakeNftId).stakedAmount.toInt(), dipAmount.toInt(), "unexpected stake amount (before)");
        assertEq(stakingReader.getStakeInfo(stakeNftId).rewardAmount.toInt(), 0, "unexpected reward amount (before)");
        assertEq(stakingReader.getStakeInfo(stakeNftId).lastUpdatedIn.toInt(), lastUpdateIn, "unexpected last updated at (before)");

        // time now
        Timestamp timestampNow = TimestampLib.current();

        // increase stake by 0
        vm.startPrank(staker);
        stakingService.stake(stakeNftId, AmountLib.zero());
        vm.stopPrank();

        // check stake/rewards balance (after calling restake)
        Amount expectedRestakedAmount = dipAmount + expectedRewardIncrease;
        assertEq(stakingReader.getStakeInfo(stakeNftId).stakedAmount.toInt(), dipAmount.toInt(), "unexpected stake amount (after stake 0)");
        assertEq(stakingReader.getStakeInfo(stakeNftId).rewardAmount.toInt(), expectedRewardIncrease.toInt(), "unexpected reward amount (after stake 0)");
        assertEq(stakingReader.getStakeInfo(stakeNftId).lastUpdatedIn.toInt(), block.number, "unexpected last updated at (after stake 0)");
    }


    function test_stakingStakeIncreaseByHundredAfterOneYear() public {

        (
            ,
            Amount dipAmount,
            NftId stakeNftId
        ) = _prepareStake(staker, instanceNftId, 1000);

        // record time at stake creation
        uint256 lastUpdateAt = block.timestamp;
        uint256 lastUpdateIn = block.number;

        // wait a year
        _wait(SecondsLib.oneYear());

        // check one year passed
        assertEq(block.timestamp - SecondsLib.oneYear().toInt(), lastUpdateAt, "unexpected year duration");

        // check reward calculations after one year
        UFixed rewardRate = stakingReader.getTargetInfo(instanceNftId).rewardRate;
        Amount rewardIncrease = StakingLib.calculateRewardIncrease(
            stakingReader,
            stakeNftId,
            rewardRate);
        
        Amount expectedRewardIncrease = StakingLib.calculateRewardAmount(
            rewardRate,
            SecondsLib.oneYear(),
            dipAmount);

        assertEq(expectedRewardIncrease.toInt(), 50 * 10**dip.decimals(), "unexpected 'expected' reward increase");
        assertTrue(rewardIncrease.gtz(), "reward increase zero");
        assertEq(rewardIncrease.toInt(), expectedRewardIncrease.toInt(), "unexpected rewared increase");

        // check stake/rewards balance (before calling restake)
        assertEq(stakingReader.getStakeInfo(stakeNftId).stakedAmount.toInt(), dipAmount.toInt(), "unexpected stake amount (before)");
        assertEq(stakingReader.getStakeInfo(stakeNftId).rewardAmount.toInt(), 0, "unexpected reward amount (before)");
        assertEq(stakingReader.getStakeInfo(stakeNftId).lastUpdatedIn.toInt(), lastUpdateIn, "unexpected last updated at (before)");

        // time now
        Seconds lockingPeriod = stakingReader.getTargetInfo(instanceNftId).lockingPeriod;
        Timestamp lockedUntilBefore = stakingReader.getStakeInfo(stakeNftId).lockedUntil;
        assertEq(lockedUntilBefore.toInt(), lastUpdateAt + lockingPeriod.toInt(), "unexpected updated lockedUntil (before)");

        // increase stake by 0
        (, Amount dipAmount2) = _prepareAccount(staker, 100);

        vm.startPrank(staker);
        stakingService.stake(stakeNftId, dipAmount2);
        vm.stopPrank();

        // check stake/rewards balance (after calling restake)
        Amount expectedNewAmount = dipAmount + dipAmount2;
        IStaking.StakeInfo memory stakeInfo = stakingReader.getStakeInfo(stakeNftId);
        assertEq(stakeInfo.stakedAmount.toInt(), expectedNewAmount.toInt(), "unexpected stake amount (after stake 100)");
        assertEq(stakeInfo.rewardAmount.toInt(), expectedRewardIncrease.toInt(), "unexpected reward amount (after stake 100)");
        assertEq(stakeInfo.lastUpdatedIn.toInt(), block.number, "unexpected last updated at (after stake 100)");

        // check locked until
        Timestamp lockedUntilAfter = stakeInfo.lockedUntil;
        Timestamp expectedLockedUntil = lockedUntilBefore.addSeconds(lockingPeriod);
        assertEq(lockedUntilAfter.toInt(), expectedLockedUntil.toInt(), "unexpected updated lockedUntil (after stake 100)");
    }


    function test_stakingStakeIncreaseMaxStakedAmountExceeded() public {
        (
            ,
            Amount dipAmount,
            NftId stakeNftId
        ) = _prepareStake(staker, instanceNftId, 1000);

        vm.startPrank(instanceOwner);
        instance.setStakingMaxAmount(dipAmount);
        vm.stopPrank();

        // increase stakes and restake rewards
        (, Amount stakeIncreaseAmount) = _prepareAccount(staker, 1500, true, true);

        vm.startPrank(staker);

        // THEN
        vm.expectRevert(abi.encodeWithSelector(
            StakingStore.ErrorStakingStoreStakesExceedingTargetMaxAmount.selector, 
            instanceNftId,
            dipAmount,
            dipAmount + stakeIncreaseAmount));

        stakingService.stake(stakeNftId, stakeIncreaseAmount);
    }


    function test_stakingStakeUnstakeHappyCase() public {

        // GIVEN
        (
            ,
            Amount stakeAmount,
            NftId stakeNftId
        ) = _prepareStake(staker, instanceNftId, 1000);

        uint256 lastUpdateAt = block.timestamp;

        (, Amount reserveAmount) = _addRewardReserves(instanceNftId, instanceOwner, 500);
        assertEq(stakingReader.getReserveBalance(instanceNftId).toInt(), reserveAmount.toInt(), "unexpected reserve balance (initial)");

        // dip balance of staker after staking
        assertEq(dip.balanceOf(staker), 0, "unexpected staker balance after staking");

        // wait a year
        _wait(SecondsLib.oneYear());

        // check balance before (= 0)
        assertEq(dip.balanceOf(staker), 0, "staker dip balance not 0 (before unstake)");

        // check stake/rewards balance (before unstake)
        assertEq(stakingReader.getStakeInfo(stakeNftId).stakedAmount.toInt(), stakeAmount.toInt(), "unexpected stake amount (before unstake)");
        assertEq(stakingReader.getStakeInfo(stakeNftId).rewardAmount.toInt(), 0, "unexpected reward amount (before unstake)");
        assertEq(stakingReader.getStakeInfo(stakeNftId).lastUpdatedIn.toInt(), lastUpdateAt, "unexpected last updated at (before unstake)");

        // WHEN
        vm.startPrank(staker);
        stakingService.unstake(stakeNftId);
        vm.stopPrank();

        // THEN
        // get and check instance reward rate
        UFixed rewardRate = stakingReader.getRewardRate(instanceNftId);
        assertTrue(rewardRate.gtz(), "instance reward rate 0");
        assertEq(_times1000(rewardRate), 50, "unexpected instance reward rate");

        // check balance after unstake
        Amount expectedBalanceAfterUnstake = stakeAmount.multiplyWith(
            UFixedLib.toUFixed(1) + rewardRate);
        
        assertTrue(expectedBalanceAfterUnstake > stakeAmount, "no rewards accumulated");

        // check reduced reward reserves
        Amount rewardAmount = expectedBalanceAfterUnstake - stakeAmount;
        Amount remainingReserveAmount = reserveAmount - rewardAmount;
        assertEq(stakingReader.getReserveBalance(instanceNftId).toInt(), remainingReserveAmount.toInt(), "unexpected reserve balance after unstake");

        // dip balance of staker after unstake
        assertEq(dip.balanceOf(staker), expectedBalanceAfterUnstake.toInt(), "unexpected staker balance after unstake");

        // check stake/rewards balance (after unstake)
        assertEq(stakingReader.getStakeInfo(stakeNftId).stakedAmount.toInt(), 0, "unexpected stake amount (after unstake)");
        assertEq(stakingReader.getStakeInfo(stakeNftId).rewardAmount.toInt(), 0, "unexpected reward amount (after unstake)");
        assertEq(stakingReader.getStakeInfo(stakeNftId).lastUpdatedIn.toInt(), block.number, "unexpected last updated at (after unstake)");

        // check accumulated stakes/rewards on instance(after unstake)
        assertEq(stakingReader.getTargetInfo(instanceNftId).stakedAmount.toInt(), 0, "unexpected instance stake amount (after unstake)");
        assertEq(stakingReader.getTargetInfo(instanceNftId).rewardAmount.toInt(), 0, "unexpected instance reward amount (after unstake)");
        assertEq(stakingReader.getTargetInfo(instanceNftId).lastUpdatedIn.toInt(), block.number, "unexpected instance last updated in (after unstake)");
    }

    function test_stakingStakeUnstakeStakeLocked() public {

        // GIVEN
        (,, NftId stakeNftId) = _prepareStake(staker, instanceNftId, 1000);

        uint256 lastUpdateAt = block.timestamp;

        (, Amount reserveAmount) = _addRewardReserves(instanceNftId, instanceOwner, 500);
        assertEq(stakingReader.getReserveBalance(instanceNftId).toInt(), reserveAmount.toInt(), "unexpected reserve balance (initial)");

        // dip balance of staker after staking
        assertEq(dip.balanceOf(staker), 0, "unexpected staker balance after staking");

        // wait 100 days
        _wait(SecondsLib.toSeconds(100 * 24 * 3600));

        // WHEN
        vm.startPrank(staker);
        vm.expectRevert(abi.encodeWithSelector(
            IStaking.ErrorStakingStakeLocked.selector, 
            stakeNftId,
            lastUpdateAt + TargetManagerLib.getDefaultLockingPeriod().toInt()));
        stakingService.unstake(stakeNftId);
    }


    function test_stakingStakeClaimRewardsHappyCase() public {

        // GIVEN
        (
            ,
            Amount stakeAmount,
            NftId stakeNftId
        ) = _prepareStake(staker, instanceNftId, 1000);

        uint256 lastUpdateAt = block.timestamp;

        (, Amount reserveAmount) = _addRewardReserves(instanceNftId, instanceOwner, 500);
        assertEq(stakingReader.getReserveBalance(instanceNftId).toInt(), reserveAmount.toInt(), "unexpected reserve balance (initial)");

        // dip balance of staker after staking
        assertEq(dip.balanceOf(staker), 0, "unexpected staker balance after staking");

        // wait a year
        _wait(SecondsLib.oneYear());

        // check balance before (= 0)
        assertEq(dip.balanceOf(staker), 0, "staker dip balance not 0 (before unstake)");

        // check stake/rewards balance (before unstake)
        assertEq(stakingReader.getStakeInfo(stakeNftId).stakedAmount.toInt(), stakeAmount.toInt(), "unexpected stake amount (before unstake)");
        assertEq(stakingReader.getStakeInfo(stakeNftId).rewardAmount.toInt(), 0, "unexpected reward amount (before unstake)");
        assertEq(stakingReader.getStakeInfo(stakeNftId).lastUpdatedIn.toInt(), lastUpdateAt, "unexpected last updated at (before unstake)");

        // WHEN
        vm.prank(staker);
        stakingService.claimRewards(stakeNftId);

        // THEN
        // get and check instance reward rate
        UFixed rewardRate = stakingReader.getRewardRate(instanceNftId);

        // check balance after claim rewards
        Amount expectedRewards = stakeAmount.multiplyWith(rewardRate);
        
        assertTrue(expectedRewards.gtz(), "no rewards accumulated");

        // check reduced reward reserves
        Amount remainingReserveAmount = reserveAmount - expectedRewards;
        assertEq(stakingReader.getReserveBalance(instanceNftId).toInt(), remainingReserveAmount.toInt(), "unexpected reserve balance after claim rewards");

        // dip balance of staker after claim rewards
        assertEq(dip.balanceOf(staker), expectedRewards.toInt(), "unexpected staker balance after claim rewards");

        // check stake/rewards balance (after claim rewards)
        assertEq(stakingReader.getStakeInfo(stakeNftId).stakedAmount.toInt(), stakeAmount.toInt(), "unexpected stake amount (after claim rewards)");
        assertEq(stakingReader.getStakeInfo(stakeNftId).rewardAmount.toInt(), 0, "unexpected reward amount (after claim rewards)");
        assertEq(stakingReader.getStakeInfo(stakeNftId).lastUpdatedIn.toInt(), block.number, "unexpected last updated at (after claim rewards)");

        // check accumulated stakes/rewards on instance(after claim rewards)
        assertEq(stakingReader.getTargetInfo(instanceNftId).stakedAmount.toInt(), stakeAmount.toInt(), "unexpected instance stake amount (after claim rewards)");
        assertEq(stakingReader.getTargetInfo(instanceNftId).rewardAmount.toInt(), 0, "unexpected instance reward amount (after claim rewards)");
        assertEq(stakingReader.getTargetInfo(instanceNftId).lastUpdatedIn.toInt(), block.number, "unexpected instance last updated in (after claim rewards)");
    }


    function test_stakingStakeClaimRewardsInsufficientReserves() public {

        // GIVEN
        (
            ,
            Amount stakeAmount,
            NftId stakeNftId
        ) = _prepareStake(staker, instanceNftId, 1000);

        uint256 lastUpdateAt = block.timestamp;

        (, Amount reserveAmount) = _addRewardReserves(instanceNftId, instanceOwner, 10);
        assertEq(stakingReader.getReserveBalance(instanceNftId).toInt(), reserveAmount.toInt(), "unexpected reserve balance (initial)");

        // dip balance of staker after staking
        assertEq(dip.balanceOf(staker), 0, "unexpected staker balance after staking");

        // wait a year
        _wait(SecondsLib.oneYear());

        // check balance before (= 0)
        assertEq(dip.balanceOf(staker), 0, "staker dip balance not 0 (before unstake)");

        // check stake/rewards balance (before unstake)
        assertEq(stakingReader.getStakeInfo(stakeNftId).stakedAmount.toInt(), stakeAmount.toInt(), "unexpected stake amount (before unstake)");
        assertEq(stakingReader.getStakeInfo(stakeNftId).rewardAmount.toInt(), 0, "unexpected reward amount (before unstake)");
        assertEq(stakingReader.getStakeInfo(stakeNftId).lastUpdatedIn.toInt(), lastUpdateAt, "unexpected last updated at (before unstake)");

        UFixed rewardRate = stakingReader.getRewardRate(instanceNftId);
        Amount expectedRewards = stakeAmount.multiplyWith(rewardRate);

        // WHEN + THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                StakingStore.ErrorStakingStoreRewardReservesInsufficient.selector,
                instanceNftId,
                reserveAmount,
                expectedRewards));

        vm.prank(staker);
        stakingService.claimRewards(stakeNftId);
    }

    // solhint-disable-next-line func-name-mixedcase
    function test_stakingRestakeHappyCase() public {
        // GIVEN

        // create a second instance - restake target
        vm.startPrank(instanceOwner2);
        (instance2, instanceNftId2) = instanceService.createInstance(false);
        Seconds lockingPeriod2 = stakingReader.getTargetInfo(instanceNftId2).lockingPeriod;
        vm.stopPrank();

        // set reward rate to zero
        vm.startPrank(instanceOwner);
        instance.setStakingRewardRate(UFixedLib.zero()); // no rewards
        vm.stopPrank();

        (, Amount dipAmount) = _prepareAccount(staker, 3000);

        vm.startPrank(staker);

        // create initial instance stake
        NftId stakeNftId = stakingService.create(
            instanceNftId, 
            dipAmount);

        // wait some time
        _wait(SecondsLib.oneYear());
        NftId zeroNftId = NftIdLib.zero();
        
        // THEN - expect log to be written
        NftId expectedNewStakeNftId = NftIdLib.toNftId(223133705); 
        // vm.expectEmit(address(stakingService));
        // emit IStakingService.LogStakingServiceStakeObjectCreated(expectedNewStakeNftId, instanceNftId2, staker); // newStakeNftId is set to zero because we don't know it yet
        vm.expectEmit(address(staking));
        emit IStaking.LogStakingStakeRestaked(expectedNewStakeNftId, instanceNftId2, dipAmount, staker, stakeNftId); // newStakeNftId is set to zero because we don't know it yet

        // WHEN - restake to new target
        (NftId stakeNftId2, Amount restakedAmount) = staking.restake(stakeNftId, instanceNftId2);

        // THEN - check restake only created new staked and changed counters nothing else, especially no tokens moved
        assertTrue(stakeNftId2.gtz());
        assertEq(dipAmount.toInt(), restakedAmount.toInt());

        // check balances after staking - no tokens mived
        assertEq(dip.balanceOf(staker), 0, "staker: unexpected dip balance (after staking)");
        assertEq(dip.balanceOf(staking.getWallet()), dipAmount.toInt(), "staking wallet: unexpected dip balance (after staking)");

        // check stake balance after restake
        assertEq(stakingReader.getStakeInfo(stakeNftId).stakedAmount.toInt(), 0, "unexpected stake amount");
        assertEq(stakingReader.getStakeInfo(stakeNftId).rewardAmount.toInt(), 0, "unexpected reward amount");
        assertEq(stakingReader.getStakeInfo(stakeNftId2).stakedAmount.toInt(), dipAmount.toInt(), "unexpected stake amount (2)");
        assertEq(stakingReader.getStakeInfo(stakeNftId2).rewardAmount.toInt(), 0, "unexpected reward amount (2)");

        // check state info
        IStaking.StakeInfo memory stakeInfo2 = stakingReader.getStakeInfo(stakeNftId2);
        assertEq(stakeInfo2.lockedUntil.toInt(), TimestampLib.current().toInt() + lockingPeriod2.toInt(), "unexpected locked until (2)");

        // check accumulated stakes/rewards on instance and instance2
        assertEq(stakingReader.getTargetInfo(instanceNftId).stakedAmount.toInt(), 0, "unexpected instance stake amount");
        assertEq(stakingReader.getTargetInfo(instanceNftId).rewardAmount.toInt(), 0, "unexpected instance reward amount");
        assertEq(stakingReader.getTargetInfo(instanceNftId).lastUpdatedIn.toInt(), block.number, "unexpected instance last updated in");

        assertEq(stakingReader.getTargetInfo(instanceNftId2).stakedAmount.toInt(), dipAmount.toInt(), "unexpected instance stake amount (2)");
        assertEq(stakingReader.getTargetInfo(instanceNftId2).rewardAmount.toInt(), 0, "unexpected instance reward amount (2)");
        assertEq(stakingReader.getTargetInfo(instanceNftId2).lastUpdatedIn.toInt(), block.number, "unexpected instance last updated in (2)");
    }

    // solhint-disable-next-line func-name-mixedcase
    function test_stakingRestakeWithRewards() public {
        // GIVEN
        // set reward rate
        UFixed instanceRewardRate = UFixedLib.toUFixed(1, -1); // 10% reward rate
        vm.startPrank(instanceOwner);
        instance.setStakingRewardRate(instanceRewardRate); 
        vm.stopPrank();

        (
            ,
            Amount dipAmount,
            NftId stakeNftId
        ) = _prepareStake(staker, instanceNftId, 1000);

        // wait some time
        _wait(SecondsLib.oneYear());

        // create a second instance - restake target
        vm.startPrank(instanceOwner2);
        (instance2, instanceNftId2) = instanceService.createInstance(false);
        Seconds lockingPeriod2 = stakingReader.getTargetInfo(instanceNftId2).lockingPeriod;
        vm.stopPrank();

        // WHEN - restake to new target
        vm.prank(staker);
        (NftId stakeNftId2, Amount restakedAmount) = staking.restake(stakeNftId, instanceNftId2);

        // THEN - check restake only created new staked and changed counters nothing else, especially no tokens moved
        Amount expectedReward = dipAmount.multiplyWith(instanceRewardRate);

        assertTrue(stakeNftId2.gtz());
        assertEq(dipAmount.toInt() + expectedReward.toInt(), restakedAmount.toInt(), "restaked amount invalid");

        // check balances after staking - no tokens mived
        assertEq(dip.balanceOf(staker), 0, "staker: unexpected dip balance (after staking)");
        assertEq(dip.balanceOf(staking.getWallet()), dipAmount.toInt(), "staking wallet: unexpected dip balance (after staking)");

        // check stake balance after restake
        assertEq(stakingReader.getStakeInfo(stakeNftId).stakedAmount.toInt(), 0, "unexpected stake amount");
        assertEq(stakingReader.getStakeInfo(stakeNftId).rewardAmount.toInt(), 0, "unexpected reward amount");
        assertEq(stakingReader.getStakeInfo(stakeNftId2).stakedAmount.toInt(), dipAmount.toInt() + expectedReward.toInt(), "unexpected stake amount (2)");
        assertEq(stakingReader.getStakeInfo(stakeNftId2).rewardAmount.toInt(), 0, "unexpected reward amount (2)");

        // check state info
        IStaking.StakeInfo memory stakeInfo2 = stakingReader.getStakeInfo(stakeNftId2);
        assertEq(stakeInfo2.lockedUntil.toInt(), TimestampLib.current().toInt() + lockingPeriod2.toInt(), "unexpected locked until (2)");

        // check accumulated stakes/rewards on instance and instance2
        assertEq(stakingReader.getTargetInfo(instanceNftId).stakedAmount.toInt(), 0, "unexpected instance stake amount");
        assertEq(stakingReader.getTargetInfo(instanceNftId).rewardAmount.toInt(), 0, "unexpected instance reward amount");
        assertEq(stakingReader.getTargetInfo(instanceNftId).lastUpdatedIn.toInt(), block.number, "unexpected instance last updated in");

        assertEq(stakingReader.getTargetInfo(instanceNftId2).stakedAmount.toInt(), dipAmount.toInt() + expectedReward.toInt(), "unexpected instance stake amount (2)");
        assertEq(stakingReader.getTargetInfo(instanceNftId2).rewardAmount.toInt(), 0, "unexpected instance reward amount (2)");
        assertEq(stakingReader.getTargetInfo(instanceNftId2).lastUpdatedIn.toInt(), block.number, "unexpected instance last updated in (2)");
    }

    // solhint-disable-next-line func-name-mixedcase
    function test_stakingRestakeAlreadyStakedTarget() public {
        // GIVEN

        // create a second instance - restake target
        vm.startPrank(instanceOwner2);
        (instance2, instanceNftId2) = instanceService.createInstance(false);
        Seconds lockingPeriod2 = stakingReader.getTargetInfo(instanceNftId2).lockingPeriod;
        vm.stopPrank();

        // set reward rate to zero
        vm.startPrank(instanceOwner);
        instance.setStakingRewardRate(UFixedLib.zero()); // no rewards
        vm.stopPrank();

        (, Amount dipAmount) = _prepareAccount(staker, 3000);
        Amount oneThousand = AmountLib.toAmount(1000 * 10 ** dip.decimals());
        Amount twoThousand = AmountLib.toAmount(2000 * 10 ** dip.decimals());

        vm.startPrank(staker);

        // create initial instance stakes
        NftId stakeNftId = stakingService.create(
            instanceNftId, 
            oneThousand);

        NftId stakeNftId2 = stakingService.create(
            instanceNftId2, 
            twoThousand);

        Timestamp initialTime = TimestampLib.current();

        // wait some time
        _wait(SecondsLib.oneYear());
        
        // WHEN - restake to target
        (NftId stakeNftId3, Amount restakedAmount) = staking.restake(stakeNftId, instanceNftId2);

        // THEN - check restake only created new stake and changed counters nothing else, especially no tokens moved
        assertTrue(stakeNftId3.gtz());
        assertEq(oneThousand.toInt(), restakedAmount.toInt());

        // check balances after staking - no tokens mived
        assertEq(dip.balanceOf(staker), 0, "staker: unexpected dip balance (after staking)");
        assertEq(dip.balanceOf(staking.getWallet()), dipAmount.toInt(), "staking wallet: unexpected dip balance (after staking)");

        // check stake balances of individual stakes after restake
        assertEq(stakingReader.getStakeInfo(stakeNftId).stakedAmount.toInt(), 0, "unexpected stake amount");
        assertEq(stakingReader.getStakeInfo(stakeNftId).rewardAmount.toInt(), 0, "unexpected reward amount");
        assertEq(stakingReader.getStakeInfo(stakeNftId2).stakedAmount.toInt(), twoThousand.toInt(), "unexpected stake amount (2)");
        assertEq(stakingReader.getStakeInfo(stakeNftId2).rewardAmount.toInt(), 0, "unexpected reward amount (2)");
        assertEq(stakingReader.getStakeInfo(stakeNftId3).stakedAmount.toInt(), oneThousand.toInt(), "unexpected stake amount (3)");
        assertEq(stakingReader.getStakeInfo(stakeNftId3).rewardAmount.toInt(), 0, "unexpected reward amount (3)");

        // check state info
        IStaking.StakeInfo memory stakeInfo2 = stakingReader.getStakeInfo(stakeNftId2);
        assertEq(stakeInfo2.lockedUntil.toInt(), initialTime.toInt() + lockingPeriod2.toInt(), "unexpected locked until (2)");
        IStaking.StakeInfo memory stakeInfo3 = stakingReader.getStakeInfo(stakeNftId3);
        assertEq(stakeInfo3.lockedUntil.toInt(), TimestampLib.current().toInt() + lockingPeriod2.toInt(), "unexpected locked until (3)");

        // check accumulated stakes/rewards on instance and instance2
        assertEq(stakingReader.getTargetInfo(instanceNftId).stakedAmount.toInt(), 0, "unexpected instance stake amount");
        assertEq(stakingReader.getTargetInfo(instanceNftId).rewardAmount.toInt(), 0, "unexpected instance reward amount");
        assertEq(stakingReader.getTargetInfo(instanceNftId).lastUpdatedIn.toInt(), block.number, "unexpected instance last updated in");

        assertEq(stakingReader.getTargetInfo(instanceNftId2).stakedAmount.toInt(), dipAmount.toInt(), "unexpected instance stake amount (2)");
        assertEq(stakingReader.getTargetInfo(instanceNftId2).rewardAmount.toInt(), 0, "unexpected instance reward amount (2)");
        assertEq(stakingReader.getTargetInfo(instanceNftId2).lastUpdatedIn.toInt(), block.number, "unexpected instance last updated in (2)");
    }


    // solhint-disable-next-line func-name-mixedcase
    function test_stakingRestakeInvalidNftType() public {
        // GIVEN
        (, Amount dipAmount) = _prepareAccount(staker, 3000);

        // WHEN + THEN - attempt to stake against registry
        vm.expectRevert(abi.encodeWithSelector(
            IRegistry.ErrorRegistryTypeCombinationInvalid.selector, 
            address(0), 30, 2)); // stake must not have registry as its parent

        vm.startPrank(staker);
        stakingService.create(
            registryNftId, 
            dipAmount);
    }


    // solhint-disable-next-line func-name-mixedcase
    function test_stakingRestakeNotOwner() public {
        // GIVEN

        (
            TokenHandler tokenHandler,
            Amount dipAmount,
            NftId stakeNftId
        ) = _prepareStake(staker, instanceNftId, 1000);

        // create a second instance - restake target
        vm.startPrank(instanceOwner2);
        (instance2, instanceNftId2) = instanceService.createInstance(false);
        Seconds lockingPeriod = stakingReader.getTargetInfo(instanceNftId).lockingPeriod;
        vm.stopPrank();

        // THEN
        vm.expectRevert(abi.encodeWithSelector(
            IStaking.ErrorStakingNotStakeOwner.selector, 
            stakeNftId,
            staker,
            outsider));

        // WHEN - restake to new target
        vm.prank(outsider);
        staking.restake(stakeNftId, instanceNftId2);
    }


    /// @dev test restaking when the stake is still locked
    // solhint-disable-next-line func-name-mixedcase
    function test_stakingRestakeStakeLocked() public {
        // GIVEN
        // create a second instance - restake target
        vm.startPrank(instanceOwner2);
        (instance2, instanceNftId2) = instanceService.createInstance(false);
        Seconds lockingPeriod = stakingReader.getTargetInfo(instanceNftId).lockingPeriod;
        vm.stopPrank();

        (, Amount dipAmount) = _prepareAccount(staker, 3000);

        vm.startPrank(staker);

        // create initial instance stake
        NftId stakeNftId = stakingService.create(
            instanceNftId, 
            dipAmount);

        // THEN
        vm.expectRevert(abi.encodeWithSelector(
            IStaking.ErrorStakingStakeLocked.selector, 
            stakeNftId,
            TimestampLib.current().addSeconds(lockingPeriod)));

        // WHEN - restake to new target
        staking.restake(stakeNftId, instanceNftId2);
    }

    /// @dev test restaking and exceeding the max staked amount
    // solhint-disable-next-line func-name-mixedcase
    function test_stakingRestakeMaxStakedAmountExceeded() public {
        // GIVEN

        (, Amount dipAmount) = _prepareAccount(staker, 3000);

        vm.startPrank(instanceOwner);
        instance.setStakingRewardRate(UFixedLib.zero()); // no rewards
        vm.stopPrank();

        // create a second instance - restake target
        vm.startPrank(instanceOwner2);
        (instance2, instanceNftId2) = instanceService.createInstance(false);
        Amount instance2MaxStakedAmount = dipAmount - AmountLib.toAmount(1000);
        instance2.setStakingMaxAmount(instance2MaxStakedAmount);
        vm.stopPrank();

        vm.startPrank(staker);

        // create initial instance stake
        NftId stakeNftId = stakingService.create(
            instanceNftId, 
            dipAmount);

        _wait(SecondsLib.oneYear());

        // THEN
        vm.expectRevert(abi.encodeWithSelector(
            IStaking.ErrorStakingTargetMaxStakedAmountExceeded.selector, 
            instanceNftId2,
            instance2MaxStakedAmount,
            dipAmount));
            

        // WHEN - restake to new target
        staking.restake(stakeNftId, instanceNftId2);
    }

    /// @dev test restaking when the target is an unknown nft
    // solhint-disable-next-line func-name-mixedcase
    function test_stakingRestakeInvalidTarget() public {
        // GIVEN

        // create a second instance - restake target
        vm.startPrank(instanceOwner2);
        (instance2, instanceNftId2) = instanceService.createInstance(false);
        Seconds lockingPeriod = stakingReader.getTargetInfo(instanceNftId).lockingPeriod;
        vm.stopPrank();

        (, Amount dipAmount) = _prepareAccount(staker, 3000);

        vm.startPrank(staker);

        // create initial instance stake
        NftId stakeNftId = stakingService.create(
            instanceNftId, 
            dipAmount);

        // and wait until restaking is allowed
        vm.warp(block.timestamp + lockingPeriod.toInt());

        // WHEN + THEN - restake to invalid target
        NftId invalidTargetNftId = NftIdLib.toNftId(123);
        vm.expectRevert(abi.encodeWithSelector(
            IStaking.ErrorStakingNotTarget.selector, 
            invalidTargetNftId));

        staking.restake(stakeNftId, invalidTargetNftId);
    }


    function _addRewardReserves(
        NftId, 
        address instanceOwner, 
        uint256 amount
    )
        internal
        returns(
            TokenHandler tokenHandler,
            Amount dipAmount
        )
    {
        (tokenHandler, dipAmount) = _prepareAccount(instanceOwner, amount);

        vm.startPrank(instanceOwner);
        instance.refillStakingRewardReserves(dipAmount);
        vm.stopPrank();
    }


    function _prepareStake(
        address myStaker, 
        NftId myTargetNftId,
        uint256 myStakeAmount
    )
        internal
        returns(
            TokenHandler tokenHandler,
            Amount dipAmount,
            NftId stakeNftId
        )
    {
        (tokenHandler, dipAmount) = _prepareAccount(myStaker, myStakeAmount);

        vm.startPrank(myStaker);
        stakeNftId = stakingService.create(
            myTargetNftId, 
            dipAmount);
        vm.stopPrank();
    }


    function _prepareAccount(
        address myStaker, 
        uint256 myStakeAmount
    )
        internal
        returns(
            TokenHandler tokenHandler,
            Amount dipAmount
        )
    {
        return _prepareAccount(myStaker, myStakeAmount, true, true);
    }


    function _prepareAccount(
        address myStaker, 
        uint256 myStakeAmount,
        bool withFunding,
        bool withApproval
    )
        internal
        returns(
            TokenHandler tokenHandler,
            Amount dipAmount
        )
    {
        tokenHandler = stakingService.getTokenHandler();
        dipAmount = AmountLib.toAmount(myStakeAmount * 10 ** dip.decimals());

        if (withFunding) {
            vm.startPrank(registryOwner);
            dip.transfer(myStaker, dipAmount.toInt());
            vm.stopPrank();
        }

        if (withApproval) {
            vm.startPrank(myStaker);
            dip.approve(address(tokenHandler), dipAmount.toInt());
            vm.stopPrank();
        }
    }


    function _times1000(UFixed value) internal pure returns (uint256) {
        return (UFixedLib.toUFixed(1000) * value).toInt();
    }


    /// @dev adds a number of seconds to block time, and also moves blocknumber by 1 block ahead
    function _wait(Seconds secondsToWait) internal {
        _wait(secondsToWait, 1);
    }

    /// @dev adds a number of seconds to block time, and a number of blocks to blocknumber
    function _wait(Seconds secondsToWait, uint256 blocksToAdd) internal {
        vm.warp(block.timestamp + secondsToWait.toInt());
        vm.roll(block.number + blocksToAdd);
    }

}