// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Amount} from "../type/Amount.sol";
import {IService} from "../shared/IService.sol";
import {IStaking} from "./IStaking.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType} from "../type/ObjectType.sol";
import {Seconds} from "../type/Seconds.sol";
import {Timestamp} from "../type/Timestamp.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";
import {UFixed} from "../type/UFixed.sol";


interface IStakingService is IService
{

    event LogStakingServiceProtocolTargetRegistered(NftId protocolNftId);
    event LogStakingServiceInstanceTargetRegistered(NftId instanceNftId, uint256 chainId);
    event LogStakingServiceLockingPeriodSet(NftId targetNftId, Seconds oldLockingDuration, Seconds lockingDuration);
    event LogStakingServiceRewardRateSet(NftId targetNftId, UFixed oldRewardRate, UFixed rewardRate);

    event LogStakingServiceStakeCreated(NftId stakeNftId, NftId targetNftId, address owner, Amount stakedAmount);
    event LogStakingServiceStakeIncreased(NftId stakeNftId, address owner, Amount stakedAmount);
    event LogStakingServiceRewardsUpdated(NftId stakeNftId);

    // modifiers
    error ErrorStakingServiceNotNftOwner(NftId nftId, address expectedOwner, address owner);
    error ErrorStakingServiceNotStaking(address stakingAddress);
    error ErrorStakingServiceNotSupportingIStaking(address stakingAddress);

    // create
    error ErrorStakingServiceZeroTargetNftId();
    error ErrorStakingServiceNotTargetNftId(NftId targetNftId);
    error ErrorStakingServiceNotActiveTargetNftId(NftId targetNftId);
    error ErrorStakingServiceDipBalanceInsufficient(NftId targetNftId, uint256 amount, uint256 balance);
    error ErrorStakingServiceDipAllowanceInsufficient(NftId targetNftId, address tokenHandler, uint256 amount, uint256 allowance);

    /// @dev creates/registers an on-chain instance staking target.
    /// function granted to instance service
    function createInstanceTarget(
        NftId targetNftId,
        Seconds initialLockingPeriod,
        UFixed initialRewardRate
    ) external;

    /// @dev set the stake locking period to the specified duration.
    /// permissioned: only the owner of the specified target may set the locking period
    function setLockingPeriod(NftId targetNftId, Seconds lockingPeriod) external;

    /// @dev set the reward rate to the specified value
    /// permissioned: only the owner of the specified target may set the locking period
    function setRewardRate(NftId targetNftId, UFixed rewardRate) external;

    /// @dev create a new stake with amount DIP to the specified target
    /// returns the id of the newly minted stake nft
    /// permissionless function
    function create(
        NftId targetNftId,
        Amount amount
    )
        external
        returns (
            NftId stakeNftId
        );


    /// @dev increase an existing stake by amount DIP
    /// updates the staking reward amount
    /// function restricted to the current stake owner
    function stake(
        NftId stakeNftId,
        Amount amount
    )
        external;


    /// @dev re-stakes the current staked DIP as well as all accumulated rewards to the new stake target.
    /// all related stakes and all accumulated reward DIP are transferred to the current stake holder
    /// function restricted to the current stake owner
    function restake(
        NftId stakeNftId
    )
        external;


    /// @dev re-stakes the current staked DIP as well as all accumulated rewards to the new stake target.
    /// all related stakes and all accumulated reward DIP are transferred to the current stake holder
    /// function restricted to the current stake owner
    function restakeToNewTarget(
        NftId stakeNftId,
        NftId newTargetNftId
    )
        external
        returns (
            NftId newStakeNftId
        );


    /// @dev decrease an existing stake by amount DIP
    /// updates the staking reward amount
    /// function restricted to the current stake owner
    function unstake(
        NftId stakeNftId,
        Amount amount
    )
        external;

    /// @dev updates the reward balance of the stake using the current reward rate.
    function updateRewards(
        NftId stakeNftId
    )
        external;


    /// @dev increases the total value locked amount for the specified target by the provided token amount.
    /// function is called when a new policy is collateralized
    /// function restricted to the pool service
    function increaseTotalValueLocked(
        NftId targetNftId,
        address token,
        Amount amount
    )
        external
        returns (Amount totalValueLocked);


    /// @dev decreases the total value locked amount for the specified target by the provided token amount.
    /// function is called when a new policy is closed or payouts are executed
    /// function restricted to the pool service
    function decreaseTotalValueLocked(
        NftId targetNftId,
        address token,
        Amount amount
    )
        external
        returns (Amount totalValueLocked);


    /// @dev sets total value locked data for a target contract on a different chain.
    /// this is done via CCIP (cross chain communication) 
    function setTotalValueLocked(
        NftId targetNftId,
        address token,
        Amount amount
    )
        external;

    function getDipToken()
        external
        returns (IERC20Metadata dip);

    function getTokenHandler()
        external
        returns (TokenHandler tokenHandler);

    function getStaking()
        external
        returns (IStaking staking);
}