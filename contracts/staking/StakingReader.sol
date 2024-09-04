// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol"; 

import {IRegistry} from "../registry/IRegistry.sol";
import {IRegistryLinked} from "../shared/IRegistryLinked.sol";
import {IStaking} from "../staking/IStaking.sol";

import {Amount} from "../type/Amount.sol";
import {Blocknumber}  from "../type/Blocknumber.sol";
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

    function getStakingRate(uint256 chainId, address token) external view returns (UFixed stakingRate) { 
        return _store.getStakingRate(chainId, token); 
    }


    function isTarget(NftId targetNftId) external view returns (bool) {
        return _store.getTargetNftIdSet().exists(targetNftId);
    }


    function targets() external view returns (uint256) {
        return _store.getTargetNftIdSet().nftIds();
    }


    function getTargetNftId(uint256 idx) external view returns (NftId) {
        return _store.getTargetNftIdSet().getNftId(idx);
    }


    function getTargetNftId(NftId stakeNftId) public view returns (NftId targetNftId) {
        return _registry.getParentNftId(stakeNftId);
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
        return getTargetInfo(targetNftId).maxStakedAmount;
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
        return _store.getReserveBalance(targetNftId); 
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

    function getBalanceUpdatedIn(NftId nftId) external view returns (Blocknumber blocknumber) {
        return _store.getBalanceUpdatedIn(nftId); 
    }

    function getTotalValueLocked(NftId nftId, address token) external view returns (Amount totalValueLocked) {
        return _store.getTotalValueLocked(nftId, token); 
    }

    function getRequiredStakeBalance(NftId nftId) external view returns (Amount requiredStakedAmount) {
        return _store.getRequiredStakeBalance(nftId); 
    }

    function getTargetBalances(NftId stakeNftId) 
        public
        view
        returns (
            Amount balanceAmount,
            Amount stakeAmount,
            Amount rewardAmount,
            Blocknumber lastUpdatedIn
        )
    {
        (
            balanceAmount,
            stakeAmount,
            rewardAmount,
            lastUpdatedIn
        ) = _store.getTargetBalances(stakeNftId);
    }

    function getStakeBalances(NftId stakeNftId) 
        external
        view
        returns (
            Amount stakeAmount,
            Amount rewardAmount,
            Timestamp lastUpdatedAt
        )
    {
        (
            stakeAmount,
            rewardAmount,
            lastUpdatedAt
        ) = _store.getStakeBalances(stakeNftId);
    }
}
