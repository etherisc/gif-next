// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount} from "../type/Amount.sol";
import {IKeyValueStore} from "../shared/IKeyValueStore.sol";
import {IComponent} from "../shared/IComponent.sol";
import {IVersionable} from "../shared/IVersionable.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType} from "../type/ObjectType.sol";
import {Timestamp} from "../type/Timestamp.sol";
import {UFixed} from "../type/UFixed.sol";

interface IStaking is 
    IKeyValueStore, 
    IComponent,
    IVersionable
{

    // info for individual stake
    struct StakeInfo {
        NftId targetNftId;
        Amount stakeAmount;
        Amount rewardAmount;
        Timestamp lockedUntil;
        Timestamp rewardsUpdatedAt;
    }

    struct TargetInfo {
        NftId targetNftid;
        ObjectType objectType;
        uint256 chainId;
        address token;
    }

    // rate management 
    function setStakingRate(uint256 chainId, address token, UFixed stakingRate) external;

    // reward management 
    function setRewardRate(NftId targetNftId, UFixed rewardRate) external;
    function refillRewardReserves(NftId targetNftId, Amount dipAmount) external;
    function withdrawRewardReserves(NftId targetNftId, Amount dipAmount) external;

    // target management
    function registerTarget(NftId targetNftId) external;
    function increaseTvl(NftId targetNftId, address token, Amount amount) external;
    function decreaseTvl(NftId targetNftId, address token, Amount amount) external;

    function registerRemoteTarget(NftId targetNftId, TargetInfo memory targetInfo) external;
    function updateRemoteTvl(NftId targetNftId, address token, Amount amount) external;

    // staking functions
    function createStake(NftId targetNftId, Amount dipAmount) external returns(NftId stakeNftId);
    function stake(NftId stakeNftId, Amount dipAmount) external;
    function restakeRewards(NftId stakeNftId) external;
    function restakeToNewTarget(NftId stakeNftId, NftId newTarget) external;
    function unstake(NftId stakeNftId) external;
    function unstake(NftId stakeNftId, Amount dipAmount) external;  
    function claimRewards(NftId stakeNftId) external;

    // view and pure functions (staking reader?)
    function getStakingRate(uint256 chainId, address token) external view returns (UFixed stakingRate);

    function getRewardRate(NftId targetNftId) external view returns (UFixed rewardRate);
    function getRewardReserves(NftId targetNftId) external view returns (Amount rewardReserveAmount);

    function getStakeInfo() external view returns (NftId stakeNftId);
    function getTargetInfo() external view returns (NftId stakeNftId);

    function getTvlAmount(NftId targetNftId, address token) external view returns (Amount tvlAmount);
    function getStakedAmount(NftId targetNftId) external view returns (Amount stakeAmount);

    function calculateRewardIncrementAmount(
        NftId targetNftId,
        Timestamp rewardsLastUpdatedAt
    ) external view returns (Amount rewardIncrementAmount);

}
