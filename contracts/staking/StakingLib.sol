// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IRegistry} from "../registry/IRegistry.sol";
import {IStaking} from "./IStaking.sol";

import {Amount, AmountLib} from "../type/Amount.sol";
import {NftId} from "../type/NftId.sol";
import {Seconds, SecondsLib} from "../type/Seconds.sol";
import {StakingReader} from "./StakingReader.sol";
import {Timestamp, TimestampLib} from "../type/Timestamp.sol";
import {UFixed, UFixedLib} from "../type/UFixed.sol";


library StakingLib {

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
            Amount rewardIncreaseAmount
        )
    {
        IStaking.StakeInfo memory stakeInfo = stakingReader.getStakeInfo(stakeNftId);

        Seconds duration = SecondsLib.toSeconds(
            block.timestamp - stakeInfo.lastUpdateAt.toInt());
        
        rewardIncreaseAmount = calculateRewardAmount(
            rewardRate,
            duration,
            stakeInfo.stakedAmount);
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