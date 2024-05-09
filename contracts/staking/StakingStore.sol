// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";

import {Amount, AmountLib} from "../type/Amount.sol";
import {Blocknumber, BlocknumberLib} from "../type/Blocknumber.sol";
import {ChainNft} from "../registry/ChainNft.sol";
import {Component} from "../shared/Component.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {IRegistryService} from "../registry/IRegistryService.sol";
import {IStaking} from "./IStaking.sol";
import {IVersionable} from "../shared/IVersionable.sol";
import {Key32} from "../type/Key32.sol";
import {KeyValueStore} from "../shared/KeyValueStore.sol";
import {KEEP_STATE} from "../type/StateId.sol";
import {LibNftIdSet} from "../type/NftIdSet.sol";
import {NftId, NftIdLib} from "../type/NftId.sol";
import {NftIdSetManager} from "../shared/NftIdSetManager.sol";
import {ObjectType, INSTANCE, PROTOCOL, STAKE, STAKING, TARGET} from "../type/ObjectType.sol";
import {Seconds, SecondsLib} from "../type/Seconds.sol";
import {StakingReader} from "./StakingReader.sol";
import {TargetManagerLib} from "./TargetManagerLib.sol";
import {Timestamp, TimestampLib} from "../type/Timestamp.sol";
import {TokenRegistry} from "../registry/TokenRegistry.sol";
import {UFixed, UFixedLib} from "../type/UFixed.sol";
import {Version, VersionLib} from "../type/Version.sol";
import {Versionable} from "../shared/Versionable.sol";


