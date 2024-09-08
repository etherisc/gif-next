// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount, AmountLib} from "../type/Amount.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {IStaking} from "./IStaking.sol";
import {NftId} from "../type/NftId.sol";
import {Seconds, SecondsLib} from "../type/Seconds.sol";
import {StakingReader} from "./StakingReader.sol";
import {StakingStore} from "./StakingStore.sol";
import {Timestamp, TimestampLib} from "../type/Timestamp.sol";
import {UFixed, UFixedLib} from "../type/UFixed.sol";


library StakingLib {

    // TODO cleanup
    // function stake(
    //     IRegistry registry,
    //     StakingReader stakingReader,
    //     StakingStore stakingStore,
    //     NftId stakeNftId,
    //     Amount stakeAmount
    // )
    //     external
    //     returns (Amount stakeBalance)
    // {
    //     // check that target is active for staking
    //     (
    //         UFixed rewardRate,
    //         Seconds lockingPeriod
    //     ) = checkStakeParameters(
    //         stakingReader, 
    //         stakeNftId);        

    //     // calculate new rewards (if any)
    //     (
    //         Amount rewardIncrementAmount, 
    //         Amount currentTotalDipAmount
    //     ) = calculateRewardIncrease(
    //         stakingReader, 
    //         stakeNftId,
    //         rewardRate);

    //     stakeBalance = currentTotalDipAmount + stakeAmount;

    //     // TODO check that additional dip, rewards and rewards increment 
    //     // are still ok with max target staking amount
    //     NftId targetNftId = registry.getParentNftId(stakeNftId);
    //     Amount maxStakedAmount = stakingReader.getTargetMaxStakedAmount(targetNftId);

    //     if (stakeBalance > maxStakedAmount) {
    //         revert IStaking.ErrorStakingTargetMaxStakedAmountExceeded(targetNftId, maxStakedAmount, stakeBalance);
    //     }

    //     stakingStore.restakeRewards(
    //         stakeNftId, 
    //         targetNftId, 
    //         rewardIncrementAmount);

    //     stakingStore.increaseStake(
    //         stakeNftId, 
    //         targetNftId, 
    //         stakeAmount);

    //     // update locked until with target locking period
    //     stakingStore.update(
    //         stakeNftId, 
    //         IStaking.StakeInfo({
    //             lockedUntil: TimestampLib.current().addSeconds(
    //                 lockingPeriod)}));

    // }

    // function restake(
    //     StakingReader stakingReader,
    //     StakingStore stakingStore,
    //     NftId oldStakeNftId,
    //     NftId newStakeNftId
    // )
    //     external
    //     returns (Amount newStakeBalance)
    // {
    //     checkUnstakeParameters(stakingReader, oldStakeNftId);
    //     (NftId oldTargetNftId, UFixed oldRewardRate) = stakingReader.getTargetRewardRate(oldStakeNftId);
        
    //     // calculate new rewards update and unstake full amount
    //     (
    //         Amount rewardIncrementAmount,
    //     ) = calculateRewardIncrease(
    //         stakingReader, 
    //         oldStakeNftId,
    //         oldRewardRate);
    //     stakingStore.updateRewards(
    //         oldStakeNftId, 
    //         oldTargetNftId, 
    //         rewardIncrementAmount);
    //     (
    //         Amount unstakedAmount, 
    //         Amount rewardsAmount
    //     ) = stakingStore.unstakeUpTo(
    //         oldStakeNftId,
    //         oldTargetNftId,
    //         AmountLib.max(), // unstake all stakes
    //         AmountLib.max()); // claim all rewards

    //     // calculate full restake amount
    //     newStakeBalance = unstakedAmount + rewardsAmount;
    //     NftId newTargetNftId = stakingReader.getTargetNftId(newStakeNftId);
        
    //     // create new staking target and increase stake
    //     Timestamp newLockedUntil = _checkCreateParameters(stakingReader, newTargetNftId, newStakeBalance);
    //     stakingStore.create(
    //         newStakeNftId, 
    //         IStaking.StakeInfo({
    //                 lockedUntil: newLockedUntil
    //             }));
    //     stakingStore.increaseStake(
    //         newStakeNftId, 
    //         newTargetNftId, 
    //         newStakeBalance);
    // }

    function checkCreateParameters(
        StakingReader stakingReader,
        NftId targetNftId, 
        Amount dipAmount
    )
        external
        view
        returns (
            Timestamp lockedUntil
        )
    {
        return _checkCreateParameters(stakingReader, targetNftId, dipAmount);
    }

    function _checkCreateParameters(
        StakingReader stakingReader,
        NftId targetNftId, 
        Amount dipAmount
    )
        internal view
        returns (
            Timestamp lockedUntil
        )
    {
        Seconds lockingPeriod = checkTarget(stakingReader, targetNftId);
        checkDipAmount(stakingReader, targetNftId, dipAmount);

        Timestamp currentTime = TimestampLib.current();
        lockedUntil = currentTime.addSeconds(lockingPeriod);
    }


    function checkStakeParameters(
        StakingReader stakingReader,
        NftId stakeNftId
    )
        public
        view
        returns (
            UFixed rewardRate,
            Seconds lockingPeriod
        )
    {
        NftId targetNftId = stakingReader.getTargetNftId(stakeNftId);

        // target nft id must be registered
        if (!stakingReader.isTarget(targetNftId)) {
            revert IStaking.ErrorStakingNotTarget(targetNftId);
        }
        
        IStaking.TargetInfo memory info = stakingReader.getTargetInfo(targetNftId);
        rewardRate = info.rewardRate;
        lockingPeriod = info.lockingPeriod;
    }

    function checkUnstakeParameters(
        StakingReader stakingReader,
        NftId stakeNftId
    )
        public
        view
        returns (
            Seconds lockingPeriod
        )
    {
        IStaking.StakeInfo memory stakeInfo = stakingReader.getStakeInfo(stakeNftId);
        
        if (stakeInfo.lockedUntil > TimestampLib.current()) {
            revert IStaking.ErrorStakingStakeLocked(stakeNftId, stakeInfo.lockedUntil);
        }
    }


    function checkTarget(
        StakingReader stakingReader,
        NftId targetNftId
    )
        public
        view
        returns (Seconds lockingPeriod)
    {
        // target nft id must be registered
        if (!stakingReader.isTarget(targetNftId)) {
            revert IStaking.ErrorStakingNotTarget(targetNftId);
        }

        lockingPeriod = stakingReader.getTargetInfo(targetNftId).lockingPeriod;
    }


    function checkDipAmount(
        StakingReader stakingReader,
        NftId targetNftId, 
        Amount dipAmount
    )
        public 
        view 
    {
        // check stake amount > 0
        if (dipAmount.eqz()) {
            revert IStaking.ErrorStakingStakeAmountZero(targetNftId);
        }

        Amount maxStakedAmount = stakingReader.getTargetMaxStakedAmount(targetNftId);
        if (dipAmount > maxStakedAmount) {
            revert IStaking.ErrorStakingTargetMaxStakedAmountExceeded(targetNftId, maxStakedAmount, dipAmount);
        }
    }

    function calculateRewardIncrease(
        StakingReader stakingReader,
        NftId stakeNftId,
        UFixed rewardRate
    )
        public
        view
        returns (
            Amount rewardIncreaseAmount,
            Amount totalDipAmount
        )
    {
        (
            Amount stakeAmount,
            Amount rewardAmount,
            Timestamp lastUpdatedAt
        ) = stakingReader.getStakeBalances(stakeNftId);

        Seconds duration = SecondsLib.toSeconds(
            block.timestamp - lastUpdatedAt.toInt());
        
        rewardIncreaseAmount = calculateRewardAmount(
            rewardRate,
            duration,
            stakeAmount);
        
        totalDipAmount = stakeAmount + rewardAmount + rewardIncreaseAmount;
    }

    function calculateRewardAmount(
        UFixed rewardRate,
        Seconds duration, 
        Amount stakeAmount
    )
        public 
        pure 
        returns(
            Amount rewardAmount
        )
    {
        UFixed rewardRateFraction = getYearFraction(duration) * rewardRate;
        rewardAmount = stakeAmount.multiplyWith(rewardRateFraction);
    }


    function getYearFraction(Seconds duration) public pure returns (UFixed yearFraction) {
        return UFixedLib.toUFixed(duration.toInt()) / UFixedLib.toUFixed(SecondsLib.oneYear().toInt());
    }

}