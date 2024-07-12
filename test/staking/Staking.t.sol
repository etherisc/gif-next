// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../../lib/forge-std/src/Test.sol";

import {Amount, AmountLib} from "../../contracts/type/Amount.sol";
import {GifTest} from "../base/GifTest.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {IStaking} from "../../contracts/staking/IStaking.sol";
import {IStakingService} from "../../contracts/staking/IStakingService.sol";
import {NftId} from "../../contracts/type/NftId.sol";
import {INSTANCE, PROTOCOL, SERVICE, STAKE, STAKING} from "../../contracts/type/ObjectType.sol";
import {Seconds, SecondsLib} from "../../contracts/type/Seconds.sol";
import {StakeManagerLib} from "../../contracts/staking/StakeManagerLib.sol";
import {StakingStore} from "../../contracts/staking/StakingStore.sol";
import {TargetManagerLib} from "../../contracts/staking/TargetManagerLib.sol";
import {Timestamp, TimestampLib} from "../../contracts/type/Timestamp.sol";
import {TokenHandler} from "../../contracts/shared/TokenHandler.sol";
import {UFixed, UFixedLib} from "../../contracts/type/UFixed.sol";
import {VersionPart} from "../../contracts/type/Version.sol";


contract Staking is GifTest {

    uint256 public constant STAKING_WALLET_APPROVAL = 5000;


    function test_stakingStakeCreateProtocolStake() public {

        NftId protocolNftId = core.stakingReader.getTargetNftId(0);
        (TokenHandler tokenHandler, Amount dipAmount) = _prepareAccount(staker, 5000);

        // check balances before staking
        assertTrue(staker != core.staking.getWallet(), "staker and staking wallet the same");
        assertEq(core.dip.balanceOf(staker), dipAmount.toInt(), "staker: unexpected dip balance");
        assertEq(core.dip.balanceOf(core.staking.getWallet()), 0, "staking wallet: unexpected dip balance");

        vm.startPrank(staker);

        // create stake
        NftId stakeNftId = stakingService.create(
            protocolNftId, 
            dipAmount);

        vm.stopPrank();

        // check balances after staking
        assertEq(core.dip.balanceOf(staker), 0, "staker: unexpected dip balance (after staking)");
        assertEq(core.dip.balanceOf(core.staking.getWallet()), dipAmount.toInt(), "staking wallet: unexpected dip balance (after staking)");

        // check ownership
        assertTrue(stakeNftId.gtz(), "stake nft id zero");
        assertEq(core.registry.ownerOf(stakeNftId), staker, "unexpected stake nft owner");
        
        // check object info (registry entry)
        IRegistry.ObjectInfo memory objectInfo = core.registry.getObjectInfo(stakeNftId);
        assertEq(objectInfo.nftId.toInt(), stakeNftId.toInt(), "unexpected stake nft id");
        assertEq(objectInfo.parentNftId.toInt(), protocolNftId.toInt(), "unexpected parent nft id");
        assertEq(objectInfo.objectType.toInt(), STAKE().toInt(), "unexpected object type");
        assertFalse(objectInfo.isInterceptor, "stake as interceptor");
        assertEq(objectInfo.objectAddress, address(0), "stake object address non zero");
        assertEq(objectInfo.initialOwner, staker, "unexpected initial stake owner");
        assertEq(bytes(objectInfo.data).length, 0, "unexpected data size");

        Seconds lockingPeriod = core.stakingReader.getTargetInfo(protocolNftId).lockingPeriod;
        assertEq(lockingPeriod.toInt(), TargetManagerLib.getDefaultLockingPeriod().toInt(), "unexpected locking period");

        // check stake balance
        assertEq(core.stakingReader.getStakeBalance(stakeNftId).toInt(), dipAmount.toInt(), "unexpected stake amount");
        assertEq(core.stakingReader.getRewardBalance(stakeNftId).toInt(), 0, "unexpected reward amount");
        assertEq(core.stakingReader.getBalanceUpdatedAt(stakeNftId).toInt(), block.timestamp, "unexpected last updated at");

        // check state info
        IStaking.StakeInfo memory stakeInfo = core.stakingReader.getStakeInfo(stakeNftId);
        assertTrue(stakeInfo.lockedUntil.gtz(), "locked until zero");
        assertEq(stakeInfo.lockedUntil.toInt(), TimestampLib.blockTimestamp().toInt() + lockingPeriod.toInt(), "unexpected locked until");
    }


    function test_stakingStakeCreateInstanceStake() public {

        (TokenHandler tokenHandler, Amount dipAmount) = _prepareAccount(staker2, 3000);

        // check balances after staking
        assertEq(core.dip.balanceOf(staker2), dipAmount.toInt(), "staker2: unexpected dip balance (before staking)");
        assertEq(core.dip.balanceOf(core.staking.getWallet()), 0, "staking wallet: unexpected dip balance (before staking)");

        vm.startPrank(staker2);

        // create instance stake
        NftId stakeNftId = stakingService.create(
            instanceNftId, 
            dipAmount);

        vm.stopPrank();

        // check balances after staking
        assertEq(core.dip.balanceOf(staker2), 0, "staker: unexpected dip balance (after staking)");
        assertEq(core.dip.balanceOf(core.staking.getWallet()), dipAmount.toInt(), "staking wallet: unexpected dip balance (after staking)");

        // check ownership
        assertTrue(stakeNftId.gtz(), "stake nft id zero");
        assertEq(core.registry.ownerOf(stakeNftId), staker2, "unexpected stake nft owner");
        
        // check object info (registry entry)
        IRegistry.ObjectInfo memory objectInfo = core.registry.getObjectInfo(stakeNftId);
        assertEq(objectInfo.nftId.toInt(), stakeNftId.toInt(), "unexpected stake nft id");
        assertEq(objectInfo.parentNftId.toInt(), instanceNftId.toInt(), "unexpected parent nft id");
        assertEq(objectInfo.objectType.toInt(), STAKE().toInt(), "unexpected object type");
        assertFalse(objectInfo.isInterceptor, "stake as interceptor");
        assertEq(objectInfo.objectAddress, address(0), "stake object address non zero");
        assertEq(objectInfo.initialOwner, staker2, "unexpected initial stake owner");
        assertEq(bytes(objectInfo.data).length, 0, "unexpected data size");

        Seconds lockingPeriod = core.stakingReader.getTargetInfo(instanceNftId).lockingPeriod;
        assertEq(lockingPeriod.toInt(), TargetManagerLib.getDefaultLockingPeriod().toInt(), "unexpected locking period");

        // check stake balance
        assertEq(core.stakingReader.getStakeBalance(stakeNftId).toInt(), dipAmount.toInt(), "unexpected stake amount");
        assertEq(core.stakingReader.getRewardBalance(stakeNftId).toInt(), 0, "unexpected reward amount");
        assertEq(core.stakingReader.getBalanceUpdatedAt(stakeNftId).toInt(), block.timestamp, "unexpected last updated at");

        // check state info
        IStaking.StakeInfo memory stakeInfo = core.stakingReader.getStakeInfo(stakeNftId);
        assertTrue(stakeInfo.lockedUntil.gtz(), "locked until zero");
        assertEq(stakeInfo.lockedUntil.toInt(), TimestampLib.blockTimestamp().toInt() + lockingPeriod.toInt(), "unexpected locked until");

        // check accumulated stakes/rewards on instance
        assertEq(core.stakingReader.getStakeBalance(instanceNftId).toInt(), dipAmount.toInt(), "unexpected instance stake amount");
        assertEq(core.stakingReader.getRewardBalance(instanceNftId).toInt(), 0, "unexpected instance reward amount");
        assertEq(core.stakingReader.getBalanceUpdatedIn(instanceNftId).toInt(), block.number, "unexpected instance last updated in");
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
        assertEq(core.stakingReader.getBalanceUpdatedAt(stakeNftId).toInt(), lastUpdateAt, "unexpected last updated at for stake balance");

        // WHEN
        // wait a year
        _wait(SecondsLib.oneYear());

        assertTrue(lastUpdateIn < block.number, "blocknumber not increased");

        // THEN
        // check one year passed
        assertEq(block.timestamp - SecondsLib.oneYear().toInt(), lastUpdateAt, "unexpected year duration");

        // check reward calculations after one year
        uint256 expectedRewardIncrementInFullDip = 50; // 50 = 5% of 1000 for a year
        UFixed rewardRate = core.stakingReader.getRewardRate(instanceNftId);
        assertEq(_times1000(rewardRate), expectedRewardIncrementInFullDip, "unexpected instance reward rate");

        // check expected reward increase (version 1)
        Amount expectedRewardIncrease = StakeManagerLib.calculateRewardAmount(
            rewardRate,
            SecondsLib.oneYear(),
            dipAmount);

        uint256 expectedRewardIncreaseInt = expectedRewardIncrementInFullDip * 10 ** core.dip.decimals();
        assertEq(expectedRewardIncrease.toInt(), expectedRewardIncreaseInt, "unexpected 'expected' reward increase");

        // check expected reward increase (version 2)
        (
            Amount rewardIncrease,
        ) = StakeManagerLib.calculateRewardIncrease(
            core.stakingReader,
            stakeNftId,
            rewardRate);

        assertTrue(rewardIncrease.gtz(), "reward increase zero");
        assertEq(rewardIncrease.toInt(), expectedRewardIncreaseInt, "unexpected reward increase");

        // check stake/rewards balance (before calling update rewards)
        assertEq(core.stakingReader.getStakeBalance(stakeNftId).toInt(), dipAmount.toInt(), "unexpected stake amount (before)");
        assertEq(core.stakingReader.getRewardBalance(stakeNftId).toInt(), 0, "unexpected reward amount (before)");
        assertEq(core.stakingReader.getBalanceUpdatedAt(stakeNftId).toInt(), lastUpdateAt, "unexpected last updated at (before)");

        // check accumulated stakes/rewards on instance
        assertEq(core.stakingReader.getStakeBalance(instanceNftId).toInt(), dipAmount.toInt(), "unexpected instance stake amount (before)");
        assertEq(core.stakingReader.getRewardBalance(instanceNftId).toInt(), 0, "unexpected instance reward amount (before)");
        assertEq(core.stakingReader.getBalanceUpdatedIn(instanceNftId).toInt(), lastUpdateIn, "unexpected instance last updated at (before)");

        // WHEN
        // update rewards (unpermissioned)
        stakingService.updateRewards(stakeNftId);

        // THEN
        // re-check stake/rewards balance (after calling update rewards)
        assertEq(core.stakingReader.getStakeBalance(stakeNftId).toInt(), dipAmount.toInt(), "unexpected stake amount (after)");
        assertEq(core.stakingReader.getRewardBalance(stakeNftId).toInt(), expectedRewardIncrease.toInt(), "unexpected reward amount (after)");
        assertEq(core.stakingReader.getBalanceUpdatedAt(stakeNftId).toInt(), block.timestamp, "unexpected last updated at (after)");

        // re-check accumulated stakes/rewards on instance
        assertEq(core.stakingReader.getStakeBalance(instanceNftId).toInt(), dipAmount.toInt(), "unexpected instance stake amount (after)");
        assertEq(core.stakingReader.getRewardBalance(instanceNftId).toInt(), expectedRewardIncrease.toInt(), "unexpected instance reward amount (after)");
        assertEq(core.stakingReader.getBalanceUpdatedIn(instanceNftId).toInt(), block.number, "unexpected instance last updated at (after)");
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
        UFixed rewardRate = core.stakingReader.getTargetInfo(instanceNftId).rewardRate;
        (
            Amount rewardIncrease,
            Amount totalDipAmount
        ) = StakeManagerLib.calculateRewardIncrease(
            core.stakingReader,
            stakeNftId,
            rewardRate);
        
        Amount expectedRewardIncrease = StakeManagerLib.calculateRewardAmount(
            rewardRate,
            SecondsLib.oneYear(),
            dipAmount);

        assertEq(expectedRewardIncrease.toInt(), 50 * 10**core.dip.decimals(), "unexpected 'expected' reward increase");
        assertTrue(rewardIncrease.gtz(), "reward increase zero");
        assertEq(rewardIncrease.toInt(), expectedRewardIncrease.toInt(), "unexpected rewared increase");

        // check stake/rewards balance (before calling restake)
        assertEq(core.stakingReader.getStakeBalance(stakeNftId).toInt(), dipAmount.toInt(), "unexpected stake amount (before)");
        assertEq(core.stakingReader.getRewardBalance(stakeNftId).toInt(), 0, "unexpected reward amount (before)");
        assertEq(core.stakingReader.getBalanceUpdatedAt(stakeNftId).toInt(), lastUpdateAt, "unexpected last updated at (before)");

        // time now
        Timestamp timestampNow = TimestampLib.blockTimestamp();

        // restake rewards
        vm.startPrank(staker);
        stakingService.stake(stakeNftId, AmountLib.zero());
        vm.stopPrank();

        // check stake/rewards balance (after calling restake)
        Amount expectedRestakedAmount = dipAmount + expectedRewardIncrease;
        assertEq(core.stakingReader.getStakeBalance(stakeNftId).toInt(), expectedRestakedAmount.toInt(), "unexpected stake amount (after restake)");
        assertEq(core.stakingReader.getRewardBalance(stakeNftId).toInt(), 0, "unexpected reward amount (after restake)");
        assertEq(core.stakingReader.getBalanceUpdatedAt(stakeNftId).toInt(), block.timestamp, "unexpected last updated at (after)");

        // check locked until
        Seconds lockingPeriod = core.stakingReader.getTargetInfo(instanceNftId).lockingPeriod;
        Timestamp lockedUntilAfter = core.stakingReader.getStakeInfo(stakeNftId).lockedUntil;
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
        UFixed rewardRate = core.stakingReader.getTargetInfo(instanceNftId).rewardRate;
        (
            Amount rewardIncrease,
            Amount totalDipAmount
        ) = StakeManagerLib.calculateRewardIncrease(
            core.stakingReader,
            stakeNftId,
            rewardRate);
        
        Amount expectedRewardIncrease = StakeManagerLib.calculateRewardAmount(
            rewardRate,
            SecondsLib.oneYear(),
            dipAmount);

        assertEq(expectedRewardIncrease.toInt(), 50 * 10**core.dip.decimals(), "unexpected 'expected' reward increase");
        assertTrue(rewardIncrease.gtz(), "reward increase zero");
        assertEq(rewardIncrease.toInt(), expectedRewardIncrease.toInt(), "unexpected rewared increase");

        // check stake/rewards balance (before calling restake)
        assertEq(core.stakingReader.getStakeBalance(stakeNftId).toInt(), dipAmount.toInt(), "unexpected stake amount (before)");
        assertEq(core.stakingReader.getRewardBalance(stakeNftId).toInt(), 0, "unexpected reward amount (before)");
        assertEq(core.stakingReader.getBalanceUpdatedAt(stakeNftId).toInt(), lastUpdateAt, "unexpected last updated at (before)");

        // time now
        Timestamp timestampNow = TimestampLib.blockTimestamp();

        // increase stakes and restake rewards
        (, Amount stakeIncreaseAmount) = _prepareAccount(staker, 1500, true, true);

        vm.startPrank(staker);
        stakingService.stake(stakeNftId, stakeIncreaseAmount);
        vm.stopPrank();

        // check stake/rewards balance (after calling restake)
        Amount newBalanceWithRestakedDipsAmount = dipAmount + stakeIncreaseAmount + expectedRewardIncrease;
        assertEq(core.stakingReader.getStakeBalance(stakeNftId).toInt(), newBalanceWithRestakedDipsAmount.toInt(), "unexpected stake amount (after restake)");
        assertEq(core.stakingReader.getRewardBalance(stakeNftId).toInt(), 0, "unexpected reward amount (after restake)");
        assertEq(core.stakingReader.getBalanceUpdatedAt(stakeNftId).toInt(), block.timestamp, "unexpected last updated at (after)");

        // check locked until
        Seconds lockingPeriod = core.stakingReader.getTargetInfo(instanceNftId).lockingPeriod;
        Timestamp lockedUntilAfter = core.stakingReader.getStakeInfo(stakeNftId).lockedUntil;
        Timestamp expectedLockedUntil = timestampNow.addSeconds(lockingPeriod);
        assertEq(lockedUntilAfter.toInt(), expectedLockedUntil.toInt(), "unexpected updated lockedUntil");
    }


    function test_stakingStakeUnstake() public {

        // GIVEN
        (
            ,
            Amount stakeAmount,
            NftId stakeNftId
        ) = _prepareStake(staker, instanceNftId, 1000);

        uint256 lastUpdateAt = block.timestamp;

        (, Amount reserveAmount,) = _addRewardReserves(instanceNftId, instanceOwner, 500);
        assertEq(core.stakingReader.getReserveBalance(instanceNftId).toInt(), reserveAmount.toInt(), "unexpected reserve balance (initial)");

        // dip balance of staker after staking
        assertEq(core.dip.balanceOf(staker), 0, "unexpected staker balance after staking");

        // wait a year
        _wait(SecondsLib.oneYear());

        // check balance before (= 0)
        assertEq(core.dip.balanceOf(staker), 0, "staker dip balance not 0 (before unstake)");

        // check stake/rewards balance (before unstake)
        assertEq(core.stakingReader.getStakeBalance(stakeNftId).toInt(), stakeAmount.toInt(), "unexpected stake amount (before unstake)");
        assertEq(core.stakingReader.getRewardBalance(stakeNftId).toInt(), 0, "unexpected reward amount (before unstake)");
        assertEq(core.stakingReader.getBalanceUpdatedAt(stakeNftId).toInt(), lastUpdateAt, "unexpected last updated at (before unstake)");

        // WHEN
        vm.startPrank(staker);
        stakingService.unstake(stakeNftId);
        vm.stopPrank();

        // THEN
        // get and check instance reward rate
        UFixed rewardRate = core.stakingReader.getRewardRate(instanceNftId);
        assertTrue(rewardRate.gtz(), "instance reward rate 0");
        assertEq(_times1000(rewardRate), 50, "unexpected instance reward rate");

        // check balance after unstake
        Amount expectedBalanceAfterUnstake = stakeAmount.multiplyWith(
            UFixedLib.toUFixed(1) + rewardRate);
        
        assertTrue(expectedBalanceAfterUnstake > stakeAmount, "no rewards accumulated");

        // check reduced reward reserves
        Amount rewardAmount = expectedBalanceAfterUnstake - stakeAmount;
        Amount remainingReserveAmount = reserveAmount - rewardAmount;
        assertEq(core.stakingReader.getReserveBalance(instanceNftId).toInt(), remainingReserveAmount.toInt(), "unexpected reserve balance after unstake");

        // dip balance of staker after unstake
        assertEq(core.dip.balanceOf(staker), expectedBalanceAfterUnstake.toInt(), "unexpected staker balance after unstake");

        // check stake/rewards balance (after unstake)
        assertEq(core.stakingReader.getStakeBalance(stakeNftId).toInt(), 0, "unexpected stake amount (after unstake)");
        assertEq(core.stakingReader.getRewardBalance(stakeNftId).toInt(), 0, "unexpected reward amount (after unstake)");
        assertEq(core.stakingReader.getBalanceUpdatedAt(stakeNftId).toInt(), block.timestamp, "unexpected last updated at (after unstake)");

        // check accumulated stakes/rewards on instance(after unstake)
        assertEq(core.stakingReader.getStakeBalance(instanceNftId).toInt(), 0, "unexpected instance stake amount (after unstake)");
        assertEq(core.stakingReader.getRewardBalance(instanceNftId).toInt(), 0, "unexpected instance reward amount (after unstake)");
        assertEq(core.stakingReader.getBalanceUpdatedIn(instanceNftId).toInt(), block.number, "unexpected instance last updated in (after unstake)");
    }


    function test_stakingStakeClaimRewardsHappyCase() public {

        // GIVEN
        (
            ,
            Amount stakeAmount,
            NftId stakeNftId
        ) = _prepareStake(staker, instanceNftId, 1000);

        uint256 lastUpdateAt = block.timestamp;

        (, Amount reserveAmount,) = _addRewardReserves(instanceNftId, instanceOwner, 500);
        assertEq(core.stakingReader.getReserveBalance(instanceNftId).toInt(), reserveAmount.toInt(), "unexpected reserve balance (initial)");

        // dip balance of staker after staking
        assertEq(core.dip.balanceOf(staker), 0, "unexpected staker balance after staking");

        // wait a year
        _wait(SecondsLib.oneYear());

        // check balance before (= 0)
        assertEq(core.dip.balanceOf(staker), 0, "staker dip balance not 0 (before unstake)");

        // check stake/rewards balance (before unstake)
        assertEq(core.stakingReader.getStakeBalance(stakeNftId).toInt(), stakeAmount.toInt(), "unexpected stake amount (before unstake)");
        assertEq(core.stakingReader.getRewardBalance(stakeNftId).toInt(), 0, "unexpected reward amount (before unstake)");
        assertEq(core.stakingReader.getBalanceUpdatedAt(stakeNftId).toInt(), lastUpdateAt, "unexpected last updated at (before unstake)");

        // WHEN
        vm.startPrank(staker);
        stakingService.claimRewards(stakeNftId);
        vm.stopPrank();

        // THEN
        // get and check instance reward rate
        UFixed rewardRate = core.stakingReader.getRewardRate(instanceNftId);

        // check balance after claim rewards
        Amount expectedRewards = stakeAmount.multiplyWith(rewardRate);
        
        assertTrue(expectedRewards.gtz(), "no rewards accumulated");

        // check reduced reward reserves
        Amount remainingReserveAmount = reserveAmount - expectedRewards;
        assertEq(core.stakingReader.getReserveBalance(instanceNftId).toInt(), remainingReserveAmount.toInt(), "unexpected reserve balance after claim rewards");

        // dip balance of staker after claim rewards
        assertEq(core.dip.balanceOf(staker), expectedRewards.toInt(), "unexpected staker balance after claim rewards");

        // check stake/rewards balance (after claim rewards)
        assertEq(core.stakingReader.getStakeBalance(stakeNftId).toInt(), stakeAmount.toInt(), "unexpected stake amount (after claim rewards)");
        assertEq(core.stakingReader.getRewardBalance(stakeNftId).toInt(), 0, "unexpected reward amount (after claim rewards)");
        assertEq(core.stakingReader.getBalanceUpdatedAt(stakeNftId).toInt(), block.timestamp, "unexpected last updated at (after claim rewards)");

        // check accumulated stakes/rewards on instance(after claim rewards)
        assertEq(core.stakingReader.getStakeBalance(instanceNftId).toInt(), stakeAmount.toInt(), "unexpected instance stake amount (after claim rewards)");
        assertEq(core.stakingReader.getRewardBalance(instanceNftId).toInt(), 0, "unexpected instance reward amount (after claim rewards)");
        assertEq(core.stakingReader.getBalanceUpdatedIn(instanceNftId).toInt(), block.number, "unexpected instance last updated in (after claim rewards)");
    }


    function test_stakingStakeClaimRewardsInsufficientReserves() public {

        // GIVEN
        (
            ,
            Amount stakeAmount,
            NftId stakeNftId
        ) = _prepareStake(staker, instanceNftId, 1000);

        uint256 lastUpdateAt = block.timestamp;

        (, Amount reserveAmount,) = _addRewardReserves(instanceNftId, instanceOwner, 10);
        assertEq(core.stakingReader.getReserveBalance(instanceNftId).toInt(), reserveAmount.toInt(), "unexpected reserve balance (initial)");

        // dip balance of staker after staking
        assertEq(core.dip.balanceOf(staker), 0, "unexpected staker balance after staking");

        // wait a year
        _wait(SecondsLib.oneYear());

        // check balance before (= 0)
        assertEq(core.dip.balanceOf(staker), 0, "staker dip balance not 0 (before unstake)");

        // check stake/rewards balance (before unstake)
        assertEq(core.stakingReader.getStakeBalance(stakeNftId).toInt(), stakeAmount.toInt(), "unexpected stake amount (before unstake)");
        assertEq(core.stakingReader.getRewardBalance(stakeNftId).toInt(), 0, "unexpected reward amount (before unstake)");
        assertEq(core.stakingReader.getBalanceUpdatedAt(stakeNftId).toInt(), lastUpdateAt, "unexpected last updated at (before unstake)");

        UFixed rewardRate = core.stakingReader.getRewardRate(instanceNftId);
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


    function setUp() public override {
        super.setUp();

        // set staking wallet approval for staking token handler
        vm.startPrank(registryOwner);
        core.staking.approveTokenHandler(AmountLib.max());
        vm.stopPrank();
    }


    function _addRewardReserves(
        NftId instanceNftId, 
        address instanceOwner, 
        uint256 amount
    )
        internal
        returns(
            TokenHandler tokenHandler,
            Amount dipAmount,
            NftId stakeNftId
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
        dipAmount = AmountLib.toAmount(myStakeAmount * 10 ** core.dip.decimals());

        if (withFunding) {
            vm.startPrank(registryOwner);
            core.dip.transfer(myStaker, dipAmount.toInt());
            vm.stopPrank();
        }

        if (withApproval) {
            vm.startPrank(myStaker);
            core.dip.approve(address(tokenHandler), dipAmount.toInt());
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