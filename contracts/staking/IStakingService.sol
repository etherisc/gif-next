// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IService} from "../shared/IService.sol";
import {IStaking} from "./IStaking.sol";

import {Amount} from "../type/Amount.sol";
import {NftId} from "../type/NftId.sol";
import {Seconds} from "../type/Seconds.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";
import {UFixed} from "../type/UFixed.sol";


interface IStakingService is IService
{

    event LogStakingServiceProtocolTargetRegistered(NftId protocolNftId);
    event LogStakingServiceInstanceTargetRegistered(NftId instanceNftId, uint256 chainId);
    event LogStakingServiceLockingPeriodSet(NftId targetNftId, Seconds oldLockingDuration, Seconds lockingDuration);
    event LogStakingServiceRewardRateSet(NftId targetNftId, UFixed oldRewardRate, UFixed rewardRate);

    event LogStakingServiceRewardReservesIncreased(NftId targetNftId, address rewardProvider, Amount dipAmount, Amount newBalance);
    event LogStakingServiceRewardReservesDecreased(NftId targetNftId, address targetOwner, Amount dipAmount, Amount newBalance);

    event LogStakingServiceStakeObjectCreated(NftId stakeNftId, NftId targetNftId, address stakeOwner);
    event LogStakingServiceStakeCreated(NftId stakeNftId, NftId targetNftId, address owner, Amount stakedAmount);
    event LogStakingServiceStakeIncreased(NftId stakeNftId, address owner, Amount stakedAmount, Amount stakeBalance);
    event LogStakingServiceUnstaked(NftId stakeNftId, address stakeOwner, Amount totalAmount);
    event LogStakingServiceStakeRestaked(address stakeOwner, NftId indexed stakeNftId, NftId newStakeNftId, NftId indexed newTargetNftId, Amount indexed newStakeBalance);

    event LogStakingServiceRewardsUpdated(NftId stakeNftId);
    event LogStakingServiceRewardsClaimed(NftId stakeNftId, address stakeOwner, Amount rewardsClaimedAmount);

    // modifiers
    error ErrorStakingServiceNotStakingOwner(address account);
    error ErrorStakingServiceNotStaking(address stakingAddress);
    error ErrorStakingServiceNotSupportingIStaking(address stakingAddress);

    // create
    error ErrorStakingServiceTargetUnknown(NftId targetNftId);
    error ErrorStakingServiceZeroTargetNftId();
    error ErrorStakingServiceNotTargetNftId(NftId targetNftId);
    error ErrorStakingServiceNotActiveTargetNftId(NftId targetNftId);
    error ErrorStakingServiceDipBalanceInsufficient(NftId targetNftId, uint256 amount, uint256 balance);
    error ErrorStakingServiceDipAllowanceInsufficient(NftId targetNftId, address tokenHandler, uint256 amount, uint256 allowance);


    /// @dev Approves the staking token handler.
    /// Reverts if the staking token handler wallet is not the token handler itself.
    function approveTokenHandler(
        IERC20Metadata token,
        Amount amount
    ) external;

    /// @dev creates/registers an on-chain instance staking target.
    /// function granted to instance service
    function createInstanceTarget(
        NftId targetNftId,
        Seconds initialLockingPeriod,
        UFixed initialRewardRate
    ) external;

    /// @dev Set the instance stake locking period to the specified duration.
    /// Permissioned: Only owner of the specified target.
    function setInstanceLockingPeriod(NftId instanceNftId, Seconds lockingPeriod) external;

    /// @dev Set the instance reward rate to the specified value.
    /// Permissioned: Only owner of the specified target.
    function setInstanceRewardRate(NftId instanceNftId, UFixed rewardRate) external;

    /// @dev Set the instance max staked amount to the specified value.
    /// Permissioned: Only owner of the specified target.
    function setInstanceMaxStakedAmount(NftId instanceNftId, Amount maxStakingAmount) external;

    /// @dev (Re)fills the staking reward reserves for the specified target using the dips provided by the reward provider.
    /// unpermissioned: anybody may fill up staking reward reserves
    function refillInstanceRewardReserves(NftId instanceNftId, address rewardProvider, Amount dipAmount) external returns (Amount newBalance);

    /// @dev (Re)fills the staking reward reserves for the specified target using the dips provided by the sender
    /// unpermissioned: anybody may fill up staking reward reserves
    function refillRewardReservesBySender(NftId targetNftId, Amount dipAmount) external returns (Amount newBalance);

    /// @dev Defunds the staking reward reserves for the specified target
    /// Permissioned: only the target owner may call this function
    function withdrawInstanceRewardReserves(NftId instanceNftId, Amount dipAmount) external returns (Amount newBalance);


    /// @dev Creates a new stake object for the specified target via the registry service.
    /// Permissioned: only the staking component may call this function
    function createStakeObject(
        NftId targetNftId,
        address initialOwner
    )
        external
        returns (NftId stakeNftId);


    /// @dev collect DIP token from stake owner.
    /// Permissioned: only the staking component may call this function
    function pullDipToken(Amount dipAmount, address stakeOwner) external;


    /// @dev transfer DIP token to stake owner.
    /// Permissioned: only the staking component may call this function
    function pushDipToken(Amount dipAmount, address stakeOwner) external;

    // TODO cleanup
    // /// @dev increase an existing stake by amount DIP
    // /// updates and restakes the staking reward amount
    // /// function restricted to the current stake owner
    // function stake(
    //     NftId stakeNftId,
    //     Amount amount
    // ) external;

    // /// @dev re-stakes the current staked DIP as well as all accumulated rewards to the new stake target.
    // /// all related stakes and all accumulated reward DIP are transferred to the current stake holder
    // /// function restricted to the current stake owner
    // function restakeToNewTarget(
    //     NftId stakeNftId,
    //     NftId newTargetNftId
    // )
    //     external
    //     returns (
    //         NftId newStakeNftId,
    //         Amount newStakeBalance
    //     );


    // /// @dev claims all available rewards.
    // function claimRewards(
    //     NftId stakeNftId
    // ) external;


    // /// @dev updates the reward balance of the stake using the current reward rate.
    // function updateRewards(
    //     NftId stakeNftId
    // ) external;


    // /// @dev unstakes all dips (stakes and rewards) of an existing stake.
    // /// function restricted to the current stake owner
    // function unstake(
    //     NftId stakeNftId
    // ) external;


    /// @dev sets total value locked data for a target contract on a different chain.
    /// this is done via CCIP (cross chain communication) 
    function setTotalValueLocked(
        NftId targetNftId,
        address token,
        Amount amount
    ) external;

    function getDipToken()
        external
        view
        returns (IERC20Metadata dip);

    function getTokenHandler()
        external
        view
        returns (TokenHandler tokenHandler);

    function getStaking()
        external
        view
        returns (IStaking staking);
}