// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount} from "../type/Amount.sol";
import {IKeyValueStore} from "../shared/IKeyValueStore.sol";
import {IComponent} from "../shared/IComponent.sol";
import {InitializableCustom} from "../shared/InitializableCustom.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {IRegistryLinked} from "../shared/IRegistryLinked.sol";
import {IStaking} from "../staking/IStaking.sol";
import {IVersionable} from "../shared/IVersionable.sol";
import {NftId} from "../type/NftId.sol";
import {NftIdSetManager} from "../shared/NftIdSetManager.sol";
import {ObjectType, STAKE, TARGET} from "../type/ObjectType.sol";
import {Seconds} from "../type/Seconds.sol";
import {StakingStore} from "./StakingStore.sol";
import {Timestamp} from "../type/Timestamp.sol";
import {UFixed} from "../type/UFixed.sol";

contract StakingReader is
    IRegistryLinked,
    InitializableCustom
{

    error ErrorStakingReaderDependenciesAlreadySet();

    IRegistry private _registry;
    IStaking private _staking;
    StakingStore private _store;

    constructor(IRegistry registry) InitializableCustom() {
        _registry = registry;
    }

    function initialize(
        address stakingAddress,
        address stakingStoreAddress
    )
        external
        initializer
    {
        _staking = IStaking(stakingAddress);
        _store = StakingStore(stakingStoreAddress);
    }

    // view and pure functions 

    function getRegistry() external view returns (IRegistry registry) {
        return _registry;
    }

    function getStaking() external view returns (IStaking staking) {
        return _staking;
    }


    function isTarget(NftId targetNftId) external view returns (bool) {
        return _store.getTargetManager().exists(targetNftId);
    }


    function targets() external view returns (uint256) {
        return _store.getTargetManager().nftIds();
    }


    function getTargetNftId(uint256 idx) external view returns (NftId) {
        return _store.getTargetManager().getNftId(idx);
    }


    function isActive(NftId targetNftId) external view returns (bool) {
        return _store.getTargetManager().isActive(targetNftId);
    }


    function activeTargets() external view returns (uint256) {
        return _store.getTargetManager().activeNftIds();
    }


    function getActiveTargetNftId(uint256 idx) external view returns (NftId) {
        return _store.getTargetManager().getActiveNftId(idx);
    }


    function getTargetInfo(NftId targetNftId) public view returns (IStaking.TargetInfo memory info) {
        bytes memory data = _store.getData(targetNftId.toKey32(TARGET()));
        if (data.length > 0) {
            return abi.decode(data, (IStaking.TargetInfo));
        }
    }


    function getStakeInfo(NftId stakeNftId) external view returns (IStaking.StakeInfo memory stakeInfo) {
        bytes memory data = _store.getData(stakeNftId.toKey32(STAKE()));
        if (data.length > 0) {
            return abi.decode(data, (IStaking.StakeInfo));
        }
    }


    function getStakeBalance(NftId nftId) external view returns (Amount balanceAmount) { 
        return _store.getStakeBalance(nftId); 
    }


    function getRewardBalance(NftId nftId) external view returns (Amount rewardAmount) {
        return _store.getRewardBalance(nftId); 
    }


    function getBalanceUpdatedAt(NftId nftId) external view returns (Timestamp updatedAt) {
        return _store.getBalanceUpdatedAt(nftId); 
    }


    function getRewardCalculationInput(NftId stakeNftId) 
        external
        view
        returns (
            UFixed rewardRate,
            Amount stakeAmount,
            Timestamp lastUpdatedAt
        )
    {
        NftId targetNftId = _registry.getObjectInfo(stakeNftId).parentNftId;
        rewardRate = getTargetInfo(targetNftId).rewardRate;

        (
            stakeAmount,
            lastUpdatedAt
        ) = _store.getBalanceAndLastUpdatedAt(stakeNftId);
    }

    // function getTvlAmount(NftId targetNftId, address token) external view returns (Amount tvlAmount);
    // function getStakedAmount(NftId targetNftId) external view returns (Amount stakeAmount);

    // function getStakingRate(uint256 chainId, address token) external view returns (UFixed stakingRate);

    // function calculateRewardIncrementAmount(
    //     NftId targetNftId,
    //     Timestamp rewardsLastUpdatedAt
    // ) external view returns (Amount rewardIncrementAmount);

}
