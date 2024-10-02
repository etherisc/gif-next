// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IRegistry} from "../registry/IRegistry.sol";
import {IStaking} from "./IStaking.sol";
import {IStakingService} from "./IStakingService.sol";

import {Amount} from "../type/Amount.sol";
import {ContractLib} from "../shared/ContractLib.sol";
import {NftId} from "../type/NftId.sol";
import {ReleaseRegistry} from "../registry/ReleaseRegistry.sol";
import {Seconds, SecondsLib} from "../type/Seconds.sol";
import {StakingReader} from "./StakingReader.sol";
import {STAKING} from "../type/ObjectType.sol";
import {Timestamp, TimestampLib} from "../type/Timestamp.sol";
import {UFixed, UFixedLib} from "../type/UFixed.sol";
import {VersionPart} from "../type/Version.sol";


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


    function checkAndGetStakingService(
        VersionPart release
    )
        public
        view
        returns (IStakingService stakingService)
    {
        IRegistry registry = ContractLib.getRegistry();

        if (!ReleaseRegistry(registry.getReleaseRegistryAddress()).isActiveRelease(release)) {
            revert IStaking.ErrorStakingReleaseNotActive(release);
        }

        address stakingServiceAddress = registry.getServiceAddress(STAKING(), release);
        if (stakingServiceAddress == address(0)) {
            revert IStaking.ErrorStakingServiceNotFound(release);
        }

        return IStakingService(stakingServiceAddress);
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

        Amount stakeLimitAmount = stakingReader.getTargetMaxStakedAmount(targetNftId);
        if (dipAmount > stakeLimitAmount) {
            revert IStaking.ErrorStakingTargetMaxStakedAmountExceeded(targetNftId, stakeLimitAmount, dipAmount);
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