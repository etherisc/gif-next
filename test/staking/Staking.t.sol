// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;


import {Amount, AmountLib} from "../../contracts/type/Amount.sol";
import {GifTest} from "../base/GifTest.sol";
import {IInstance} from "../../contracts/instance/IInstance.sol";
import {INftOwnable} from "../../contracts/shared/INftOwnable.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {IStaking} from "../../contracts/staking/IStaking.sol";
import {IStakingService} from "../../contracts/staking/IStakingService.sol";
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

        NftId protocolNftId = stakingReader.getTargetNftId(0);
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

        Seconds lockingPeriod = stakingReader.getTargetInfo(protocolNftId).lockingPeriod;
        assertEq(lockingPeriod.toInt(), TargetManagerLib.getDefaultLockingPeriod().toInt(), "unexpected locking period");

        // check stake balance
        assertEq(stakingReader.getStakeBalance(stakeNftId).toInt(), dipAmount.toInt(), "unexpected stake amount");
        assertEq(stakingReader.getRewardBalance(stakeNftId).toInt(), 0, "unexpected reward amount");
        assertEq(stakingReader.getBalanceUpdatedAt(stakeNftId).toInt(), block.timestamp, "unexpected last updated at");

        // check state info
        IStaking.StakeInfo memory stakeInfo = stakingReader.getStakeInfo(stakeNftId);
        assertTrue(stakeInfo.lockedUntil.gtz(), "locked until zero");
        assertEq(stakeInfo.lockedUntil.toInt(), TimestampLib.blockTimestamp().toInt() + lockingPeriod.toInt(), "unexpected locked until");
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
        assertEq(stakingReader.getStakeBalance(stakeNftId).toInt(), dipAmount.toInt(), "unexpected stake amount");
        assertEq(stakingReader.getRewardBalance(stakeNftId).toInt(), 0, "unexpected reward amount");
        assertEq(stakingReader.getBalanceUpdatedAt(stakeNftId).toInt(), block.timestamp, "unexpected last updated at");

        // check state info
        IStaking.StakeInfo memory stakeInfo = stakingReader.getStakeInfo(stakeNftId);
        assertTrue(stakeInfo.lockedUntil.gtz(), "locked until zero");
        assertEq(stakeInfo.lockedUntil.toInt(), TimestampLib.blockTimestamp().toInt() + lockingPeriod.toInt(), "unexpected locked until");

        // check accumulated stakes/rewards on instance
        assertEq(stakingReader.getStakeBalance(instanceNftId).toInt(), dipAmount.toInt(), "unexpected instance stake amount");
        assertEq(stakingReader.getRewardBalance(instanceNftId).toInt(), 0, "unexpected instance reward amount");
        assertEq(stakingReader.getBalanceUpdatedIn(instanceNftId).toInt(), block.number, "unexpected instance last updated in");
    }

    function test_stakeExceedsMaxStakedAmount() public {
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
        assertEq(stakingReader.getBalanceUpdatedAt(stakeNftId).toInt(), lastUpdateAt, "unexpected last updated at for stake balance");

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
        (
            Amount rewardIncrease,
        ) = StakingLib.calculateRewardIncrease(
            stakingReader,
            stakeNftId,
            rewardRate);

        assertTrue(rewardIncrease.gtz(), "reward increase zero");
        assertEq(rewardIncrease.toInt(), expectedRewardIncreaseInt, "unexpected reward increase");

        // check stake/rewards balance (before calling update rewards)
        assertEq(stakingReader.getStakeBalance(stakeNftId).toInt(), dipAmount.toInt(), "unexpected stake amount (before)");
        assertEq(stakingReader.getRewardBalance(stakeNftId).toInt(), 0, "unexpected reward amount (before)");
        assertEq(stakingReader.getBalanceUpdatedAt(stakeNftId).toInt(), lastUpdateAt, "unexpected last updated at (before)");

        // check accumulated stakes/rewards on instance
        assertEq(stakingReader.getStakeBalance(instanceNftId).toInt(), dipAmount.toInt(), "unexpected instance stake amount (before)");
        assertEq(stakingReader.getRewardBalance(instanceNftId).toInt(), 0, "unexpected instance reward amount (before)");
        assertEq(stakingReader.getBalanceUpdatedIn(instanceNftId).toInt(), lastUpdateIn, "unexpected instance last updated at (before)");

        // WHEN
        // update rewards (unpermissioned)
        stakingService.updateRewards(stakeNftId);

        // THEN
        // re-check stake/rewards balance (after calling update rewards)
        assertEq(stakingReader.getStakeBalance(stakeNftId).toInt(), dipAmount.toInt(), "unexpected stake amount (after)");
        assertEq(stakingReader.getRewardBalance(stakeNftId).toInt(), expectedRewardIncrease.toInt(), "unexpected reward amount (after)");
        assertEq(stakingReader.getBalanceUpdatedAt(stakeNftId).toInt(), block.timestamp, "unexpected last updated at (after)");

        // re-check accumulated stakes/rewards on instance
        assertEq(stakingReader.getStakeBalance(instanceNftId).toInt(), dipAmount.toInt(), "unexpected instance stake amount (after)");
        assertEq(stakingReader.getRewardBalance(instanceNftId).toInt(), expectedRewardIncrease.toInt(), "unexpected instance reward amount (after)");
        assertEq(stakingReader.getBalanceUpdatedIn(instanceNftId).toInt(), block.number, "unexpected instance last updated at (after)");
    }


    function test_stakingStakeRestakeAfterOneYear() public {

        (
            ,
            Amount dipAmount,
            NftId stakeNftId
        ) = _prepareStake(staker, instanceNftId, 1000);

        // record time at stake creation
        uint256 lastUpdateAt = block.timestamp;

        // wait a year
        _wait(SecondsLib.oneYear());

        // check one year passed
        assertEq(block.timestamp - SecondsLib.oneYear().toInt(), lastUpdateAt, "unexpected year duration");

        // check reward calculations after one year
        UFixed rewardRate = stakingReader.getTargetInfo(instanceNftId).rewardRate;
        (
            Amount rewardIncrease,
            Amount totalDipAmount
        ) = StakingLib.calculateRewardIncrease(
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
        assertEq(stakingReader.getStakeBalance(stakeNftId).toInt(), dipAmount.toInt(), "unexpected stake amount (before)");
        assertEq(stakingReader.getRewardBalance(stakeNftId).toInt(), 0, "unexpected reward amount (before)");
        assertEq(stakingReader.getBalanceUpdatedAt(stakeNftId).toInt(), lastUpdateAt, "unexpected last updated at (before)");

        // time now
        Timestamp timestampNow = TimestampLib.blockTimestamp();

        // restake rewards
        vm.startPrank(staker);
        stakingService.stake(stakeNftId, AmountLib.zero());
        vm.stopPrank();

        // check stake/rewards balance (after calling restake)
        Amount expectedRestakedAmount = dipAmount + expectedRewardIncrease;
        assertEq(stakingReader.getStakeBalance(stakeNftId).toInt(), expectedRestakedAmount.toInt(), "unexpected stake amount (after restake)");
        assertEq(stakingReader.getRewardBalance(stakeNftId).toInt(), 0, "unexpected reward amount (after restake)");
        assertEq(stakingReader.getBalanceUpdatedAt(stakeNftId).toInt(), block.timestamp, "unexpected last updated at (after)");

        // check locked until
        Seconds lockingPeriod = stakingReader.getTargetInfo(instanceNftId).lockingPeriod;
        Timestamp lockedUntilAfter = stakingReader.getStakeInfo(stakeNftId).lockedUntil;
        Timestamp expectedLockedUntil = timestampNow.addSeconds(lockingPeriod);
        assertEq(lockedUntilAfter.toInt(), expectedLockedUntil.toInt(), "unexpected updated lockedUntil");
    }


    function test_stakingStakeIncreaseStakeAfterOneYear() public {

        (
            ,
            Amount dipAmount,
            NftId stakeNftId
        ) = _prepareStake(staker, instanceNftId, 1000);

        // record time at stake creation
        uint256 lastUpdateAt = block.timestamp;

        // wait a year
        _wait(SecondsLib.oneYear());

        // check one year passed
        assertEq(block.timestamp - SecondsLib.oneYear().toInt(), lastUpdateAt, "unexpected year duration");

        // check reward calculations after one year
        UFixed rewardRate = stakingReader.getTargetInfo(instanceNftId).rewardRate;
        (
            Amount rewardIncrease,
        ) = StakingLib.calculateRewardIncrease(
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
        assertEq(stakingReader.getStakeBalance(stakeNftId).toInt(), dipAmount.toInt(), "unexpected stake amount (before)");
        assertEq(stakingReader.getRewardBalance(stakeNftId).toInt(), 0, "unexpected reward amount (before)");
        assertEq(stakingReader.getBalanceUpdatedAt(stakeNftId).toInt(), lastUpdateAt, "unexpected last updated at (before)");

        // time now
        Timestamp timestampNow = TimestampLib.blockTimestamp();

        // increase stakes and restake rewards
        (, Amount stakeIncreaseAmount) = _prepareAccount(staker, 1500, true, true);

        vm.startPrank(staker);
        stakingService.stake(stakeNftId, stakeIncreaseAmount);
        vm.stopPrank();

        // check stake/rewards balance (after calling restake)
        Amount newBalanceWithRestakedDipsAmount = dipAmount + stakeIncreaseAmount + expectedRewardIncrease;
        assertEq(stakingReader.getStakeBalance(stakeNftId).toInt(), newBalanceWithRestakedDipsAmount.toInt(), "unexpected stake amount (after restake)");
        assertEq(stakingReader.getRewardBalance(stakeNftId).toInt(), 0, "unexpected reward amount (after restake)");
        assertEq(stakingReader.getBalanceUpdatedAt(stakeNftId).toInt(), block.timestamp, "unexpected last updated at (after)");

        // check locked until
        Seconds lockingPeriod = stakingReader.getTargetInfo(instanceNftId).lockingPeriod;
        Timestamp lockedUntilAfter = stakingReader.getStakeInfo(stakeNftId).lockedUntil;
        Timestamp expectedLockedUntil = timestampNow.addSeconds(lockingPeriod);
        assertEq(lockedUntilAfter.toInt(), expectedLockedUntil.toInt(), "unexpected updated lockedUntil");
    }

    function test_stakingStakeIncrease_maxStakedAmountExceeded() public {
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
            IStaking.ErrorStakingTargetMaxStakedAmountExceeded.selector, 
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
        assertEq(stakingReader.getStakeBalance(stakeNftId).toInt(), stakeAmount.toInt(), "unexpected stake amount (before unstake)");
        assertEq(stakingReader.getRewardBalance(stakeNftId).toInt(), 0, "unexpected reward amount (before unstake)");
        assertEq(stakingReader.getBalanceUpdatedAt(stakeNftId).toInt(), lastUpdateAt, "unexpected last updated at (before unstake)");

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
        assertEq(stakingReader.getStakeBalance(stakeNftId).toInt(), 0, "unexpected stake amount (after unstake)");
        assertEq(stakingReader.getRewardBalance(stakeNftId).toInt(), 0, "unexpected reward amount (after unstake)");
        assertEq(stakingReader.getBalanceUpdatedAt(stakeNftId).toInt(), block.timestamp, "unexpected last updated at (after unstake)");

        // check accumulated stakes/rewards on instance(after unstake)
        assertEq(stakingReader.getStakeBalance(instanceNftId).toInt(), 0, "unexpected instance stake amount (after unstake)");
        assertEq(stakingReader.getRewardBalance(instanceNftId).toInt(), 0, "unexpected instance reward amount (after unstake)");
        assertEq(stakingReader.getBalanceUpdatedIn(instanceNftId).toInt(), block.number, "unexpected instance last updated in (after unstake)");
    }

    function test_stakingStakeUnstake_stakeLocked() public {

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
        assertEq(stakingReader.getStakeBalance(stakeNftId).toInt(), stakeAmount.toInt(), "unexpected stake amount (before unstake)");
        assertEq(stakingReader.getRewardBalance(stakeNftId).toInt(), 0, "unexpected reward amount (before unstake)");
        assertEq(stakingReader.getBalanceUpdatedAt(stakeNftId).toInt(), lastUpdateAt, "unexpected last updated at (before unstake)");

        // WHEN
        vm.startPrank(staker);
        stakingService.claimRewards(stakeNftId);
        vm.stopPrank();

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
        assertEq(stakingReader.getStakeBalance(stakeNftId).toInt(), stakeAmount.toInt(), "unexpected stake amount (after claim rewards)");
        assertEq(stakingReader.getRewardBalance(stakeNftId).toInt(), 0, "unexpected reward amount (after claim rewards)");
        assertEq(stakingReader.getBalanceUpdatedAt(stakeNftId).toInt(), block.timestamp, "unexpected last updated at (after claim rewards)");

        // check accumulated stakes/rewards on instance(after claim rewards)
        assertEq(stakingReader.getStakeBalance(instanceNftId).toInt(), stakeAmount.toInt(), "unexpected instance stake amount (after claim rewards)");
        assertEq(stakingReader.getRewardBalance(instanceNftId).toInt(), 0, "unexpected instance reward amount (after claim rewards)");
        assertEq(stakingReader.getBalanceUpdatedIn(instanceNftId).toInt(), block.number, "unexpected instance last updated in (after claim rewards)");
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
        assertEq(stakingReader.getStakeBalance(stakeNftId).toInt(), stakeAmount.toInt(), "unexpected stake amount (before unstake)");
        assertEq(stakingReader.getRewardBalance(stakeNftId).toInt(), 0, "unexpected reward amount (before unstake)");
        assertEq(stakingReader.getBalanceUpdatedAt(stakeNftId).toInt(), lastUpdateAt, "unexpected last updated at (before unstake)");

        UFixed rewardRate = stakingReader.getRewardRate(instanceNftId);
        Amount expectedRewards = stakeAmount.multiplyWith(rewardRate);

        // WHEN

        vm.expectRevert(
            abi.encodeWithSelector(
                StakingStore.ErrorStakingStoreRewardReservesInsufficient.selector,
                instanceNftId,
                expectedRewards,
                reserveAmount));

        vm.startPrank(staker);
        stakingService.claimRewards(stakeNftId);
        vm.stopPrank();
    }

    // solhint-disable-next-line func-name-mixedcase
    function test_restake_happyCase() public {
        // GIVEN

        // create a second instance - restake target
        vm.startPrank(instanceOwner2);
        (instance2, instanceNftId2) = instanceService.createInstance();
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
        vm.expectEmit(true, true, true, false);
        emit IStakingService.LogStakingServiceStakeRestaked(staker, stakeNftId, zeroNftId, instanceNftId2, dipAmount); // newStakeNftId is set to zero because we don't know it yet

        // WHEN - restake to new target
        (NftId stakeNftId2, Amount restakedAmount) = stakingService.restakeToNewTarget(stakeNftId, instanceNftId2);

        // THEN - check restake only created new staked and changed counters nothing else, especially no tokens moved
        assertTrue(stakeNftId2.gtz());
        assertEq(dipAmount.toInt(), restakedAmount.toInt());

        // check balances after staking - no tokens mived
        assertEq(dip.balanceOf(staker), 0, "staker: unexpected dip balance (after staking)");
        assertEq(dip.balanceOf(staking.getWallet()), dipAmount.toInt(), "staking wallet: unexpected dip balance (after staking)");

        // check stake balance after restake
        assertEq(stakingReader.getStakeBalance(stakeNftId).toInt(), 0, "unexpected stake amount");
        assertEq(stakingReader.getRewardBalance(stakeNftId).toInt(), 0, "unexpected reward amount");
        assertEq(stakingReader.getStakeBalance(stakeNftId2).toInt(), dipAmount.toInt(), "unexpected stake amount (2)");
        assertEq(stakingReader.getRewardBalance(stakeNftId2).toInt(), 0, "unexpected reward amount (2)");

        // check state info
        IStaking.StakeInfo memory stakeInfo2 = stakingReader.getStakeInfo(stakeNftId2);
        assertEq(stakeInfo2.lockedUntil.toInt(), TimestampLib.blockTimestamp().toInt() + lockingPeriod2.toInt(), "unexpected locked until (2)");

        // check accumulated stakes/rewards on instance and instance2
        assertEq(stakingReader.getStakeBalance(instanceNftId).toInt(), 0, "unexpected instance stake amount");
        assertEq(stakingReader.getRewardBalance(instanceNftId).toInt(), 0, "unexpected instance reward amount");
        assertEq(stakingReader.getBalanceUpdatedIn(instanceNftId).toInt(), block.number, "unexpected instance last updated in");

        assertEq(stakingReader.getStakeBalance(instanceNftId2).toInt(), dipAmount.toInt(), "unexpected instance stake amount (2)");
        assertEq(stakingReader.getRewardBalance(instanceNftId2).toInt(), 0, "unexpected instance reward amount (2)");
        assertEq(stakingReader.getBalanceUpdatedIn(instanceNftId2).toInt(), block.number, "unexpected instance last updated in (2)");
    }

    // solhint-disable-next-line func-name-mixedcase
    function test_restake_withRewards() public {
        // GIVEN

        // create a second instance - restake target
        vm.startPrank(instanceOwner2);
        (instance2, instanceNftId2) = instanceService.createInstance();
        Seconds lockingPeriod2 = stakingReader.getTargetInfo(instanceNftId2).lockingPeriod;
        vm.stopPrank();

        (, Amount dipAmount) = _prepareAccount(staker, 3000);

        // set reward rate
        vm.startPrank(instanceOwner);
        instance.setStakingRewardRate(UFixedLib.toUFixed(1, -1)); // 10% reward rate
        vm.stopPrank();

        vm.startPrank(staker);

        // create initial instance stake
        NftId stakeNftId = stakingService.create(
            instanceNftId, 
            dipAmount);

        // wait some time
        _wait(SecondsLib.oneYear());
        NftId zeroNftId = NftIdLib.zero();
        
        // WHEN - restake to new target
        (NftId stakeNftId2, Amount restakedAmount) = stakingService.restakeToNewTarget(stakeNftId, instanceNftId2);

        // THEN - check restake only created new staked and changed counters nothing else, especially no tokens moved
        Amount expectedReward = dipAmount.multiplyWith(UFixedLib.toUFixed(1, -1)); // 10% over one year

        assertTrue(stakeNftId2.gtz());
        assertEq(dipAmount.toInt()  + expectedReward.toInt(), restakedAmount.toInt(), "restaked amount invalid");

        // check balances after staking - no tokens mived
        assertEq(dip.balanceOf(staker), 0, "staker: unexpected dip balance (after staking)");
        assertEq(dip.balanceOf(staking.getWallet()), dipAmount.toInt(), "staking wallet: unexpected dip balance (after staking)");

        // check stake balance after restake
        assertEq(stakingReader.getStakeBalance(stakeNftId).toInt(), 0, "unexpected stake amount");
        assertEq(stakingReader.getRewardBalance(stakeNftId).toInt(), 0, "unexpected reward amount");
        assertEq(stakingReader.getStakeBalance(stakeNftId2).toInt(), dipAmount.toInt() + expectedReward.toInt(), "unexpected stake amount (2)");
        assertEq(stakingReader.getRewardBalance(stakeNftId2).toInt(), 0, "unexpected reward amount (2)");

        // check state info
        IStaking.StakeInfo memory stakeInfo2 = stakingReader.getStakeInfo(stakeNftId2);
        assertEq(stakeInfo2.lockedUntil.toInt(), TimestampLib.blockTimestamp().toInt() + lockingPeriod2.toInt(), "unexpected locked until (2)");

        // check accumulated stakes/rewards on instance and instance2
        assertEq(stakingReader.getStakeBalance(instanceNftId).toInt(), 0, "unexpected instance stake amount");
        assertEq(stakingReader.getRewardBalance(instanceNftId).toInt(), 0, "unexpected instance reward amount");
        assertEq(stakingReader.getBalanceUpdatedIn(instanceNftId).toInt(), block.number, "unexpected instance last updated in");

        assertEq(stakingReader.getStakeBalance(instanceNftId2).toInt(), dipAmount.toInt() + expectedReward.toInt(), "unexpected instance stake amount (2)");
        assertEq(stakingReader.getRewardBalance(instanceNftId2).toInt(), 0, "unexpected instance reward amount (2)");
        assertEq(stakingReader.getBalanceUpdatedIn(instanceNftId2).toInt(), block.number, "unexpected instance last updated in (2)");
    }

    // solhint-disable-next-line func-name-mixedcase
    function test_restake_alreadyStakedTarget() public {
        // GIVEN

        // create a second instance - restake target
        vm.startPrank(instanceOwner2);
        (instance2, instanceNftId2) = instanceService.createInstance();
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

        Timestamp initialTime = TimestampLib.blockTimestamp();

        // wait some time
        _wait(SecondsLib.oneYear());
        
        // WHEN - restake to target
        (NftId stakeNftId3, Amount restakedAmount) = stakingService.restakeToNewTarget(stakeNftId, instanceNftId2);

        // THEN - check restake only created new staked and changed counters nothing else, especially no tokens moved
        assertTrue(stakeNftId2.gtz());
        assertEq(oneThousand.toInt(), restakedAmount.toInt());

        // check balances after staking - no tokens mived
        assertEq(dip.balanceOf(staker), 0, "staker: unexpected dip balance (after staking)");
        assertEq(dip.balanceOf(staking.getWallet()), dipAmount.toInt(), "staking wallet: unexpected dip balance (after staking)");

        // check stake balance after restake
        assertEq(stakingReader.getStakeBalance(stakeNftId).toInt(), 0, "unexpected stake amount");
        assertEq(stakingReader.getRewardBalance(stakeNftId).toInt(), 0, "unexpected reward amount");
        assertEq(stakingReader.getStakeBalance(stakeNftId2).toInt(), twoThousand.toInt(), "unexpected stake amount (2)");
        assertEq(stakingReader.getRewardBalance(stakeNftId2).toInt(), 0, "unexpected reward amount (2)");
        assertEq(stakingReader.getStakeBalance(stakeNftId3).toInt(), oneThousand.toInt(), "unexpected stake amount (3)");
        assertEq(stakingReader.getRewardBalance(stakeNftId3).toInt(), 0, "unexpected reward amount (3)");

        // check state info
        IStaking.StakeInfo memory stakeInfo2 = stakingReader.getStakeInfo(stakeNftId2);
        assertEq(stakeInfo2.lockedUntil.toInt(), initialTime.toInt() + lockingPeriod2.toInt(), "unexpected locked until (2)");
        IStaking.StakeInfo memory stakeInfo3 = stakingReader.getStakeInfo(stakeNftId3);
        assertEq(stakeInfo3.lockedUntil.toInt(), TimestampLib.blockTimestamp().toInt() + lockingPeriod2.toInt(), "unexpected locked until (3)");

        // check accumulated stakes/rewards on instance and instance2
        assertEq(stakingReader.getStakeBalance(instanceNftId).toInt(), 0, "unexpected instance stake amount");
        assertEq(stakingReader.getRewardBalance(instanceNftId).toInt(), 0, "unexpected instance reward amount");
        assertEq(stakingReader.getBalanceUpdatedIn(instanceNftId).toInt(), block.number, "unexpected instance last updated in");

        assertEq(stakingReader.getStakeBalance(instanceNftId2).toInt(), dipAmount.toInt(), "unexpected instance stake amount (2)");
        assertEq(stakingReader.getRewardBalance(instanceNftId2).toInt(), 0, "unexpected instance reward amount (2)");
        assertEq(stakingReader.getBalanceUpdatedIn(instanceNftId2).toInt(), block.number, "unexpected instance last updated in (2)");
    }


    // solhint-disable-next-line func-name-mixedcase
    function test_restake_invalidNftType() public {
        // GIVEN

        // create a second instance - restake target
        vm.startPrank(instanceOwner2);
        (instance2, instanceNftId2) = instanceService.createInstance();
        Seconds lockingPeriod2 = stakingReader.getTargetInfo(instanceNftId2).lockingPeriod;
        vm.stopPrank();

        (, Amount dipAmount) = _prepareAccount(staker, 3000);

        vm.startPrank(instanceOwner);

        // THEN
        vm.expectRevert(abi.encodeWithSelector(
            INftOwnable.ErrorNftOwnableInvalidType.selector, 
            instanceNftId,
            30));

        // WHEN - restake to new target
        stakingService.restakeToNewTarget(instanceNftId, instanceNftId2);
    }

    // solhint-disable-next-line func-name-mixedcase
    function test_restake_notOwner() public {
        // GIVEN

        // create a second instance - restake target
        vm.startPrank(instanceOwner2);
        (instance2, instanceNftId2) = instanceService.createInstance();
        Seconds lockingPeriod2 = stakingReader.getTargetInfo(instanceNftId2).lockingPeriod;
        vm.stopPrank();

        (, Amount dipAmount) = _prepareAccount(staker, 3000);

        vm.startPrank(staker);

        // THEN
        vm.expectRevert(abi.encodeWithSelector(
            INftOwnable.ErrorNftOwnableNotOwner.selector, 
            staker));

        // WHEN - restake to new target
        stakingService.restakeToNewTarget(instanceNftId, instanceNftId2);
    }


    /// @dev test restaking when the stake is still locked
    // solhint-disable-next-line func-name-mixedcase
    function test_restake_stakeLocked() public {
        // GIVEN

        // create a second instance - restake target
        vm.startPrank(instanceOwner2);
        (instance2, instanceNftId2) = instanceService.createInstance();
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
            TimestampLib.blockTimestamp().addSeconds(lockingPeriod)));

        // WHEN - restake to new target
        stakingService.restakeToNewTarget(stakeNftId, instanceNftId2);
    }

    /// @dev test restaking and exceeding the max staked amount
    // solhint-disable-next-line func-name-mixedcase
    function test_restake_maxStakedAmountExceeded() public {
        // GIVEN

        (, Amount dipAmount) = _prepareAccount(staker, 3000);

        vm.startPrank(instanceOwner);
        instance.setStakingRewardRate(UFixedLib.zero()); // no rewards
        vm.stopPrank();

        // create a second instance - restake target
        vm.startPrank(instanceOwner2);
        (instance2, instanceNftId2) = instanceService.createInstance();
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
        stakingService.restakeToNewTarget(stakeNftId, instanceNftId2);
    }

    /// @dev test restaking when the target is an unknown nft
    // solhint-disable-next-line func-name-mixedcase
    function test_restake_invalidTarget() public {
        // GIVEN

        // create a second instance - restake target
        vm.startPrank(instanceOwner2);
        (instance2, instanceNftId2) = instanceService.createInstance();
        Seconds lockingPeriod = stakingReader.getTargetInfo(instanceNftId).lockingPeriod;
        vm.stopPrank();

        (, Amount dipAmount) = _prepareAccount(staker, 3000);

        vm.startPrank(staker);

        // create initial instance stake
        NftId stakeNftId = stakingService.create(
            instanceNftId, 
            dipAmount);
        NftId targetNftId = NftIdLib.zero();

        // THEN
        vm.expectRevert(abi.encodeWithSelector(
            IStakingService.ErrorStakingServiceTargetUnknown.selector, 
            targetNftId));

        // WHEN - restake to new target
        stakingService.restakeToNewTarget(stakeNftId, targetNftId);
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