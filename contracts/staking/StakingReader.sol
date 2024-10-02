// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol"; 

import {IRegistry} from "../registry/IRegistry.sol";
import {RegistryLinked} from "../shared/RegistryLinked.sol";
import {IStaking} from "../staking/IStaking.sol";

import {Amount} from "../type/Amount.sol";
import {ChainId}  from "../type/ChainId.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType} from "../type/ObjectType.sol";
import {RegistryLinked} from "../shared/RegistryLinked.sol";
import {Seconds} from "../type/Seconds.sol";
import {StakingStore} from "./StakingStore.sol";
import {UFixed} from "../type/UFixed.sol";


contract StakingReader is
    Initializable,
    RegistryLinked
{

    error ErrorStakingReaderUnauthorizedCaler();

    address private _initializeOwner;
    IStaking private _staking;
    StakingStore private _store;

    constructor() {
        _initializeOwner = msg.sender;
    }

    function initialize(
        address stakingAddress,
        address stakingStoreAddress
    )
        external
        initializer()
    {
        if (msg.sender != _initializeOwner) {
            revert ErrorStakingReaderUnauthorizedCaler();
        }

        _staking = IStaking(stakingAddress);
        _store = StakingStore(stakingStoreAddress);
    }

    // view functions

    function getStaking() external view returns (IStaking staking) {
        return _staking;
    }

    function getProtocolNftId() external view returns (NftId protocolNftId) {
        return _getRegistry().getProtocolNftId();
    }


    function isTarget(NftId targetNftId) external view returns (bool) {
        return _store.getTargetSet().exists(targetNftId);
    }


    function targets() external view returns (uint256) {
        return _store.getTargetSet().nftIds();
    }


    function getTargetNftId(uint256 idx) external view returns (NftId) {
        return _store.getTargetSet().getNftId(idx);
    }


    function getTargetNftId(NftId stakeNftId) public view returns (NftId targetNftId) {
        return _getRegistry().getParentNftId(stakeNftId);
    }


    function getStakeInfo(NftId stakeNftId) external view returns (IStaking.StakeInfo memory stakeInfo) {
        return _store.getStakeInfo(stakeNftId);
    }


    function getTargetInfo(NftId targetNftId) public view returns (IStaking.TargetInfo memory info) {
        return _store.getTargetInfo(targetNftId);
    }


    function getLimitInfo(NftId targetNftId) public view returns (IStaking.LimitInfo memory info) {
        return _store.getLimitInfo(targetNftId);
    }


    function getTvlInfo(NftId targetNftId, address token) public view returns (IStaking.TvlInfo memory info) {
        return _store.getTvlInfo(targetNftId, token);
    }


    function getTokenInfo(ChainId chainId, address token) public view returns (IStaking.TokenInfo memory info) {
        return _store.getTokenInfo(chainId, token);
    }


    function isSupportedTargetType(ObjectType targetType) public view returns (bool) {
        return _store.getSupportInfo(targetType).isSupported;
    }


    function getSupportInfo(ObjectType targetType) public view returns (IStaking.SupportInfo memory info) {
        return _store.getSupportInfo(targetType);
    }


    /// @dev Get the locking period that applies to the specified stake NFT ID.
    function getTargetLockingPeriod(NftId stakeNftId) external view returns (NftId targetNftId, Seconds lockingPeriod) {
        targetNftId = getTargetNftId(stakeNftId);
        lockingPeriod = getTargetInfo(targetNftId).lockingPeriod;
    }


    /// @dev Get the reward rate that applies to the specified stake NFT ID.
    function getTargetRewardRate(NftId stakeNftId) external view returns (NftId targetNftId, UFixed rewardRate) {
        targetNftId = getTargetNftId(stakeNftId);
        rewardRate = getTargetInfo(targetNftId).rewardRate;
    }


    /// @dev Get the max staked amount allowed for the specified target NFT ID.
    function getTargetMaxStakedAmount(NftId targetNftId) external view returns (Amount maxStakedAmount) {
        return getTargetInfo(targetNftId).limitAmount;
    }


    /// @dev Get the reward rate for the specified target NFT ID.
    function getLockingPeriod(NftId targetNftId) external view returns (Seconds lockingPeriod) {
        return getTargetInfo(targetNftId).lockingPeriod;
    }


    /// @dev Get the reward rate for the specified target NFT ID.
    function getRewardRate(NftId targetNftId) external view returns (UFixed rewardRate) {
        return getTargetInfo(targetNftId).rewardRate;
    }

    /// @dev returns the current reward reserve balance for the specified target.
    function getReserveBalance(NftId targetNftId) external view returns (Amount rewardReserveBalance) {
        return getTargetInfo(targetNftId).reserveAmount;
    }

    function getTotalValueLocked(NftId targetNftId, address token) external view returns (Amount totalValueLocked) {
        return _store.getTvlInfo(targetNftId, token).tvlAmount;
    }

    function getRequiredStakeBalance(NftId targetNftId) external view returns (Amount requiredStakedAmount) {
        return _store.getRequiredStakeBalance(targetNftId, true);
    }

    function getRequiredStakeBalance(NftId targetNftId, bool includeTargetTypeRequirements) external view returns (Amount requiredStakedAmount) {
        return _store.getRequiredStakeBalance(targetNftId, includeTargetTypeRequirements);
    }
}
