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

    // target parameters
    event LogStakingLockingPeriodSet(NftId targetNftId, Seconds oldLockingPeriod, Seconds lockingPeriod);
    event LogStakingRewardRateSet(NftId targetNftId, UFixed oldRewardRate, UFixed rewardRate);

    // modifiers
    error ErrorStakingNotStake(NftId stakeNftId);
    error ErrorStakingNotTarget(NftId targetNftId);

    error ErrorStakingNotStakingOwner();
    error ErrorStakingNotNftOwner(NftId nftId);

    // check dip balance and allowance
    error ErrorStakingDipBalanceInsufficient(address owner, uint256 amount, uint256 dipBalance);
    error ErrorStakingDipAllowanceInsufficient(address owner, address tokenHandler, uint256 amount, uint256 dipAllowance);

    error ErrorStakingStakingReaderStakingMismatch(address stakingByStakingReader);
    error ErrorStakingTargetAlreadyRegistered(NftId targetNftId);
    error ErrorStakingTargetNftIdZero();
    error ErrorStakingTargetTypeNotSupported(NftId targetNftId, ObjectType objectType);
    error ErrorStakingTargetUnexpectedObjectType(NftId targetNftId, ObjectType expectedObjectType, ObjectType actualObjectType);
    error ErrorStakingLockingPeriodZero(NftId targetNftId);
    error ErrorStakingLockingPeriodTooLong(NftId targetNftId, Seconds maxLockingPeriod, Seconds lockingPeriod);
    error ErrorStakingRewardRateTooHigh(NftId targetNftId, UFixed maxRewardRate, UFixed rewardRate);
    error ErrorStakingTargetNotFound(NftId targetNftId);
    error ErrorStakingTargetTokenNotFound(NftId targetNftId, uint256 chainId, address token);

    error ErrorStakingTargetNotActive(NftId targetNftId);
    error ErrorStakingStakeAmountZero(NftId targetNftId);

    // info for individual stake
    struct StakeInfo {
        Timestamp lockedUntil;
    }

    struct TargetInfo {
        ObjectType objectType;
        uint256 chainId;
        Seconds lockingPeriod;
        UFixed rewardRate;
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
    function setLockingPeriod(NftId targetNftId, Seconds lockingPeriod) external;

    function setRewardRate(NftId targetNftId, UFixed rewardRate) external;
    function refillRewardReserves(NftId targetNftId, Amount dipAmount) external;
    function withdrawRewardReserves(NftId targetNftId, Amount dipAmount) external;

    function increaseTvl(NftId targetNftId, address token, Amount amount) external;
    function decreaseTvl(NftId targetNftId, address token, Amount amount) external;

    function updateRemoteTvl(NftId targetNftId, address token, Amount amount) external;

    // staking functions

    /// @dev register a new stake info object
    /// permissioned: only staking service may call this function.
    function registerStake(NftId stakeNftId, NftId targetNftId, Amount dipAmount) external;

    /// @dev increase the staked dip by dipAmount for the specified stake
    function stake(NftId stakeNftId, Amount dipAmount) external;

    /// @dev restakes the dips to a new target.
    /// the sum of the staked dips and the accumulated rewards will be restaked.
    /// permissioned: only staking service may call this function.
    function restake(NftId stakeNftId) external;

    /// @dev retuns the specified amount of dips to the holder of the specified stake nft.
    /// if dipAmount is set to Amount.max() all staked dips and all rewards are transferred to 
    /// permissioned: only staking service may call this function.
    function unstake(NftId stakeNftId)
        external
        returns (
            Amount unstakedAmount,
            Amount rewardsClaimedAmount
        );

    /// @dev update stake rewards for current time.
    /// may be called before an announement of a decrease of a reward rate reduction.
    /// calling this functions ensures that reward balance is updated using the current (higher) reward rate.
    /// unpermissioned.
    function updateRewards(NftId stakeNftId) external;

    /// @dev transfers all rewards accumulated so far to the holder of the specified stake nft.
    /// permissioned: only staking service may call this function.
    function claimRewards(NftId stakeNftId)
        external
        returns (
            Amount rewardsClaimedAmount
        );

    //--- helper functions --------------------------------------------------//

    /// @dev transfers the specified amount of dips from the from address to the staking wallet.
    function collectDipAmount(address from, Amount dipAmount) external;

    /// @dev transfers the specified amount of dips from the staking wallet to the to addess.
    function transferDipAmount(address to, Amount dipAmount) external;

    //--- view and pure functions -------------------------------------------//

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
