// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";

import {IRegistry} from "../registry/IRegistry.sol";
import {IStaking} from "./IStaking.sol";

import {Amount, AmountLib} from "../type/Amount.sol";
import {ChainId, ChainIdLib} from "../type/ChainId.sol";
import {Blocknumber, BlocknumberLib} from "../type/Blocknumber.sol";
import {KeyValueStore} from "../shared/KeyValueStore.sol";
import {KEEP_STATE} from "../type/StateId.sol";
import {NftId, NftIdLib} from "../type/NftId.sol";
import {NftIdSet} from "../shared/NftIdSet.sol";
import {ObjectType} from "../type/ObjectType.sol";
import {PROTOCOL, STAKE, TARGET} from "../type/ObjectType.sol";
import {Seconds, SecondsLib} from "../type/Seconds.sol";
import {StakingLib} from "./StakingLib.sol";
import {StakingLifecycle} from "./StakingLifecycle.sol";
import {StakingReader} from "./StakingReader.sol";
import {TargetManagerLib} from "./TargetManagerLib.sol";
import {Timestamp, TimestampLib} from "../type/Timestamp.sol";
import {TokenRegistry} from "../registry/TokenRegistry.sol";
import {UFixed, UFixedLib} from "../type/UFixed.sol";


contract StakingStore is 
    AccessManaged,
    KeyValueStore,
    StakingLifecycle
{

    // token
    error ErrorStakingStoreTokenNotRegistered(ChainId chainId, address token);
    error ErrorStakingStoreTokenAlreadyAdded(ChainId chainId, address token);
    error ErrorStakingStoreTokenUnknown(ChainId chainId, address token);

    // target
    error ErrorStakingStoreTargetNotInitialized(NftId targetNftId);

    // in/decreasing reward reserves
    error ErrorStakingStoreNotTarget(NftId targetNftId);
    error ErrorStakingStoreRewardReservesInsufficient(NftId targetNftId, Amount reserveAmount, Amount claimedAmount);

    // stakes
    error ErrorStakingStoreStakesExceedingTargetMaxAmount(NftId targetNftId, Amount maxStakedAmount, Amount newIStaking);
    error ErrorStakingStoreStakeNotInitialized(NftId nftId);

    // creating and updating of staking balance
    error ErrorStakingStoreStakeBalanceAlreadyInitialized(NftId nftId);
    error ErrorStakingStoreStakeBalanceNotInitialized(NftId nftI);

    // creating and updating of tvl balance
    error ErrorStakingStoreTvlBalanceAlreadyInitialized(NftId nftId, address token);
    error ErrorStakingStoreTvlBalanceNotInitialized(NftId nftId, address token);

    IRegistry private _registry;
    NftIdSet private _targetNftIdSet;
    StakingReader private _reader;

    // stakes
    mapping(NftId stakeNftId => IStaking.StakeInfo) private _stakeInfo;

    // targets
    mapping(NftId targetNftId => IStaking.TargetInfo) private _targetInfo;
    mapping(NftId targetNftId => mapping(address token => IStaking.TvlInfo)) private _tvlInfo;
    mapping(NftId targetNftId => address [] token) _targetToken;

    // staking rate
    mapping(ChainId chainId => mapping(address token => IStaking.TokenInfo)) private _tokenInfo;


    constructor(IRegistry registry, StakingReader reader)
        AccessManaged(msg.sender)
    {
        // set final authority
        setAuthority(registry.getAuthority());

        // set internal variables
        _registry = registry;
        _reader = reader;
        _targetNftIdSet = new NftIdSet();

        // register protocol target
        _createTarget(
            NftIdLib.toNftId(1101), 
            PROTOCOL(),
            TargetManagerLib.getDefaultLockingPeriod(),
            TargetManagerLib.getDefaultRewardRate(),
            false); // no parameter check
    }


    //--- token management --------------------------------------------------//

    /// @dev Registers a token for tvl management.
    function addToken(
        ChainId chainId, 
        address token
    )
        external
        restricted() // token registry via staking
    {
        // checks

        IStaking.TokenInfo storage info = _tokenInfo[chainId][token];

        // check token is not yet registered
        if (info.lastUpdateIn.gtz()) {
            revert ErrorStakingStoreTokenAlreadyAdded(chainId, token);
        }

        // TODO cleanup
        // // check if token is registered with token registry
        // TokenRegistry tokenRegistry = TokenRegistry(_registry.getTokenRegistryAddress());
        // if (!tokenRegistry.isRegistered(chainId, token)) {
        //     revert ErrorStakingStoreTokenNotRegistered(chainId, token);
        // }

        info.stakingRate = UFixedLib.zero();
        info.lastUpdateIn = BlocknumberLib.current();
    }


    /// @dev Sets the staking rate for the token.
    function setStakingRate(
        ChainId chainId, 
        address token, 
        UFixed stakingRate
    )
        external
        restricted() // staking
        returns (
            UFixed oldStakingRate,
            Blocknumber lastUpdatedIn
        )
    {
        IStaking.TokenInfo storage info = _tokenInfo[chainId][token];
        if (info.lastUpdateIn.eqz()) {
            revert ErrorStakingStoreTokenUnknown(chainId, token);
        }

        // get previous values
        oldStakingRate = info.stakingRate;
        lastUpdatedIn = info.lastUpdateIn;

        // update values
        info.stakingRate = stakingRate;
        info.lastUpdateIn = BlocknumberLib.current();
    }

    //--- target management -------------------------------------------------//

    function createTarget(
        NftId targetNftId,
        ObjectType objectType,
        Seconds lockingPeriod,
        UFixed rewardRate
    )
        external
        restricted() // staking
    {
        _createTarget(targetNftId, objectType, lockingPeriod, rewardRate, true);
    }


    function setLockingPeriod(
        NftId targetNftId,
        Seconds lockingPeriod
    )
        external
        restricted() // staking
        returns (
            Seconds oldLockingPeriod,
            Blocknumber lastUpdatedIn
        )
    {
        TargetManagerLib.checkLockingPeriod(targetNftId, lockingPeriod);

        IStaking.TargetInfo storage targetInfo;
        (targetInfo, lastUpdatedIn) = _verifyAndUpdateTarget(targetNftId);

        oldLockingPeriod = targetInfo.lockingPeriod;
        targetInfo.lockingPeriod = lockingPeriod;
    }


    function setRewardRate(
        NftId targetNftId,
        UFixed rewardRate
    )
        external
        restricted() // staking
        returns (
            UFixed oldRewardRate,
            Blocknumber lastUpdatedIn
        )
    {
        TargetManagerLib.checkRewardRate(targetNftId, rewardRate);

        IStaking.TargetInfo storage targetInfo;
        (targetInfo, lastUpdatedIn) = _verifyAndUpdateTarget(targetNftId);

        oldRewardRate = targetInfo.rewardRate;
        targetInfo.rewardRate = rewardRate;
    }


    function setMaxStakedAmount(
        NftId targetNftId,
        Amount maxStakedAmount
    )
        external
        restricted() // staking
        returns (
            Amount oldMaxStakedAmount,
            Blocknumber lastUpdatedIn
        )
    {
        IStaking.TargetInfo storage targetInfo;
        (targetInfo, lastUpdatedIn) = _verifyAndUpdateTarget(targetNftId);

        oldMaxStakedAmount = targetInfo.maxStakedAmount;
        targetInfo.maxStakedAmount = maxStakedAmount;
    }


    // TODO move to private functions
    function _verifyAndUpdateTarget(NftId targetNftId)
        private
        returns (
            IStaking.TargetInfo storage targetInfo,
            Blocknumber lastUpdatedIn
        )
    {
        // checks
        targetInfo = _getAndVerifyTarget(targetNftId);
        lastUpdatedIn = targetInfo.lastUpdateIn;
        targetInfo.lastUpdateIn = BlocknumberLib.current();
    }


    // TODO move to private functions
    function _createTarget(
        NftId targetNftId,
        ObjectType objectType,
        Seconds lockingPeriod,
        UFixed rewardRate,
        bool checkParameters
    )
        private
    {
        // checks
        if (checkParameters) {
            TargetManagerLib.checkTargetParameters(
                _registry, 
                _reader, 
                targetNftId, 
                objectType, 
                lockingPeriod, 
                rewardRate);
        }

        // effects
        IStaking.TargetInfo storage targetInfo = _targetInfo[targetNftId];
        targetInfo.stakedAmount = AmountLib.zero();
        targetInfo.rewardAmount = AmountLib.zero();
        targetInfo.reserveAmount = AmountLib.zero();
        targetInfo.maxStakedAmount = AmountLib.max();

        targetInfo.objectType = objectType;
        targetInfo.lockingPeriod = lockingPeriod;
        targetInfo.rewardRate = rewardRate;
        targetInfo.chainId = ChainIdLib.fromNftId(targetNftId);
        targetInfo.lastUpdateIn = BlocknumberLib.current();

        // add new target to target set
        _targetNftIdSet.add(targetNftId);
    }


    function addTargetToken(
        NftId targetNftId,
        address token
    )
        external
        restricted()
    {
        // checks

        // skip registering if tvl balance has already been initialized
        IStaking.TvlInfo storage tvlInfo = _tvlInfo[targetNftId][token];
        if (tvlInfo.lastUpdateIn.gtz()) {
            return;
        }

        // check target exists
        _getAndVerifyTarget(targetNftId);

        // check token is known for chain id of target
        ChainId chainId = ChainIdLib.fromNftId(targetNftId);
        if (_tokenInfo[chainId][token].lastUpdateIn.eqz()) {
            revert ErrorStakingStoreTokenUnknown(chainId, token);
        }

        // effects
        tvlInfo.tvlAmount = AmountLib.zero();
        tvlInfo.lastUpdateIn = BlocknumberLib.current();

        // add token to list of know tokens for target
        _targetToken[targetNftId].push(token);
    }


    function increaseReserves(
        NftId targetNftId, 
        Amount dipAmount
    )
        external
        restricted()
        returns (Amount newReserveBalance)
    {
        // checks
        IStaking.TargetInfo storage targetInfo = _getAndVerifyTarget(targetNftId);

        // effects
        targetInfo.reserveAmount = targetInfo.reserveAmount + dipAmount;
        targetInfo.lastUpdateIn = BlocknumberLib.current();
        newReserveBalance = targetInfo.reserveAmount;
    }


    function decreaseReserves(
        NftId targetNftId, 
        Amount dipAmount
    )
        external
        restricted()
        returns (Amount newReserveBalance)
    {
        // checks
        IStaking.TargetInfo storage targetInfo = _getAndVerifyTarget(targetNftId);

        // check if reserves are sufficient
        if (dipAmount > targetInfo.reserveAmount) {
            revert ErrorStakingStoreRewardReservesInsufficient(
                targetNftId,
                targetInfo.reserveAmount,
                dipAmount);
        }

        // effects
        targetInfo.reserveAmount = targetInfo.reserveAmount - dipAmount;
        targetInfo.lastUpdateIn = BlocknumberLib.current();
        newReserveBalance = targetInfo.reserveAmount;
    }


    //--- tvl specific functions -------------------------------------//

    function increaseTotalValueLocked(
        NftId targetNftId,
        address token,
        Amount amount
    )
        external
        restricted()
        returns (Amount newBalance)
    {
        // checks
        IStaking.TvlInfo storage tvlInfo = _getAndVerifyTvl(targetNftId, token);

        // effects
        tvlInfo.tvlAmount = tvlInfo.tvlAmount + amount;
        tvlInfo.lastUpdateIn = BlocknumberLib.current();
        newBalance = tvlInfo.tvlAmount;
    }


    function decreaseTotalValueLocked(
        NftId targetNftId,
        address token,
        Amount amount
    )
        external
        restricted()
        returns (Amount newBalance)
    {
        // checks
        IStaking.TvlInfo storage tvlInfo = _getAndVerifyTvl(targetNftId, token);

        // effects
        tvlInfo.tvlAmount = tvlInfo.tvlAmount - amount;
        tvlInfo.lastUpdateIn = BlocknumberLib.current();
        newBalance = tvlInfo.tvlAmount;
    }

    //--- stake specific functions -------------------------------------//

    function createStake(
        NftId stakeNftId, 
        NftId targetNftId, 
        Amount stakedAmount
    )
        external
        restricted()
        returns (Timestamp lockedUntil)
    {
        // checks
        lockedUntil = StakingLib.checkCreateParameters(
            _reader,
            targetNftId,
            stakedAmount);

        IStaking.StakeInfo storage stakeInfo = _stakeInfo[stakeNftId];
        if (stakeInfo.lastUpdateIn.gtz()) {
            revert ErrorStakingStoreStakeBalanceAlreadyInitialized(stakeNftId);
        }

        IStaking.TargetInfo storage targetInfo = _getAndVerifyTarget(targetNftId);
        _checkMaxStakedAmount(targetNftId, targetInfo, stakedAmount);

        // effects
        // update target
        targetInfo.stakedAmount = targetInfo.stakedAmount + stakedAmount;
        targetInfo.lastUpdateIn = BlocknumberLib.current();

        // update stake
        stakeInfo.targetNftId = targetNftId;
        stakeInfo.stakedAmount = stakedAmount;
        stakeInfo.rewardAmount = AmountLib.zero();
        stakeInfo.lockedUntil = lockedUntil;
        stakeInfo.lastUpdateAt = TimestampLib.current();
        stakeInfo.lastUpdateIn = BlocknumberLib.current();
    }

    /// @dev Increases the stake amount and optionally restakes the rewards.
    /// IMPORTANT: Function updateRewards must be called before this function in the same transaction.
    function increaseStakes(
        NftId stakeNftId, 
        Amount stakeIncreaseAmount, // additional staked amount
        Seconds additionalLockingPeriod, // duration to increase locked until
        bool restakeRewards
    )
        external
        restricted()
        returns (
            Amount stakeBalance,
            Amount rewardBalance,
            Timestamp lockedUntil
        )
    {
        // checks
        IStaking.StakeInfo storage stakeInfo = _getAndVerifyStake(stakeNftId);
        IStaking.TargetInfo storage targetInfo = _getAndVerifyTarget(stakeInfo.targetNftId);
        Amount restakedRewardAmount = stakeInfo.rewardAmount;

        // calculate new values (with restaking)
        if (restakeRewards && restakedRewardAmount.gtz()) {
            Amount totalStakeIncreaseAmount = stakeIncreaseAmount + restakedRewardAmount;
            _checkMaxStakedAmount(stakeInfo.targetNftId, targetInfo, totalStakeIncreaseAmount);

            // effects
            // update target
            targetInfo.stakedAmount = targetInfo.stakedAmount + totalStakeIncreaseAmount;
            targetInfo.rewardAmount = targetInfo.rewardAmount - stakeInfo.rewardAmount;

            // update stake
            stakeInfo.stakedAmount = stakeInfo.stakedAmount + totalStakeIncreaseAmount;
            stakeInfo.rewardAmount = AmountLib.zero();

        // calculate new values (without restaking)
        } else {
            _checkMaxStakedAmount(stakeInfo.targetNftId, targetInfo, stakeIncreaseAmount);
    
            // effects
            // update target and stake
            targetInfo.stakedAmount = targetInfo.stakedAmount + stakeIncreaseAmount;
            stakeInfo.stakedAmount = stakeInfo.stakedAmount + stakeIncreaseAmount;
        }

        // update meta data for target and stake
        targetInfo.lastUpdateIn = BlocknumberLib.current();
        stakeInfo.lastUpdateAt = TimestampLib.current();
        stakeInfo.lastUpdateIn = BlocknumberLib.current();

        // increase locked until if applicable
        if (additionalLockingPeriod.gtz()) {
            stakeInfo.lockedUntil = stakeInfo.lockedUntil.addSeconds(additionalLockingPeriod);
        }

        // set return values
        stakeBalance = stakeInfo.stakedAmount;
        rewardBalance = stakeInfo.rewardAmount;
        lockedUntil = stakeInfo.lockedUntil;
    }


    /// @dev Decreases the staking and reward amounts.
    /// The function attepmts to unstake up to the specified max amounts.
    /// In case the specified amounts are higher than the current staked and reward amounts, the avaiable amounts are unstaked.
    /// The method optionally restakes the rewards.
    /// IMPORTANT: Function updateRewards must be called before this function in the same transaction.
    function decreaseStakes(
        NftId stakeNftId, 
        Amount maxUnstakedAmount,
        Amount maxClaimAmount,
        bool restakeRewards
    )
        external
        restricted()
        returns (
            Amount restakedRewardAmount,
            Amount unstakedAmount,
            Amount claimedAmount,
            Amount stakedBalance,
            Amount rewardBalance
        )
    {
        // checks
        IStaking.StakeInfo storage stakeInfo = _getAndVerifyStake(stakeNftId);
        IStaking.TargetInfo storage targetInfo = _getAndVerifyTarget(stakeInfo.targetNftId);

        // restake rewards if applicable
        if (restakeRewards && stakeInfo.rewardAmount.gtz()) {
            restakedRewardAmount = stakeInfo.rewardAmount;
            _checkMaxStakedAmount(stakeInfo.targetNftId, targetInfo, restakedRewardAmount);

            // update target
            targetInfo.stakedAmount = targetInfo.stakedAmount + restakedRewardAmount;
            targetInfo.rewardAmount = targetInfo.rewardAmount - restakedRewardAmount;

            // update stake
            stakeInfo.stakedAmount = stakeInfo.stakedAmount + restakedRewardAmount;
            stakeInfo.rewardAmount = AmountLib.zero();

        } else {
            restakedRewardAmount = AmountLib.zero();
        }
    
        // determine amounts
        unstakedAmount = AmountLib.min(maxUnstakedAmount, stakeInfo.stakedAmount);
        claimedAmount = AmountLib.min(maxClaimAmount, stakeInfo.rewardAmount);

        // update reserves if rewards are claimed
        if (!restakeRewards) {
            // check if reserves are sufficient
            if (claimedAmount > targetInfo.reserveAmount) {
                revert ErrorStakingStoreRewardReservesInsufficient(
                    stakeInfo.targetNftId,
                    targetInfo.reserveAmount,
                    claimedAmount);
            }

            targetInfo.reserveAmount = targetInfo.reserveAmount - claimedAmount;
        }

        // update target
        targetInfo.stakedAmount = targetInfo.stakedAmount - unstakedAmount;
        targetInfo.rewardAmount = targetInfo.rewardAmount - claimedAmount;
        targetInfo.lastUpdateIn = BlocknumberLib.current();

        // update stake
        stakeInfo.stakedAmount = stakeInfo.stakedAmount - unstakedAmount;
        stakeInfo.rewardAmount = stakeInfo.rewardAmount - claimedAmount;
        stakeInfo.lastUpdateAt = TimestampLib.current();
        stakeInfo.lastUpdateIn = BlocknumberLib.current();

        // set return values
        stakedBalance = stakeInfo.stakedAmount;
        rewardBalance = stakeInfo.rewardAmount;
    }


    function updateRewards(
        NftId stakeNftId
    )
        external
        restricted()
        returns (
            Amount rewardIncreaseAmount,
            Seconds targetLockingPeriod,
            Amount stakeBalance,
            Amount rewardBalance,
            Timestamp lockedUntil
        )
    {
        // checks
        IStaking.StakeInfo storage stakeInfo = _getAndVerifyStake(stakeNftId);
        IStaking.TargetInfo storage targetInfo = _getAndVerifyTarget(stakeInfo.targetNftId);

        // get seconds since last update on stake
        Seconds duration = SecondsLib.toSeconds(
            block.timestamp - stakeInfo.lastUpdateAt.toInt());
        
        // calculate reward increase since
        rewardIncreaseAmount = StakingLib.calculateRewardAmount(
            targetInfo.rewardRate,
            duration,
            stakeInfo.stakedAmount);

        // effects
        if (rewardIncreaseAmount.gtz()) {
            // update target
            targetInfo.rewardAmount = targetInfo.rewardAmount + rewardIncreaseAmount;
            targetInfo.lastUpdateIn = BlocknumberLib.current();

            // update stake
            stakeInfo.rewardAmount = stakeInfo.rewardAmount + rewardIncreaseAmount;
            stakeInfo.lastUpdateIn = BlocknumberLib.current();
            stakeInfo.lastUpdateAt = TimestampLib.current();
        }

        // set remaining return values
        targetLockingPeriod = targetInfo.lockingPeriod;
        stakeBalance = stakeInfo.stakedAmount;
        rewardBalance = stakeInfo.rewardAmount;
        lockedUntil = stakeInfo.lockedUntil;
    }


    function restakeRewards(
        NftId stakeNftId,
        Amount additionalRewardAmount, 
        Seconds additionalLockingPeriod // duration to increase locked until
    )
        external
        restricted()
        returns (
            Amount newstakedAmount
        )
    {
        // checks
        IStaking.StakeInfo storage stakeInfo = _getAndVerifyStake(stakeNftId);

        Amount oldRewardAmount = stakeInfo.rewardAmount;
        Amount updatedRewardAmount = stakeInfo.rewardAmount + additionalRewardAmount;

        IStaking.TargetInfo storage targetInfo = _getAndVerifyTarget(stakeInfo.targetNftId);
        _checkMaxStakedAmount(stakeInfo.targetNftId, targetInfo, updatedRewardAmount);

        // effects
        // update target
        targetInfo.stakedAmount = targetInfo.stakedAmount + updatedRewardAmount;
        targetInfo.rewardAmount = targetInfo.rewardAmount - oldRewardAmount;
        targetInfo.lastUpdateIn = BlocknumberLib.current();

        // update stake
        stakeInfo.stakedAmount = stakeInfo.stakedAmount + updatedRewardAmount;
        stakeInfo.rewardAmount = AmountLib.zero();
        stakeInfo.lastUpdateAt = TimestampLib.current();
        stakeInfo.lastUpdateIn = BlocknumberLib.current();

        // increase locked until if applicable
        if (additionalLockingPeriod.gtz()) {
            stakeInfo.lockedUntil.addSeconds(additionalLockingPeriod);
        }
    }


    //--- view functions -----------------------------------------------//

    function getStakingReader() external view returns (StakingReader stakingReader){
        return _reader;
    }


    function exists(NftId stakeNftId) external view returns (bool) { 
        return _stakeInfo[stakeNftId].lastUpdateIn.gtz();
    }


    function getRequiredStakeBalance(NftId targetNftId)
        external
        view
        returns (Amount requiredStakedAmount)
    {
        address [] memory tokens = _targetToken[targetNftId];
        if (tokens.length == 0) {
            return AmountLib.zero();
        }

        requiredStakedAmount = AmountLib.zero();
        ChainId targetChainId = _targetInfo[targetNftId].chainId;
        address token;
        Amount tvlAmount;
        UFixed stakingRate;

        for (uint256 i = 0; i < tokens.length; i++) {
            token = tokens[i];
            tvlAmount = _tvlInfo[targetNftId][token].tvlAmount;
            if (tvlAmount.eqz()) { continue; }

            stakingRate = _tokenInfo[targetChainId][token].stakingRate;
            if (stakingRate.eqz()) { continue; }

            requiredStakedAmount = requiredStakedAmount + tvlAmount.multiplyWith(stakingRate);
        }
    }


    /// @dev Returns true iff current stake amount is still locked
    function isStakeLocked(NftId stakeNftId) external view returns (bool) { 
        return _stakeInfo[stakeNftId].lockedUntil > TimestampLib.current(); 
    }


    /// @dev Returns the stake infos for the specified stake.
    function getStakeInfo(NftId stakeNftId) external view returns (IStaking.StakeInfo memory stakeInfo) { 
        return _stakeInfo[stakeNftId]; 
    }


    /// @dev Returns the stake infos for the specified stake.
    function getStakeTarget(NftId stakeNftId) external view returns (NftId targetNftId) { 
        return _stakeInfo[stakeNftId].targetNftId; 
    }


    /// @dev Returns the target infos for the specified target.
    function getTargetInfo(NftId targetNftId) external view returns (IStaking.TargetInfo memory targetInfo) { 
        return _targetInfo[targetNftId]; 
    }


    /// @dev Returns the tvl infos for the specified target.
    function getTvlInfo(NftId targetNftId, address token) external view returns (IStaking.TvlInfo memory tvlInfo) {
        return _tvlInfo[targetNftId][token];
    }


    /// @dev Returns the tvl infos for the specified target.
    function getTokenInfo(ChainId chainId, address token) external view returns (IStaking.TokenInfo memory tokenInfo) {
        return _tokenInfo[chainId][token];
    }


    function getTargetSet() external view returns (NftIdSet targetNftIdSet) { 
        return _targetNftIdSet;
    }


    //--- private stake and target functions --------------------------------//


    function _getAndVerifyStake(
        NftId stakeNftId
    )
        private
        view
        returns (
            IStaking.StakeInfo storage stakeInfo
        )
    {
        stakeInfo = _stakeInfo[stakeNftId];
        if (stakeInfo.lastUpdateIn.eqz()) {
            revert ErrorStakingStoreStakeNotInitialized(stakeNftId);
        }
    }


    function _checkMaxStakedAmount(
        NftId targetNftId, 
        IStaking.TargetInfo storage targetInfo, 
        Amount additionalstakedAmount
    )
        private
    {
        if (targetInfo.stakedAmount + additionalstakedAmount > targetInfo.maxStakedAmount) {
            revert ErrorStakingStoreStakesExceedingTargetMaxAmount(
                targetNftId,
                targetInfo.maxStakedAmount,
                targetInfo.stakedAmount + additionalstakedAmount);
        }

        // TODO add check for tvl dependent maximum, see #628
    }


    function _getAndVerifyTarget(
        NftId targetNftId
    )
        private
        view
        returns (
            IStaking.TargetInfo storage targetInfo
        )
    {
        targetInfo = _targetInfo[targetNftId];

        if (targetInfo.lastUpdateIn.eqz()) {
            revert ErrorStakingStoreTargetNotInitialized(targetNftId);
        }
    }

    //--- private tvl functions ------------------------------------------------//

    /// @dev Initializes token balance handling for the specified target.
    function _createTvlBalance(NftId targetNftId, address token)
        private
    {
        IStaking.TvlInfo storage info = _tvlInfo[targetNftId][token];

        if (info.lastUpdateIn.gtz()) {
            revert ErrorStakingStoreTvlBalanceAlreadyInitialized(targetNftId, token);
        }

        // set tvl balances to 0 and update last updated in
        info.tvlAmount = AmountLib.zero();
        info.lastUpdateIn = BlocknumberLib.current();
    }


    function _updateTvlBalance(
        NftId targetNftId,
        address token,
        Amount newTvlAmount
    )
        private
        returns (
            Amount oldTvlAmount,
            Blocknumber lastUpdatedIn
        )
    {
        IStaking.TvlInfo storage tvlInfo = _getAndVerifyTvl(targetNftId, token);
        oldTvlAmount = tvlInfo.tvlAmount;
        lastUpdatedIn = tvlInfo.lastUpdateIn;

        tvlInfo.tvlAmount = newTvlAmount;
        tvlInfo.lastUpdateIn = BlocknumberLib.current();
    }


    function _getAndVerifyTvl(NftId targetNftId, address token)
        private
        view
        returns (IStaking.TvlInfo storage tvlInfo)
    {
        tvlInfo = _tvlInfo[targetNftId][token];
        if (tvlInfo.lastUpdateIn.eqz()) {
            revert ErrorStakingStoreTvlBalanceNotInitialized(targetNftId, token);
        }
    }
}
