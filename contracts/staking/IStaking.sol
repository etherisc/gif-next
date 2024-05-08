// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount} from "../type/Amount.sol";
import {IComponent} from "../shared/IComponent.sol";
import {IVersionable} from "../shared/IVersionable.sol";
import {NftId} from "../type/NftId.sol";
import {NftIdSetManager} from "../shared/NftIdSetManager.sol";
import {ObjectType} from "../type/ObjectType.sol";
import {Seconds} from "../type/Seconds.sol";
import {StakingReader} from "./StakingReader.sol";
import {StakingStore} from "./StakingStore.sol";
import {Timestamp} from "../type/Timestamp.sol";
import {UFixed} from "../type/UFixed.sol";

interface IStaking is 
    IComponent,
    IVersionable
{

    event LogStakingTargetAdded(NftId targetNftId, ObjectType objectType, uint256 chainId);
    event LogStakingLockingPeriodSet(NftId targetNftId, Seconds oldLockingDuration, Seconds lockingDuration);
    event LogStakingRewardRateSet(NftId targetNftId, UFixed oldRewardRate, UFixed rewardRate);

    error ErrorStakingStakingReaderStakingMismatch(address stakingByStakingReader);
    error ErrorStakingNotNftOwner(NftId nftId);
    error ErrorStakingTargetAlreadyRegistered(NftId targetNftId);
    error ErrorStakingTargetNftIdZero();
    error ErrorStakingTargetTypeNotSupported(NftId targetNftId, ObjectType objectType);
    error ErrorStakingTargetUnexpectedObjectType(NftId targetNftId, ObjectType expectedObjectType, ObjectType actualObjectType);
    error ErrorStakingLockingPeriodZero(NftId targetNftId);
    error ErrorStakingLockingPeriodTooLong(NftId targetNftId, Seconds maxLockingPeriod, Seconds lockingPeriod);
    error ErrorStakingRewardRateTooHigh(NftId targetNftId, UFixed maxRewardRate, UFixed rewardRate);
    error ErrorStakingTargetNotFound(NftId targetNftId);
    error ErrorStakingTargetTokenNotFound(NftId targetNftId, uint256 chainId, address token);

    // info for individual stake
    struct StakeInfo {
        Amount stakeAmount;
        Amount rewardAmount;
        Timestamp lockedUntil;
        Timestamp rewardsUpdatedAt;
    }

    struct TargetInfo {
        ObjectType objectType;
        uint256 chainId;
        Seconds lockingPeriod;
        UFixed rewardRate;
        Amount rewardReserveAmount;
    }

    // rate management 
    function setStakingRate(uint256 chainId, address token, UFixed stakingRate) external;


    // target management

    function registerTarget(
        NftId targetNftId,
        ObjectType expectedObjectType,
        uint256 chainId,
        Seconds initialLockingPeriod,
        UFixed initialRewardRate
    ) external;


    /// @dev set the stake locking period to the specified duration.
    /// permissioned: only the owner of the specified target may set the locking period
    function setLockingPeriod(NftId targetNftId, Seconds lockingPeriod) external;

    function setRewardRate(NftId targetNftId, UFixed rewardRate) external;
    function refillRewardReserves(NftId targetNftId, Amount dipAmount) external;
    function withdrawRewardReserves(NftId targetNftId, Amount dipAmount) external;

    function increaseTvl(NftId targetNftId, address token, Amount amount) external;
    function decreaseTvl(NftId targetNftId, address token, Amount amount) external;

    function updateRemoteTvl(NftId targetNftId, address token, Amount amount) external;

    // staking functions

    /// @dev creates/stores a new stake info object
    /// permissioned: only staking service may call this function.
    function create(NftId stakeNftId, NftId targetNftId, Amount dipAmount) external;

    function stake(NftId stakeNftId, Amount dipAmount) external;
    function restakeRewards(NftId stakeNftId) external;
    function restakeToNewTarget(NftId stakeNftId, NftId newTarget) external;
    function unstake(NftId stakeNftId) external;
    function unstake(NftId stakeNftId, Amount dipAmount) external;  
    function claimRewards(NftId stakeNftId) external;

    // view and pure functions (staking reader?)

    function getStakingStore() external view returns (StakingStore stakingStore);
    function getStakingReader() external view returns (StakingReader reader);

    // function getStakeInfo(NftId stakeNftId) external view returns (StakeInfo memory stakeInfo);
    // function getTargetInfo(NftId targetNftId) external view returns (TargetInfo memory targetInfo);

    function getTvlAmount(NftId targetNftId, address token) external view returns (Amount tvlAmount);
    function getStakedAmount(NftId targetNftId) external view returns (Amount stakeAmount);

    function getStakingRate(uint256 chainId, address token) external view returns (UFixed stakingRate);

    function calculateRewardIncrementAmount(
        NftId targetNftId,
        Timestamp rewardsLastUpdatedAt
    ) external view returns (Amount rewardIncrementAmount);

}
