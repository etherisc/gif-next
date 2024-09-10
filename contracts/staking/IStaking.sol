// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IComponent} from "../shared/IComponent.sol";
import {IVersionable} from "../upgradeability/IVersionable.sol";

import {Amount} from "../type/Amount.sol";
import {Blocknumber} from "../type/Blocknumber.sol";
import {ChainId} from "../type/ChainId.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType} from "../type/ObjectType.sol";
import {Seconds} from "../type/Seconds.sol";
import {StakingReader} from "./StakingReader.sol";
import {StakingStore} from "./StakingStore.sol";
import {Timestamp} from "../type/Timestamp.sol";
import {UFixed} from "../type/UFixed.sol";
import {VersionPart} from "../type/Version.sol";


interface IStaking is 
    IComponent,
    IVersionable
{

    // owner functions
    event LogStakingProtocolLockingPeriodSet(NftId targetNftId, Seconds newLockingPeriod, Seconds oldLockingPeriod, Blocknumber lastUpdatedIn);
    event LogStakingProtocolRewardRateSet(NftId targetNftId, UFixed newRewardRate, UFixed oldRewardRate, Blocknumber lastUpdatedIn);
    event LogStakingStakingRateSet(ChainId chainId, address token, UFixed newStakingRate, UFixed oldStakingRate, Blocknumber lastUpdatedIn);
    event LogStakingStakingServiceSet(address stakingService, VersionPart release, address oldStakingService);
    event LogStakingStakingReaderSet(address stakingReader, address oldStakingReader);
    event LogStakingTokenHandlerApproved(address token, Amount approvalAmount, Amount oldApprovalAmount);

    // token
    event LogStakingTokenAdded(ChainId chainId, address token);
    event LogStakingTargetTokenAdded(NftId targetNftId, ChainId chainId, address token);

    // total value locked
    event LogStakingTotalValueLockedIncreased(NftId targetNftId, address token, Amount amount, Amount newBalance);
    event LogStakingTotalValueLockedDecreased(NftId targetNftId, address token, Amount amount, Amount newBalance);

    // targets
    event LogStakingTargetCreated(NftId targetNftId, ObjectType objectType, Seconds lockingPeriod, UFixed rewardRate, Amount maxStakedAmount);

    // target parameters
    event LogStakingTargetLockingPeriodSet(NftId targetNftId, Seconds oldLockingPeriod, Seconds lockingPeriod);
    event LogStakingTargetRewardRateSet(NftId targetNftId, UFixed rewardRate, UFixed oldRewardRate);
    event LogStakingTargetMaxStakedAmountSet(NftId targetNftId, Amount maxStakedAmount);

    // stakes
    event LogStakingStakeCreated(NftId stakeNftId, NftId targetNftId, Amount stakeAmount, Timestamp lockedUntil, address stakeOwner);
    event LogStakingStakeRewardsUpdated(NftId stakeNftId, Amount rewardIncrementAmount, Amount stakeBalance, Amount rewardBalance, Timestamp lockedUntil);
    event LogStakingRewardsRestaked(NftId stakeNftId, Amount restakedAmount, Amount stakeBalance, Amount rewardBalance, Timestamp lockedUntil);
    event LogStakingStaked(NftId stakeNftId, Amount stakedAmount, Amount stakeBalance, Amount rewardBalance, Timestamp lockedUntil);
    event LogStakingUnstaked(NftId stakeNftId, Amount unstakedAmount, Amount stakeBalance, Amount rewardBalance, Timestamp lockedUntil);
    event LogStakingRewardsClaimed(NftId stakeNftId, Amount claimedAmount, Amount stakeBalance, Amount rewardBalance, Timestamp lockedUntil);

    event LogStakingStakeRestaked(NftId stakeNftId, NftId targetNftId, Amount stakeAmount, address owner, NftId oldStakeNftId);

    // modifiers
    error ErrorStakingNotStake(NftId stakeNftId);
    error ErrorStakingNotTarget(NftId targetNftId);
    error ErrorStakingNotStakeOwner(NftId stakeNftId, address expectedOwner, address actualOwner);

    error ErrorStakingNotStakingOwner();
    error ErrorStakingNotNftOwner(NftId nftId);

    // owner functions
    error ErrorStakingReleaseNotActive(VersionPart release);
    error ErrorStakingServiceNotFound(VersionPart release);

    // initializeTokenHandler
    error ErrorStakingNotRegistry(address registry);

    // staking rate
    error ErrorStakingTokenNotRegistered(ChainId chainId, address token);

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
    error ErrorStakingTargetTokenNotFound(NftId targetNftId, ChainId chainId, address token);
    error ErrorStakingTargetMaxStakedAmountExceeded(NftId targetNftId, Amount maxStakedAmount, Amount stakedAmount);

    error ErrorStakingStakeAmountZero(NftId targetNftId);

    // info for individual stake
    struct StakeInfo {
        // slot 0
        Amount stakedAmount; // 96
        Amount rewardAmount; // 96
        Timestamp lockedUntil; // 40
        // slot 1
        NftId targetNftId; // 96, redundant to parent nft in registry object info
        Timestamp lastUpdateAt; // 40, needed to update rewards
        Blocknumber lastUpdateIn; // 40, needed for traceability
    }

    struct TargetInfo {
        // Slot 0
        Amount stakedAmount; // 96
        Amount rewardAmount; // 96
        Blocknumber lastUpdateIn; // 40, needed for traceability
        // Slot 1
        Amount reserveAmount; // 96
        Amount maxStakedAmount; // 96
        Seconds lockingPeriod; // 40
        ObjectType objectType; // 8
        // Slot 2
        UFixed rewardRate; // 160
        ChainId chainId; // 96 redundant to target nft id
    }

    struct TvlInfo {
        // Slot 0
        Amount tvlAmount; // 96
        Blocknumber lastUpdateIn; // 40, needed for traceability
    }

    struct TokenInfo {
        // Slot 0
        UFixed stakingRate; // 160
        Blocknumber lastUpdateIn; // 40, needed for traceability
    }

    function initializeTokenHandler() external;

    //--- only owner functions -------------------------------------------//

    /// @dev Set the stake locking period for protocol stakes to the specified duration.
    function setProtocolLockingPeriod(Seconds lockingPeriod) external;

    /// @dev Set the protocol reward rate.
    function setProtocolRewardRate(UFixed rewardRate) external;

    /// @dev Set the staking rate for the specified chain and token.
    /// The staking rate defines the amount of staked dips required to back up 1 token of total value locked.
    function setStakingRate(ChainId chainId, address token, UFixed stakingRate) external;

    /// @dev Sets/updates the staking service contract to the staking service of the specified release.
    function setStakingService(VersionPart release) external;

    /// @dev Sets/updates the staking reader contract. 
    function setStakingReader(StakingReader stakingReader) external;

    /// @dev Registers a token for recording staking rate and total value locked.
    /// Process flow: Add token by token registry which will trigger this staking contract.
    function addToken(ChainId chainId, address token) external;

    /// @dev Set the approval to the token handler.
    /// Defines the max allowance from the staking wallet to the token handler.
    function approveTokenHandler(IERC20Metadata token, Amount amount) external;

    //--- target management ----------------------------------------------//

    /// @dev Register a new target for staking.
    /// Permissioned: only the staking service may call this function 
    function registerTarget(
        NftId targetNftId,
        ObjectType expectedObjectType,
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

    /// @dev Register a token for the specified target.
    /// Used for instance targets. Each product may introduce its own token.
    /// Permissioned: only the staking service may call this function
    function addTargetToken(NftId targetNftId, address token) external;

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

    /// @dev Creates a new stake to the specified target over the given DIP amount.
    /// The stake owner is provided as an argument and becomes the stake NFT holder.
    /// This function is permissionless and may be called by any user.
    function createStake(NftId targetNftId, Amount dipAmount, address stakeOwner) external returns (NftId stakeNftId);

    /// @dev Increase the staked DIP by dipAmount for the specified stake.
    /// Staking rewards are updated and added to the staked DIP amount as well.
    /// The function returns the new total amount of staked dips.
    function stake(NftId stakeNftId, Amount dipAmount) external returns (Amount newStakeBalance);

    /// @dev Pays the specified DIP amount to the holder of the stake NFT ID.
    /// If dipAmount is set to Amount.max() all stakes and rewards are transferred to the stake holder.
    /// permissioned: only staking service may call this function.
    function unstake(NftId stakeNftId) external returns (Amount unstakedAmount, Amount rewardsClaimedAmount);

    /// @dev restakes the dips to a new target.
    /// the sum of the staked dips and the accumulated rewards will be restaked.
    /// permissioned: only staking service may call this function.
    function restake(NftId stakeNftId, NftId newTargetNftId) external returns (NftId newStakeNftId, Amount newStakeBalance);

    /// @dev update stake rewards for current time.
    /// may be called before an announement of a decrease of a reward rate reduction.
    /// calling this functions ensures that reward balance is updated using the current (higher) reward rate.
    /// unpermissioned.
    function updateRewards(NftId stakeNftId) external returns (Amount newRewardAmount);

    /// @dev transfers all rewards accumulated so far to the holder of the specified stake nft.
    /// permissioned: only staking service may call this function.
    function claimRewards(NftId stakeNftId) external returns (Amount rewardsClaimedAmount);

    //--- view and pure functions -------------------------------------------//

    function getStakingStore() external view returns (StakingStore stakingStore);
    function getStakingReader() external view returns (StakingReader reader);
}
