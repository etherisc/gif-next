// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol"; 

import {IRegistry} from "../registry/IRegistry.sol";
import {IRegistryLinked} from "../shared/IRegistryLinked.sol";
import {IStaking} from "../staking/IStaking.sol";

import {Amount, AmountLib} from "../type/Amount.sol";
import {Blocknumber}  from "../type/Blocknumber.sol";
import {ChainId}  from "../type/ChainId.sol";
import {NftId} from "../type/NftId.sol";
import {Seconds} from "../type/Seconds.sol";
import {StakingStore} from "./StakingStore.sol";
import {STAKE, TARGET} from "../type/ObjectType.sol";
import {Timestamp} from "../type/Timestamp.sol";
import {UFixed} from "../type/UFixed.sol";


contract StakingReader is
    IRegistryLinked,
    Initializable
{

    error ErrorStakingReaderUnauthorizedCaler();

    address private _initializeOwner;
    IRegistry private _registry;
    IStaking private _staking;
    StakingStore private _store;

    constructor(IRegistry registry) {
        _initializeOwner = msg.sender;
        _registry = registry;
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

    // view and pure functions 

    function getRegistry() external view returns (IRegistry registry) {
        return _registry;
    }

    function getStaking() external view returns (IStaking staking) {
        return _staking;
    }

    function getProtocolNftId() external view returns (NftId protocolNftId) {
        return _registry.getProtocolNftId();
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
        return _registry.getParentNftId(stakeNftId);
    }


    function getStakeInfo(NftId stakeNftId) external view returns (IStaking.StakeInfo memory stakeInfo) {
        return _store.getStakeInfo(stakeNftId);
    }


    function getTargetInfo(NftId targetNftId) public view returns (IStaking.TargetInfo memory info) {
        return _store.getTargetInfo(targetNftId);
    }


    function getTvlInfo(NftId targetNftId, address token) public view returns (IStaking.TvlInfo memory info) {
        return _store.getTvlInfo(targetNftId, token);
    }


    function getTokenInfo(ChainId chainId, address token) public view returns (IStaking.TokenInfo memory info) {
        return _store.getTokenInfo(chainId, token);
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
        return _store.getRequiredStakeBalance(targetNftId);
    }
}
