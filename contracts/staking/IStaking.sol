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

    event LogStakingTargetAdded(NftId targetNftId, ObjectType objectType, uint256 chainId);

    error ErrorStakingTargetAlreadyRegistered(NftId targetNftId);
    error ErrorStakingTargetNftIdZero();
    error ErrorStakingTargetTypeNotSupported(NftId targetNftId, ObjectType objectType);
    error ErrorStakingTargetUnexpectedObjectType(NftId targetNftId, ObjectType expectedObjectType, ObjectType actualObjectType);
    error ErrorStakingTargetNotFound(NftId targetNftId);
    error ErrorStakingTargetTokenNotFound(NftId targetNftId, uint256 chainId, address token);

    // info for individual stake
    struct StakeInfo {
        NftId targetNftId;
        Amount stakeAmount;
        Amount rewardAmount;
        Timestamp lockedUntil;
        Timestamp rewardsUpdatedAt;
    }

    struct TargetInfo {
        ObjectType objectType;
        uint256 chainId;
        Timestamp createdAt;
    }

    // rate management 
    function setStakingRate(uint256 chainId, address token, UFixed stakingRate) external;

    // reward management 
    function setRewardRate(NftId targetNftId, UFixed rewardRate) external;
    function refillRewardReserves(NftId targetNftId, Amount dipAmount) external;
    function withdrawRewardReserves(NftId targetNftId, Amount dipAmount) external;

    // target management
    function registerInstanceTarget(NftId targetNftId) external;
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
    function isTargetTypeSupported(ObjectType objectType) external view returns (bool isSupported);

    function targets() external view returns (uint256);
    function getTargetNftId(uint256 idx) external view returns (NftId targetNftId);
    function isTarget(NftId targetNftId) external view returns (bool);

    function activeTargets() external view returns (uint256);
    function getActiveTargetNftId(uint256 idx) external view returns (NftId targetNftId);
    function isActive(NftId targetNftId) external view returns (bool);

    function getTargetInfo(NftId targetNftId) external view returns (TargetInfo memory targetInfo);
    function getTvlAmount(NftId targetNftId, address token) external view returns (Amount tvlAmount);
    function getStakedAmount(NftId targetNftId) external view returns (Amount stakeAmount);

    function getStakingRate(uint256 chainId, address token) external view returns (UFixed stakingRate);

    function getRewardRate(NftId targetNftId) external view returns (UFixed rewardRate);
    function getRewardReserves(NftId targetNftId) external view returns (Amount rewardReserveAmount);

    function getStakeInfo() external view returns (NftId stakeNftId);


    function calculateRewardIncrementAmount(
        NftId targetNftId,
        Timestamp rewardsLastUpdatedAt
    ) external view returns (Amount rewardIncrementAmount);

}
