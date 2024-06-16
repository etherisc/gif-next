// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Amount, AmountLib} from "../type/Amount.sol";
import {Component} from "../shared/Component.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {IRegistryService} from "../registry/IRegistryService.sol";
import {IStaking} from "./IStaking.sol";
import {Key32} from "../type/Key32.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType, INSTANCE, PROTOCOL, TARGET} from "../type/ObjectType.sol";
import {Seconds, SecondsLib} from "../type/Seconds.sol";
import {StakingReader} from "./StakingReader.sol";
import {StakingStore} from "./StakingStore.sol";
import {Timestamp, TimestampLib} from "../type/Timestamp.sol";
import {UFixed, UFixedLib} from "../type/UFixed.sol";


library StakeManagerLib {

    function stake(
        IRegistry registry,
        StakingReader stakingReader,
        StakingStore stakingStore,
        NftId stakeNftId,
        Amount stakeAmount
    )
        external
        returns (Amount stakeBalance)
    {
        // check that target is active for staking
        (
            UFixed rewardRate,
            Seconds lockingPeriod
        ) = checkStakeParameters(
            stakingReader, 
            stakeNftId);        

        // calculate new rewards (if any)
        (
            Amount rewardIncrementAmount, 
            Amount currentTotalDipAmount
        ) = calculateRewardIncrease(
            stakingReader, 
            stakeNftId,
            rewardRate);

        stakeBalance = currentTotalDipAmount + stakeAmount;

        // TODO check that additional dip, rewards and rewards increment 
        // are still ok with max target staking amount
        NftId targetNftId = registry.getObjectInfo(stakeNftId).parentNftId;

        stakingStore.restakeRewards(
            stakeNftId, 
            targetNftId, 
            rewardIncrementAmount);

        stakingStore.increaseStake(
            stakeNftId, 
            targetNftId, 
            stakeAmount);

        // update locked until with target locking period
        stakingStore.update(
            stakeNftId, 
            IStaking.StakeInfo({
                lockedUntil: TimestampLib.blockTimestamp().addSeconds(
                    lockingPeriod)}));

    }

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
        Seconds lockingPeriod = checkTarget(stakingReader, targetNftId);
        checkDipAmount(stakingReader, targetNftId, dipAmount);

        Timestamp currentTime = TimestampLib.blockTimestamp();
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

        // only accept stakes for active targets
        if (!stakingReader.isActive(targetNftId)) {
            revert IStaking.ErrorStakingTargetNotActive(targetNftId);
        }

        IStaking.TargetInfo memory info = stakingReader.getTargetInfo(targetNftId);
        rewardRate = info.rewardRate;
        lockingPeriod = info.lockingPeriod;
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

        // only accept stakes for active targets
        if (!stakingReader.isActive(targetNftId)) {
            revert IStaking.ErrorStakingTargetNotActive(targetNftId);
        }

        lockingPeriod = stakingReader.getTargetInfo(targetNftId).lockingPeriod;
    }


    function checkDipAmount(
        StakingReader stakingReader,
        NftId targetNftId, 
        Amount dipAmount
    )
        public 
        pure 
    {
        // check stake amount > 0
        if (dipAmount.eqz()) {
            revert IStaking.ErrorStakingStakeAmountZero(targetNftId);
        }

        // TODO add check for target specific max dip amount (min stake + tvl * stake rate + buffer)
    }


    function checkDipBalanceAndAllowance(
        IERC20Metadata dip, 
        address owner, 
        address tokenHandlerAddress, 
        Amount dipAmount
    )
        public
        view
    {
        // check balance
        uint256 amount = dipAmount.toInt();
        uint256 dipBalance = dip.balanceOf(owner);
        if (dipBalance < amount) {
            revert IStaking.ErrorStakingDipBalanceInsufficient(owner, amount, dipBalance);
        }

        // check allowance
        uint256 dipAllowance = dip.allowance(owner, tokenHandlerAddress);
        if (dipAllowance < amount) {
            revert IStaking.ErrorStakingDipAllowanceInsufficient(owner, tokenHandlerAddress, amount, dipAllowance);
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