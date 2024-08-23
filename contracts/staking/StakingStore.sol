// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";

import {IRegistry} from "../registry/IRegistry.sol";
import {IStaking} from "./IStaking.sol";

import {Amount, AmountLib} from "../type/Amount.sol";
import {Blocknumber, BlocknumberLib} from "../type/Blocknumber.sol";
import {KeyValueStore} from "../shared/KeyValueStore.sol";
import {KEEP_STATE} from "../type/StateId.sol";
import {NftId, NftIdLib} from "../type/NftId.sol";
import {NftIdSet} from "../shared/NftIdSet.sol";
import {PROTOCOL, STAKE, TARGET} from "../type/ObjectType.sol";
import {StakingReader} from "./StakingReader.sol";
import {TargetManagerLib} from "./TargetManagerLib.sol";
import {Timestamp, TimestampLib} from "../type/Timestamp.sol";
import {StakingLifecycle} from "./StakingLifecycle.sol";
import {UFixed} from "../type/UFixed.sol";


contract StakingStore is 
    AccessManaged,
    KeyValueStore,
    StakingLifecycle
{

    event LogStakingStoreReserveBalanceIncreased(NftId targetNftId, Amount dipAmount, Amount reserveBalance, Blocknumber lastUpdatedIn);
    event LogStakingStoreReserveBalanceDecreased(NftId targetNftId, Amount dipAmount, Amount reserveBalance, Blocknumber lastUpdatedIn);

    event LogStakingStoreTotalValueLockedIncreased(NftId targetNftId, address token, Amount amount, Amount newBalance, Blocknumber lastUpdatedIn);
    event LogStakingStoreTotalValueLockedDecreased(NftId targetNftId, address token, Amount amount, Amount newBalance, Blocknumber lastUpdatedIn);

    event LogStakingStoreStakesIncreased(NftId nftId, Amount addedAmount, Amount newBalance, Blocknumber lastUpdatedIn);
    event LogStakingStoreStakesDecreased(NftId nftId, Amount addedAmount, Amount newBalance, Blocknumber lastUpdatedIn);

    event LogStakingStoreRewardsIncreased(NftId nftId, Amount addedAmount, Amount newBalance, Blocknumber lastUpdatedIn);
    event LogStakingStoreRewardsDecreased(NftId nftId, Amount addedAmount, Amount newBalance, Blocknumber lastUpdatedIn);

    event LogStakingStoreRewardsRestaked(NftId nftId, Amount amount, Amount rewardAmount, Amount rewardIncrementAmount, Amount newBalance, Blocknumber lastUpdatedIn);

    // in/decreasing reward reserves
    error ErrorStakingStoreNotTarget(NftId targetNftId);
    error ErrorStakingStoreRewardReservesInsufficient(NftId targetNftId, Amount dipAmount, Amount reservesBalanceAmount);    

    // creating and updating of balance
    error ErrorStakingStoreBalanceAlreadyInitialized(NftId nftId);
    error ErrorStakingStoreBalanceNotInitialized(NftId nftId);

    // update balance
    error ErrorStakingStoreTvlBalanceNotInitialized(NftId nftId);

    IRegistry private _registry;
    NftIdSet private _targetNftIdSet;
    StakingReader private _reader;

    // staking rate
    mapping(uint256 chainId => mapping(address token => UFixed stakingRate)) private _stakingRate;

    // total, stake and reward balances
    mapping(NftId nftId => Amount stakes) private _stakeBalance;
    mapping(NftId nftId => Amount rewards) private _rewardBalance;
    mapping(NftId nftId => Amount reserves) private _reserveBalance;

    mapping(NftId nftId => Timestamp lastUpdatedAt) private _lastUpdatedAt;
    mapping(NftId nftId => Blocknumber lastUpdatedIn) private _lastUpdatedIn;

    // total value locked balance
    mapping(NftId nftId => mapping(address token => Amount tvl)) private _tvlBalance;
    mapping(NftId nftId => mapping(address token => Amount tvlInDip)) private _tvlInDip;
    mapping(NftId nftId => Amount tvlRequiredDip) private _tvlRequiredDip;
    mapping(NftId nftId => Blocknumber lastUpdatedIn) private _tvlLastUpdatedIn;


    constructor(IRegistry registry, StakingReader reader)
        AccessManaged(msg.sender)
    {
        // set final authority
        setAuthority(registry.getAuthority());

        // set internal variables
        _registry = registry; //TODO if keeps registry -> RegistryLinked and checks registry address
        _reader = reader;
        _targetNftIdSet = new NftIdSet();

        // register protocol target
        _createTarget(
            NftIdLib.toNftId(1101), 
            IStaking.TargetInfo({
                objectType: PROTOCOL(),
                chainId: 1,
                lockingPeriod: TargetManagerLib.getDefaultLockingPeriod(),
                rewardRate: TargetManagerLib.getDefaultRewardRate(),
                maxStakedAmount: AmountLib.max()}));
    }


    //--- staking rate specific functions -----------------------------------//

    function setStakingRate(
        uint256 chainId, 
        address token, 
        UFixed stakingRate
    )
        external
        restricted()
    {
        _stakingRate[chainId][token] = stakingRate;
    }

    //--- target specific functions -----------------------------------------//

    function createTarget(
        NftId targetNftId,
        IStaking.TargetInfo memory targetInfo
    )
        external
        restricted()
    {
        _createTarget(targetNftId, targetInfo);
    }


    function updateTarget(
        NftId targetNftId, 
        IStaking.TargetInfo memory targetInfo
    )
        external
        restricted()
    {
        _update(
            targetNftId.toKey32(TARGET()), 
            abi.encode(targetInfo), KEEP_STATE());
    }


    function increaseReserves(
        NftId targetNftId, 
        Amount dipAmount
    )
        external
        restricted()
        returns (Amount newReserveBalance)
    {
        newReserveBalance = _reserveBalance[targetNftId] + dipAmount;
        Blocknumber lastUpdatedIn = _updateReserves(targetNftId, newReserveBalance);

        emit LogStakingStoreReserveBalanceIncreased(targetNftId, dipAmount, newReserveBalance, lastUpdatedIn);
    }


    function decreaseReserves(
        NftId targetNftId, 
        Amount dipAmount
    )
        external
        restricted()
        returns (Amount newReserveBalance)
    {
        Amount reserveAmount = _reserveBalance[targetNftId];
        if (dipAmount > reserveAmount) {
            revert ErrorStakingStoreRewardReservesInsufficient(
                targetNftId,
                dipAmount,
                reserveAmount);
        }

        newReserveBalance = _reserveBalance[targetNftId] - dipAmount;
        Blocknumber lastUpdatedIn = _updateReserves(targetNftId, newReserveBalance);

        emit LogStakingStoreReserveBalanceDecreased(targetNftId, dipAmount, newReserveBalance, lastUpdatedIn);
    }


    //--- tvl specific functions -------------------------------------//

    function increaseTotalValueLocked(
        NftId targetNftId,
        UFixed stakingRate,
        address token,
        Amount amount
    )
        external
        restricted()
        returns (Amount newBalance)
    {
        (
            Blocknumber tvlLastUpdatedIn,
            Amount oldBalance,
            Amount oldDipBalance
        ) = _getAndVerifyTvl(targetNftId, token);

        newBalance = oldBalance + amount;
        Amount newDipBalance = newBalance.multiplyWith(stakingRate);

        // update new tvl balances
        _tvlBalance[targetNftId][token] = newBalance;
        _tvlInDip[targetNftId][token] = newDipBalance;

        // update new amount of required dip
        _tvlRequiredDip[targetNftId] = _tvlRequiredDip[targetNftId] - oldDipBalance + newDipBalance;

        // update last updated in
        _tvlLastUpdatedIn[targetNftId] = BlocknumberLib.currentBlocknumber();

        emit LogStakingStoreTotalValueLockedIncreased(targetNftId, token, amount, newBalance, tvlLastUpdatedIn);
    }


    function decreaseTotalValueLocked(
        NftId targetNftId,
        UFixed stakingRate,
        address token,
        Amount amount
    )
        external
        restricted()
        returns (Amount newBalance)
    {
        (
            Blocknumber tvlLastUpdatedIn,
            Amount oldBalance,
            Amount oldDipBalance
        ) = _getAndVerifyTvl(targetNftId, token);

        newBalance = oldBalance - amount;
        Amount newDipBalance = AmountLib.toAmount((
            stakingRate * newBalance.toUFixed()).toInt());

        // update new tvl balances
        _tvlBalance[targetNftId][token] = newBalance;
        _tvlInDip[targetNftId][token] = newDipBalance;

        // update new amount of required dip
        _tvlRequiredDip[targetNftId] = _tvlRequiredDip[targetNftId] - oldDipBalance + newDipBalance;

        // update last updated in
        _tvlLastUpdatedIn[targetNftId] = BlocknumberLib.currentBlocknumber();

        emit LogStakingStoreTotalValueLockedDecreased(targetNftId, token, amount, newBalance, tvlLastUpdatedIn);
    }

    //--- stake specific functions -------------------------------------//

    function create(
        NftId stakeNftId, 
        IStaking.StakeInfo memory stakeInfo
    )
        external
        restricted()
    {
        _create(
            stakeNftId.toKey32(STAKE()),
            abi.encode(stakeInfo));

        _createStakeBalance(stakeNftId);
    }

    function update(
        NftId stakeNftId, 
        IStaking.StakeInfo memory stakeInfo
    )
        external
        restricted()
    {
        _update(
            stakeNftId.toKey32(STAKE()),
            abi.encode(stakeInfo),
            KEEP_STATE());
    }

    //--- general functions --------------------------------------------//


    function increaseStake(
        NftId nftId, 
        NftId targetNftId,
        Amount amount
    )
        external
        restricted()
    {
        Blocknumber lastUpdatedIn = _checkBalanceExists(nftId);

        _updateStakeBalance(
            nftId, 
            _stakeBalance[nftId] + amount, // new stake balance
            _rewardBalance[nftId]); // unchanged reward balance

        _updateTargetBalance(
            targetNftId,
            _stakeBalance[targetNftId] + amount,
            _rewardBalance[targetNftId]);

        emit LogStakingStoreStakesIncreased(nftId, amount, _stakeBalance[nftId], lastUpdatedIn);
    }


    function restakeRewards(
        NftId nftId, 
        NftId targetNftId,
        Amount rewardIncrementAmount
    )
        external
        restricted()
    {
        Blocknumber lastUpdatedIn = _checkBalanceExists(nftId);
        Amount stakeAmount = _stakeBalance[nftId];
        Amount rewardAmount = _rewardBalance[nftId];

        // move all rewards to stake balance
        _updateStakeBalance(
            nftId, 
            stakeAmount + rewardAmount + rewardIncrementAmount, // new stake balance
            AmountLib.zero()); // new reward balance

        _updateTargetBalance(
            targetNftId,
            _stakeBalance[targetNftId] + rewardAmount + rewardIncrementAmount,
            _rewardBalance[targetNftId] - rewardAmount);

        emit LogStakingStoreRewardsRestaked(nftId, stakeAmount, rewardAmount, rewardIncrementAmount, _stakeBalance[nftId], lastUpdatedIn);
    }


    function updateRewards(
        NftId nftId, 
        NftId targetNftId, 
        Amount rewardIncrementAmount
    )
        external
        restricted()
    {
        Blocknumber lastUpdatedIn = _checkBalanceExists(nftId);

        // increse rewards by increment
        _updateStakeBalance(
            nftId, 
            _stakeBalance[nftId], // unchanged stake balance
            _rewardBalance[nftId] + rewardIncrementAmount); // new reward balance

        _updateTargetBalance(
            targetNftId,
            _stakeBalance[targetNftId],
            _rewardBalance[targetNftId] + rewardIncrementAmount);

        emit LogStakingStoreRewardsIncreased(nftId, rewardIncrementAmount, _rewardBalance[nftId], lastUpdatedIn);
    }


    function claimUpTo(
        NftId nftId, 
        NftId targetNftId, 
        Amount maxClaimAmount
    )
        external
        restricted()
        returns (Amount claimedAmount)
    {
        Blocknumber lastUpdatedIn = _checkBalanceExists(nftId);

        // determine the claimable rewards amount
        claimedAmount = AmountLib.min(maxClaimAmount, _rewardBalance[nftId]);

        // decrease rewards by claimed amount
        _updateStakeBalance(
            nftId, 
            _stakeBalance[nftId], // unchanged stake balance
            _rewardBalance[nftId] - claimedAmount); // new reward balance

        _updateTargetBalance(
            targetNftId,
            _stakeBalance[targetNftId],
            _rewardBalance[targetNftId] - claimedAmount);

        emit LogStakingStoreRewardsDecreased(nftId, claimedAmount, _rewardBalance[nftId], lastUpdatedIn);
    }


    function unstakeUpTo(
        NftId nftId, 
        NftId targetNftId, 
        Amount maxUnstakeAmount,
        Amount maxClaimAmount
    )
        external
        restricted()
        returns (
            Amount unstakedAmount,
            Amount claimedAmount
        )
    {
        Blocknumber lastUpdatedIn = _checkBalanceExists(nftId);

        // determine amounts
        unstakedAmount = AmountLib.min(maxUnstakeAmount, _stakeBalance[nftId]);
        claimedAmount = AmountLib.min(maxClaimAmount, _rewardBalance[nftId]);

        // decrease stakes and rewards as determined
        _updateStakeBalance(
            nftId, 
            _stakeBalance[nftId] - unstakedAmount, // unchanged stake balance
            _rewardBalance[nftId] - claimedAmount); // new reward balance

        _updateTargetBalance(
            targetNftId,
            _stakeBalance[targetNftId] - unstakedAmount,
            _rewardBalance[targetNftId] - claimedAmount);

        emit LogStakingStoreStakesDecreased(nftId, unstakedAmount, _stakeBalance[nftId], lastUpdatedIn);
        emit LogStakingStoreRewardsDecreased(nftId, claimedAmount, _rewardBalance[nftId], lastUpdatedIn);
    }

    //--- view functions -----------------------------------------------//

    function getStakingReader() external view returns (StakingReader stakingReader){
        return _reader;
    }

    // TODO rename
    function getTargetNftIdSet() external view returns (NftIdSet targetNftIdSet){
        return _targetNftIdSet;
    }

    function getStakingRate(uint256 chainId, address token) external view returns (UFixed stakingRate) { return _stakingRate[chainId][token]; }

    function exists(NftId stakeNftId) external view returns (bool) { return exists(stakeNftId.toKey32(STAKE())); }

    function getTotalValueLocked(NftId nftId, address token) external view returns (Amount tvlBalanceAmount) { return _tvlBalance[nftId][token]; }
    function getRequiredStakeBalance(NftId nftId) external view returns (Amount requiredAmount) { return _tvlRequiredDip[nftId]; }

    function getReserveBalance(NftId nftId) external view returns (Amount balanceAmount) { return _reserveBalance[nftId]; }
    function getStakeBalance(NftId nftId) external view returns (Amount balanceAmount) { return _stakeBalance[nftId]; }
    function getRewardBalance(NftId nftId) external view returns (Amount rewardAmount) { return _rewardBalance[nftId]; }
    function getBalanceUpdatedAt(NftId nftId) external view returns (Timestamp updatedAt) { return _lastUpdatedAt[nftId]; }
    function getBalanceUpdatedIn(NftId nftId) external view returns (Blocknumber blocknumber) { return _lastUpdatedIn[nftId]; }


    function getTargetBalances(NftId nftId)
        external
        view
        returns (
            Amount stakeBalance,
            Amount rewardBalance,
            Amount reserveBalance,
            Blocknumber lastUpdatedIn
        )
    {
        stakeBalance = _stakeBalance[nftId];
        rewardBalance = _rewardBalance[nftId];
        reserveBalance = _reserveBalance[nftId];
        lastUpdatedIn = _lastUpdatedIn[nftId];
    }


    function getStakeBalances(NftId nftId)
        external
        view
        returns (
            Amount stakeBalance,
            Amount rewardBalance,
            Timestamp lastUpdatedAt
        )
    {
        stakeBalance = _stakeBalance[nftId];
        rewardBalance = _rewardBalance[nftId];
        lastUpdatedAt = _lastUpdatedAt[nftId];
    }

    //--- private functions -------------------------------------------//

    function _createTarget(
        NftId targetNftId,
        IStaking.TargetInfo memory targetInfo
    )
        private
    {
        _create(
            targetNftId.toKey32(TARGET()),
            abi.encode(targetInfo));

        // initialize tvl and stake balance
        _tvlLastUpdatedIn[targetNftId]= BlocknumberLib.currentBlocknumber();
        _createTargetBalance(targetNftId);

        _targetNftIdSet.add(targetNftId);
    }

    function _updateReserves(
        NftId targetNftId, 
        Amount newRewardBalance
    )
        private
        returns (Blocknumber lastUpdatedIn)
    {
        if (_lastUpdatedIn[targetNftId].eqz()) {
            revert ErrorStakingStoreNotTarget(targetNftId);
        }

        lastUpdatedIn = _lastUpdatedIn[targetNftId];

        _reserveBalance[targetNftId] = newRewardBalance;
        _lastUpdatedIn[targetNftId] = BlocknumberLib.currentBlocknumber();
    }


    function _createTargetBalance(NftId nftId)
        private
    {
        if (_lastUpdatedIn[nftId].gtz()) {
            revert ErrorStakingStoreBalanceAlreadyInitialized(nftId);
        }

        // set target balances to 0
        _stakeBalance[nftId] = AmountLib.zero();
        _rewardBalance[nftId] = AmountLib.zero();
        _reserveBalance[nftId] = AmountLib.zero();

        // set last updated in to current block number
        // we don't need last updated at timestamp for targets
        _lastUpdatedIn[nftId] = BlocknumberLib.currentBlocknumber();
    }


    function _createStakeBalance(NftId nftId)
        private
    {
        if (_lastUpdatedIn[nftId].gtz()) {
            revert ErrorStakingStoreBalanceAlreadyInitialized(nftId);
        }

        // set stake balances to 0
        _stakeBalance[nftId] = AmountLib.zero();
        _rewardBalance[nftId] = AmountLib.zero();

        // set last updated at/in to current timestamp/block number
        _lastUpdatedAt[nftId] = TimestampLib.blockTimestamp();
        _lastUpdatedIn[nftId] = BlocknumberLib.currentBlocknumber();
    }


    function _updateStakeBalance(
        NftId stakeNftId,
        Amount newStakeAmount,
        Amount newRewardAmount
    )
        private
    {
        _stakeBalance[stakeNftId] = newStakeAmount;
        _rewardBalance[stakeNftId] = newRewardAmount;

        _lastUpdatedAt[stakeNftId] = TimestampLib.blockTimestamp();
        _lastUpdatedIn[stakeNftId] = BlocknumberLib.currentBlocknumber();
    }


    function _updateTargetBalance(
        NftId targetNftId,
        Amount newStakeAmount,
        Amount newRewardAmount
    )
        private
    {
        _stakeBalance[targetNftId] = newStakeAmount;
        _rewardBalance[targetNftId] = newRewardAmount;

        // for targets we don't need the timestamp, just the blocknumber
        _lastUpdatedIn[targetNftId] = BlocknumberLib.currentBlocknumber();
    }

    function _checkBalanceExists(NftId nftId)
        private
        view
        returns (Blocknumber lastUpdatedIn)
    {
        lastUpdatedIn = _lastUpdatedIn[nftId];

        if (lastUpdatedIn.eqz()) {
            revert ErrorStakingStoreBalanceNotInitialized(nftId);
        }
    }


    function _getAndVerifyTvl(
        NftId targetNftId,
        address token
    )
        private
        view
        returns (
            Blocknumber tvlLastUpdatedIn,
            Amount oldBalance,
            Amount oldDipBalance
        )
    {
        tvlLastUpdatedIn = _tvlLastUpdatedIn[targetNftId];

        if (tvlLastUpdatedIn.eqz()) {
            revert ErrorStakingStoreTvlBalanceNotInitialized(targetNftId);
        }

        oldBalance = _tvlBalance[targetNftId][token];
        oldDipBalance = _tvlInDip[targetNftId][token];
    }
}