contract StakingStore is 
    AccessManaged,
    KeyValueStore
{

    event LogStakingStoreStakesIncreased(NftId nftId, Amount addedAmount, Amount newBalance, Blocknumber lastUpdatedIn);
    event LogStakingStoreStakesDecreased(NftId nftId, Amount addedAmount, Amount newBalance, Blocknumber lastUpdatedIn);

    event LogStakingStoreRewardsIncreased(NftId nftId, Amount addedAmount, Amount newBalance, Blocknumber lastUpdatedIn);
    event LogStakingStoreRewardsDecreased(NftId nftId, Amount addedAmount, Amount newBalance, Blocknumber lastUpdatedIn);

    event LogStakingStoreRewardsRestaked(NftId nftId, Amount amount, Amount rewardAmount, Amount rewardIncrementAmount, Amount newBalance, Blocknumber lastUpdatedIn);

    // creating and updating of balance
    error ErrorStakingStoreBalanceAlreadyInitialized(NftId nftId);
    error ErrorStakingStoreBalanceNotInitialized(NftId nftId);

    // update balance

    IRegistry private _registry;
    NftIdSetManager private _targetManager;
    StakingReader private _reader;

    mapping(NftId nftId => Amount stakes) private _stakeBalance;
    mapping(NftId nftId => Amount rewards) private _rewardBalance;

    // TODO check if this is made redundant by *Info struct updates
    mapping(NftId nftId => Timestamp lastUpdatedAt) private _lastUpdatedAt;
    mapping(NftId nftId => Blocknumber lastUpdatedIn) private _lastUpdatedIn;


    constructor(
        address initialAuthority,
        address registryAddress,
        address stakingReaderAddress
    )
        AccessManaged(initialAuthority)
    {
        _registry = IRegistry(registryAddress);
        _reader = StakingReader(stakingReaderAddress);
        _targetManager = new NftIdSetManager();
        _targetManager.setOwner(address(this));
    }

    //--- target specific functions ------------------------------------//

    function createTarget(
        NftId targetNftId,
        IStaking.TargetInfo memory targetInfo
    )
        external
    {
        _create(
            targetNftId.toKey32(TARGET()),
            abi.encode(targetInfo));

        _createBalance(targetNftId, AmountLib.zero());
        _targetManager.add(targetNftId);
    }


    function updateTarget(
        NftId targetNftId, 
        IStaking.TargetInfo memory targetInfo
    )
        external
    {
        _update(
            targetNftId.toKey32(TARGET()), 
            abi.encode(targetInfo), KEEP_STATE());
    }

    //--- stake specific functions -------------------------------------//

    function create(
        NftId stakeNftId, 
        IStaking.StakeInfo memory stakeInfo,
        Amount stakeAmount
    )
        external
    {
        _create(
            stakeNftId.toKey32(STAKE()),
            abi.encode(stakeInfo));

        _createBalance(stakeNftId, stakeAmount);
    }

    function update(
        NftId stakeNftId, 
        IStaking.StakeInfo memory stakeInfo
    )
        external
    {
        _update(
            stakeNftId.toKey32(STAKE()),
            abi.encode(stakeInfo),
            KEEP_STATE());
    }

    //--- general functions --------------------------------------------//


    function increaseBalance(NftId nftId, Amount amount, Amount rewardIncrementAmount)
        external
    {
        Blocknumber lastUpdatedIn = _lastUpdatedIn[nftId];
        bool updated = false;

        if (lastUpdatedIn.eqz()) {
            revert ErrorStakingStoreBalanceNotInitialized(nftId);
        }

        // update stake balance with amount
        if(amount.gtz()) {
            updated = true;
            _stakeBalance[nftId] = _stakeBalance[nftId] + amount;
            emit LogStakingStoreStakesIncreased(nftId, amount, _stakeBalance[nftId], lastUpdatedIn);
        }

        // update reward balance with amount
        if(rewardIncrementAmount.gtz()) {
            updated = true;
            _rewardBalance[nftId] = _rewardBalance[nftId] + rewardIncrementAmount;
            emit LogStakingStoreRewardsIncreased(nftId, rewardIncrementAmount, _rewardBalance[nftId], lastUpdatedIn);
        }

        if (updated) {
            _lastUpdatedAt[nftId] = TimestampLib.blockTimestamp();
            _lastUpdatedIn[nftId] = BlocknumberLib.currentBlocknumber();
        }
    }


    function restakeRewards(
        NftId nftId, 
        Amount rewardIncrementAmount
    )
        external
    {
        Blocknumber lastUpdatedIn = _lastUpdatedIn[nftId];
        Amount stakeAmount = _stakeBalance[nftId];
        Amount rewardAmount = _rewardBalance[nftId];

        if (lastUpdatedIn.eqz()) {
            revert ErrorStakingStoreBalanceNotInitialized(nftId);
        }

        // move all rewards to stake balance
        _stakeBalance[nftId] = stakeAmount + rewardAmount + rewardIncrementAmount;
        _rewardBalance[nftId] = AmountLib.zero();

        _lastUpdatedAt[nftId] = TimestampLib.blockTimestamp();
        _lastUpdatedIn[nftId] = BlocknumberLib.currentBlocknumber();

        emit LogStakingStoreRewardsRestaked(nftId, stakeAmount, rewardAmount, rewardIncrementAmount, _stakeBalance[nftId], lastUpdatedIn);
    }


    function updateRewards(
        NftId nftId, 
        Amount rewardIncrementAmount
    )
        external
    {
        Blocknumber lastUpdatedIn = _lastUpdatedIn[nftId];
        Amount rewardAmount = _rewardBalance[nftId];

        if (lastUpdatedIn.eqz()) {
            revert ErrorStakingStoreBalanceNotInitialized(nftId);
        }

        // move all rewards to stake balance
        _rewardBalance[nftId] = rewardAmount + rewardIncrementAmount;

        _lastUpdatedAt[nftId] = TimestampLib.blockTimestamp();
        _lastUpdatedIn[nftId] = BlocknumberLib.currentBlocknumber();

        emit LogStakingStoreRewardsIncreased(nftId, rewardIncrementAmount, _rewardBalance[nftId], lastUpdatedIn);
    }


    function claimUpTo(
        NftId nftId, 
        Amount maxRewardAmount
    )
        external
        returns (Amount rewardsClaimedAmount)
    {
        Blocknumber lastUpdatedIn = _lastUpdatedIn[nftId];
        bool updated = false;

        if (lastUpdatedIn.eqz()) {
            revert ErrorStakingStoreBalanceNotInitialized(nftId);
        }

        // determine the claimable rewards amount
        if (maxRewardAmount > _rewardBalance[nftId]) {
            rewardsClaimedAmount = _rewardBalance[nftId];
        } else {
            rewardsClaimedAmount = maxRewardAmount;
        }

        // decrease reward amount
        _rewardBalance[nftId] = _rewardBalance[nftId] - rewardsClaimedAmount;

        _lastUpdatedAt[nftId] = TimestampLib.blockTimestamp();
        _lastUpdatedIn[nftId] = BlocknumberLib.currentBlocknumber();

        emit LogStakingStoreRewardsDecreased(nftId, rewardsClaimedAmount, _rewardBalance[nftId], lastUpdatedIn);
    }


    function unstakeUpTo(
        NftId nftId, 
        Amount maxUnstakeAmount,
        Amount maxClaimAmount
    )
        external
        returns (
            Amount unstakedAmount,
            Amount claimedAmount
        )
    {
        Blocknumber lastUpdatedIn = _lastUpdatedIn[nftId];
        bool updated = false;

        if (lastUpdatedIn.eqz()) {
            revert ErrorStakingStoreBalanceNotInitialized(nftId);
        }

        // determine the unstakeable amount
        if (maxUnstakeAmount > _rewardBalance[nftId]) {
            unstakedAmount = _rewardBalance[nftId];
        } else {
            unstakedAmount = maxUnstakeAmount;
        }

        // determine the claimable rewards amount
        if (maxClaimAmount > _rewardBalance[nftId]) {
            claimedAmount = _rewardBalance[nftId];
        } else {
            claimedAmount = maxClaimAmount;
        }

        // decrease amounts
        _stakeBalance[nftId] = _stakeBalance[nftId] - unstakedAmount;
        _rewardBalance[nftId] = _rewardBalance[nftId] - claimedAmount;

        _lastUpdatedAt[nftId] = TimestampLib.blockTimestamp();
        _lastUpdatedIn[nftId] = BlocknumberLib.currentBlocknumber();

        emit LogStakingStoreStakesDecreased(nftId, unstakedAmount, _stakeBalance[nftId], lastUpdatedIn);
        emit LogStakingStoreRewardsDecreased(nftId, claimedAmount, _rewardBalance[nftId], lastUpdatedIn);
    }

    //--- view functions -----------------------------------------------//

    function getTargetManager() external view returns (NftIdSetManager targetManager){
        return _targetManager;
    }

    function exists(NftId stakeNftId) external view returns (bool) {
        return exists(stakeNftId.toKey32(STAKE()));
    }

    function getStakeBalance(NftId nftId) external view returns (Amount balanceAmount) { return _stakeBalance[nftId]; }
    function getRewardBalance(NftId nftId) external view returns (Amount rewardAmount) { return _rewardBalance[nftId]; }
    function getBalanceUpdatedAt(NftId nftId) external view returns (Timestamp updatedAt) { return _lastUpdatedAt[nftId]; }

    function getBalanceAndLastUpdatedAt(NftId nftId)
        external
        view
        returns (
            Amount stakeBalance,
            Timestamp lastUpdatedAt
        )
    {
        stakeBalance = _stakeBalance[nftId];
        lastUpdatedAt = _lastUpdatedAt[nftId];
    }

    //--- private functions -------------------------------------------//

    function _createBalance(NftId nftId, Amount amount) private {
        if (_lastUpdatedIn[nftId].gtz()) {
            revert ErrorStakingStoreBalanceAlreadyInitialized(nftId);
        }

        _stakeBalance[nftId] = amount;
        _rewardBalance[nftId] = AmountLib.zero();

        _lastUpdatedAt[nftId] = TimestampLib.blockTimestamp();
        _lastUpdatedIn[nftId] = BlocknumberLib.currentBlocknumber();
    }
}
