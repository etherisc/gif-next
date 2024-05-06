// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount} from "../type/Amount.sol";
import {IKeyValueStore} from "../shared/IKeyValueStore.sol";
import {IComponent} from "../shared/IComponent.sol";
import {IVersionable} from "../shared/IVersionable.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType, STAKE, TARGET} from "../type/ObjectType.sol";
import {Seconds} from "../type/Seconds.sol";
import {IStaking} from "../staking/IStaking.sol";
import {Timestamp} from "../type/Timestamp.sol";
import {UFixed} from "../type/UFixed.sol";

contract StakingReader {

    error ErrorStakingReaderStakingAlreadySet(address staking);

    IStaking private _staking;

    function setStaking(address stakingAddress) external {
        if (address(_staking) != address(0)) {
            revert ErrorStakingReaderStakingAlreadySet(address(_staking));
        }

        _staking = IStaking(stakingAddress);
    }

    // view and pure functions (staking reader?)

    function getStaking() external view returns (IStaking staking) {
        return _staking;
    }


    function isTarget(NftId targetNftId) external view returns (bool) {
        return _staking.getTargetManager().exists(targetNftId);
    }


    function targets() external view returns (uint256) {
        return _staking.getTargetManager().nftIds();
    }


    function getTargetNftId(uint256 idx) external view returns (NftId) {
        return _staking.getTargetManager().getNftId(idx);
    }


    function isActive(NftId targetNftId) external view returns (bool) {
        return _staking.getTargetManager().isActive(targetNftId);
    }


    function activeTargets() external view returns (uint256) {
        return _staking.getTargetManager().activeNftIds();
    }


    function getActiveTargetNftId(uint256 idx) external view returns (NftId) {
        return _staking.getTargetManager().getActiveNftId(idx);
    }


    function getTargetInfo(NftId targetNftId) public view returns (IStaking.TargetInfo memory info) {
        bytes memory data = _staking.getData(targetNftId.toKey32(TARGET()));
        if (data.length > 0) {
            return abi.decode(data, (IStaking.TargetInfo));
        }
    }


    function getStakeInfo(NftId stakeNftId) external view returns (IStaking.StakeInfo memory stakeInfo) {
        bytes memory data = _staking.getData(stakeNftId.toKey32(STAKE()));
        if (data.length > 0) {
            return abi.decode(data, (IStaking.StakeInfo));
        }
    }


    // function getTvlAmount(NftId targetNftId, address token) external view returns (Amount tvlAmount);
    // function getStakedAmount(NftId targetNftId) external view returns (Amount stakeAmount);

    // function getStakingRate(uint256 chainId, address token) external view returns (UFixed stakingRate);

    // function calculateRewardIncrementAmount(
    //     NftId targetNftId,
    //     Timestamp rewardsLastUpdatedAt
    // ) external view returns (Amount rewardIncrementAmount);

}
