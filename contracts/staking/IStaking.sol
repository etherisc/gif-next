// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Amount} from "../type/Amount.sol";
import {IComponent} from "../shared/IComponent.sol";
import {IVersionable} from "../upgradeability/IVersionable.sol";
import {NftId} from "../type/NftId.sol";
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
    // staking rate
    event LogStakingStakingRateSet(uint256 chainId, address token, UFixed oldStakingRate, UFixed newStakingRate);

    // target parameters
    event LogStakingLockingPeriodSet(NftId targetNftId, Seconds oldLockingPeriod, Seconds lockingPeriod);
    event LogStakingRewardRateSet(NftId targetNftId, UFixed oldRewardRate, UFixed rewardRate);
    event LogStakingMaxStakedAmountSet(NftId targetNftId, Amount maxStakedAmount);

    // modifiers
    error ErrorStakingNotStake(NftId stakeNftId);
    error ErrorStakingNotTarget(NftId targetNftId);

    error ErrorStakingNotStakingOwner();
    error ErrorStakingNotNftOwner(NftId nftId);

    // initializeTokenHandler
    error ErrorStakingNotRegistry(address registry);

    // staking rate
    error ErrorStakingTokenNotRegistered(uint256 chainId, address token);

    // check dip balance and allowance
    error ErrorStakingDipBalanceInsufficient(address owner, uint256 amount, uint256 dipBalance);
    error ErrorStakingDipAllowanceInsufficient(address owner, address tokenHandler, uint256 amount, uint256 dipAllowance);

    error ErrorStakingStakingReaderStakingMismatch(address stakingByStakingReader);
    error ErrorStakingTargetAlreadyRegistered(NftId targetNftId);
    error ErrorStakingTargetNftIdZero();
    error ErrorStakingTargetTypeNotSupported(NftId targetNftId, ObjectType objectType);
    error ErrorStakingTargetUnexpectedObjectType(NftId targetNftId, ObjectType expectedObjectType, ObjectType actualObjectType);
    error ErrorStakingLockingPeriodTooShort(NftId targetNftId, Seconds minLockingPeriod, Seconds lockingPeriod);
    error ErrorStakingLockingPeriodTooLong(NftId targetNftId, Seconds maxLockingPeriod, Seconds lockingPeriod);
    error ErrorStakingStakeLocked(NftId stakeNftId, Timestamp lockedUntil);
    error ErrorStakingRewardRateTooHigh(NftId targetNftId, UFixed maxRewardRate, UFixed rewardRate);
    error ErrorStakingTargetNotFound(NftId targetNftId);
    error ErrorStakingTargetTokenNotFound(NftId targetNftId, uint256 chainId, address token);
    error ErrorStakingTargetMaxStakedAmountExceeded(NftId targetNftId, Amount maxStakedAmount, Amount stakedAmount);

    error ErrorStakingStakeAmountZero(NftId targetNftId);

    // info for individual stake
    struct StakeInfo {
        // slot 0
        Timestamp lockedUntil;
    }

    struct TargetInfo {
        // Slot 0
        UFixed rewardRate;
        Amount maxStakedAmount;
        // Slot 1
        ObjectType objectType;
        Seconds lockingPeriod;
        // Slot 2
        uint256 chainId;
    }

    function initializeTokenHandler() external;

    function approveTokenHandler(IERC20Metadata token, Amount amount) external;

    // staking rate management 

    /// @dev sets the rate that converts 1 token of total value locked into the
    /// the required staked dip amount to back up the locked token value
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
    /// permissioned: only the staking service may call this function
    function setLockingPeriod(NftId targetNftId, Seconds lockingPeriod) external;

    /// @dev update the target specific reward rate.
    /// permissioned: only the staking service may call this function
    function setRewardRate(NftId targetNftId, UFixed rewardRate) external;

    /// @dev set the maximum staked amount for the specified target.
    /// permissioned: only the staking service may call this function
    function setMaxStakedAmount(NftId targetNftId, Amount maxStakedAmount) external;

    /// @dev (re)fills the staking reward reserves for the specified target
    /// unpermissioned: anybody may fill up staking reward reserves
    function refillRewardReserves(NftId targetNftId, Amount dipAmount) external returns (Amount newBalance);

    /// @dev defunds the staking reward reserves for the specified target
    /// permissioned: only the staking service may call this function
    function withdrawRewardReserves(NftId targetNftId, Amount dipAmount) external returns (Amount newBalance);


    /// @dev increases the total value locked amount for the specified target by the provided token amount.
    /// function is called when a new policy is collateralized.
    /// function restricted to the pool service.
    function increaseTotalValueLocked(NftId targetNftId, address token, Amount amount) external returns (Amount newBalance);


    /// @dev decreases the total value locked amount for the specified target by the provided token amount.
    /// function is called when a new policy is closed or payouts are executed.
    /// function restricted to the pool service.
    function decreaseTotalValueLocked(NftId targetNftId, address token, Amount amount) external returns (Amount newBalance);


    function updateRemoteTvl(NftId targetNftId, address token, Amount amount) external;

    // staking functions

    /// @dev creat a new stake info object
    /// permissioned: only staking service may call this function.
    function createStake(NftId stakeNftId, NftId targetNftId, Amount dipAmount) external;

    /// @dev increase the staked dip by dipAmount for the specified stake.
    /// staking rewards are updated and added to the staked dips as well.
    /// the function returns the new total amount of staked dips.
    function stake(NftId stakeNftId, Amount dipAmount) external returns (Amount stakeBalance);

    /// @dev restakes the dips to a new target.
    /// the sum of the staked dips and the accumulated rewards will be restaked.
    /// permissioned: only staking service may call this function.
    function restake(NftId stakeNftId, NftId newStakeNftId) external returns (Amount newStakeBalance);

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

    //--- view and pure functions -------------------------------------------//

    function getStakingStore() external view returns (StakingStore stakingStore);
    function getStakingReader() external view returns (StakingReader reader);
}
