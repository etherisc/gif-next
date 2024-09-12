// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol"; 

import {IRegistry} from "../registry/IRegistry.sol";
import {IStaking} from "./IStaking.sol";
import {ITargetLimitHandler} from "./ITargetLimitHandler.sol";

import {Amount, AmountLib} from "../type/Amount.sol";
import {ChainId, ChainIdLib} from "../type/ChainId.sol";
import {Blocknumber, BlocknumberLib} from "../type/Blocknumber.sol";
import {KeyValueStore} from "../shared/KeyValueStore.sol";
import {NftId, NftIdLib} from "../type/NftId.sol";
import {NftIdSet} from "../shared/NftIdSet.sol";
import {ObjectType} from "../type/ObjectType.sol";
import {PROTOCOL} from "../type/ObjectType.sol";
import {Seconds, SecondsLib} from "../type/Seconds.sol";
import {StakingLib} from "./StakingLib.sol";
import {StakingLifecycle} from "./StakingLifecycle.sol";
import {StakingReader} from "./StakingReader.sol";
import {TargetManagerLib} from "./TargetManagerLib.sol";
import {Timestamp, TimestampLib} from "../type/Timestamp.sol";
import {UFixed, UFixedLib} from "../type/UFixed.sol";


contract StakingStore is 
    Initializable,
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
    error ErrorStakingStoreLimitNotInitialized(NftId targetNftId);

    // in/decreasing reward reserves
    error ErrorStakingStoreNotTarget(NftId targetNftId);
    error ErrorStakingStoreRewardReservesInsufficient(NftId targetNftId, Amount reserveAmount, Amount claimedAmount);

    // stakes
    error ErrorStakingStoreStakesExceedingTargetMaxAmount(NftId targetNftId, Amount stakeLimitAmount, Amount newIStaking);
    error ErrorStakingStoreStakeNotInitialized(NftId nftId);

    // creating and updating of staking balance
    error ErrorStakingStoreStakeBalanceAlreadyInitialized(NftId nftId);
    error ErrorStakingStoreStakeBalanceNotInitialized(NftId nftI);

    // creating and updating of tvl balance
    error ErrorStakingStoreTvlBalanceAlreadyInitialized(NftId nftId, address token);
    error ErrorStakingStoreTvlBalanceNotInitialized(NftId nftId, address token);

    IRegistry private _registry;
    ITargetLimitHandler private _targetLimitHandler;
    StakingReader private _reader;
    NftIdSet private _targetNftIdSet;


    // stakes
    mapping(NftId stakeNftId => IStaking.StakeInfo) private _stakeInfo;

    // targets
    mapping(NftId targetNftId => IStaking.TargetInfo) private _targetInfo;
    mapping(NftId targetNftId => IStaking.LimitInfo) private _limitInfo;
    mapping(NftId targetNftId => mapping(address token => IStaking.TvlInfo)) private _tvlInfo;
    mapping(NftId targetNftId => address [] token) private _targetToken;

    // staking rate
    mapping(ChainId chainId => mapping(address token => IStaking.TokenInfo)) private _tokenInfo;


    constructor(
        IRegistry registry, 
        StakingReader reader
    )
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


    function initialize(
        address targetLimitHandler
    )
        external
        initializer()
    {
        _targetLimitHandler = ITargetLimitHandler(targetLimitHandler);
    }


    //--- dependency management ---------------------------------------------//

    function setStakingReader(address reader)
        external
        restricted()
    {
        address oldReader = address(_reader);
        _reader = StakingReader(reader);

        emit IStaking.LogStakingStakingReaderSet(reader, oldReader);
    }


    function setTargetLimitHandler(address targetLimitHandler )
        external
        restricted()
    {
        address oldTargetHandler = address(_targetLimitHandler);
        _targetLimitHandler = ITargetLimitHandler(targetLimitHandler );

        emit IStaking.LogStakingTargetHandlerSet(targetLimitHandler , oldTargetHandler);
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

        info.stakingRate = UFixedLib.zero();
        info.lastUpdateIn = BlocknumberLib.current();

        // logging
        emit IStaking.LogStakingTokenAdded(chainId, token);
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


    // TODO refactor to set limits functionality
    function setMaxStakedAmount(
        NftId targetNftId,
        Amount stakeLimitAmount
    )
        external
        restricted() // staking
        returns (
            Amount oldLimitAmount,
            Blocknumber lastUpdatedIn
        )
    {
        IStaking.TargetInfo storage targetInfo;
        (targetInfo, lastUpdatedIn) = _verifyAndUpdateTarget(targetNftId);

        oldLimitAmount = targetInfo.limitAmount;
        targetInfo.limitAmount = stakeLimitAmount;

        emit IStaking.LogStakingTargetMaxStakedAmountSet(targetNftId, stakeLimitAmount, lastUpdatedIn);

    }


    function setTargetLimits(
        NftId targetNftId, 
        Amount marginAmount, 
        Amount hardLimitAmount
    )
        external
        virtual
        restricted()
    {
        // checks
        IStaking.LimitInfo storage limitInfo = _getAndVerifyLimit(targetNftId);
        Blocknumber lastUpdateIn = limitInfo.lastUpdateIn;

        // effects
        limitInfo.marginAmount = marginAmount;
        limitInfo.hardLimitAmount = hardLimitAmount;
        limitInfo.lastUpdateIn = BlocknumberLib.current();

        // logging
        emit IStaking.LogStakingTargetLimitsUpdated(
            targetNftId,
            marginAmount,
            hardLimitAmount,
            lastUpdateIn);
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


    function refillRewardReserves(
        NftId targetNftId, 
        Amount dipAmount
    )
        external
        restricted()
        returns (Amount newReserveBalance)
    {
        // checks
        IStaking.TargetInfo storage targetInfo = _getAndVerifyTarget(targetNftId);
        Blocknumber lastUpdateIn = targetInfo.lastUpdateIn;

        // effects
        targetInfo.reserveAmount = targetInfo.reserveAmount + dipAmount;
        targetInfo.lastUpdateIn = BlocknumberLib.current();

        // logging
        newReserveBalance = targetInfo.reserveAmount;
        emit IStaking.LogStakingRewardReservesRefilled(
            targetNftId,
            dipAmount,
            _registry.ownerOf(targetNftId),
            newReserveBalance,
            lastUpdateIn);
    }


    function withdrawRewardReserves(
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
        Blocknumber lastUpdateIn = _decreaseReserves(targetNftId, targetInfo, dipAmount);

        // logging
        newReserveBalance = targetInfo.reserveAmount;
        emit IStaking.LogStakingRewardReservesWithdrawn(
            targetNftId,
            dipAmount,
            _registry.ownerOf(targetNftId),
            newReserveBalance,
            lastUpdateIn);
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
        Blocknumber lastUpdateIn = tvlInfo.lastUpdateIn;

        // effects
        // update tvl balance and adapts required stakes if necessary
        tvlInfo.tvlAmount = tvlInfo.tvlAmount + amount;
        _checkAndUpdateTargetLimit(targetNftId, token, tvlInfo);
        tvlInfo.lastUpdateIn = BlocknumberLib.current();
        newBalance = tvlInfo.tvlAmount;

        // logging
        emit IStaking.LogStakingTvlIncreased(targetNftId, token, amount, newBalance, lastUpdateIn);
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
        Blocknumber lastUpdateIn = tvlInfo.lastUpdateIn;

        // effects
        // update tvl balance and adapts required stakes if necessary
        tvlInfo.tvlAmount = tvlInfo.tvlAmount - amount;
        _checkAndUpdateTargetLimit(targetNftId, token, tvlInfo);
        tvlInfo.lastUpdateIn = BlocknumberLib.current();
        newBalance = tvlInfo.tvlAmount;

        // logging
        emit IStaking.LogStakingTvlDecreased(targetNftId, token, amount, newBalance, lastUpdateIn);
    }


    function updateTargetLimit(NftId targetNftId)
        external
        restricted()
        returns (Amount stakeLimitAmount)
    {
        return _updateTargetLimit(targetNftId);
    }


    function _checkAndUpdateTargetLimit(
        NftId targetNftId, 
        address token,
        IStaking.TvlInfo storage tvlInfo
    )
        internal
    {
        // update counter
        tvlInfo.updatesCounter++;

        // check if upgrade is necessary
        bool updateRequired = _targetLimitHandler.isLimitUpdateRequired(
            targetNftId, 
            token, 
            tvlInfo.updatesCounter,
            tvlInfo.tvlBaselineAmount, 
            tvlInfo.tvlAmount);

        if (updateRequired) {
            // reset baseline and counter
            tvlInfo.tvlBaselineAmount = tvlInfo.tvlAmount;
            tvlInfo.updatesCounter = 0;

            // update limit
            _updateTargetLimit(targetNftId);
        }
    }


    function _updateTargetLimit(NftId targetNftId)
        internal
        returns (Amount limitAmount)
    {
        // checks
        IStaking.TargetInfo storage targetInfo = _getAndVerifyTarget(targetNftId);
        IStaking.LimitInfo storage limitInfo = _getAndVerifyLimit(targetNftId);
        Blocknumber lastUpdateIn = limitInfo.lastUpdateIn;

        // calculate max stake amount
        Amount requiredStakeAmount = getRequiredStakeBalance(targetNftId);
        limitAmount = AmountLib.min(
            targetInfo.limitAmount, 
            requiredStakeAmount + limitInfo.marginAmount);
        
        limitAmount = AmountLib.min(
            limitAmount, 
            limitInfo.hardLimitAmount);

        // effects
        targetInfo.limitAmount = limitAmount;
        targetInfo.lastUpdateIn = BlocknumberLib.current();

        // logging
        emit IStaking.LogStakingTargetLimitUpdated(
            targetNftId,
            targetInfo.limitAmount,
            limitInfo.hardLimitAmount,
            requiredStakeAmount,
            targetInfo.stakedAmount,
            lastUpdateIn);
    }

    //--- stake specific functions -------------------------------------//

    function createStake(
        NftId stakeNftId, 
        NftId targetNftId,
        address stakeOwner,
        Amount stakeAmount
    )
        external
        restricted()
        returns (Timestamp lockedUntil)
    {
        // checks
        IStaking.StakeInfo storage stakeInfo = _stakeInfo[stakeNftId];
        if (stakeInfo.lastUpdateIn.gtz()) {
            revert ErrorStakingStoreStakeBalanceAlreadyInitialized(stakeNftId);
        }

        IStaking.TargetInfo storage targetInfo = _getAndVerifyTarget(targetNftId);
        _checkMaxStakedAmount(targetNftId, targetInfo, stakeAmount);

        // effects
        stakeInfo.targetNftId = targetNftId;
        stakeInfo.stakedAmount = AmountLib.zero();
        stakeInfo.rewardAmount = AmountLib.zero();
        stakeInfo.lockedUntil = TimestampLib.current();
        _setStakeLastUpdatesToCurrent(stakeInfo);

        // logging for creation of empty stake
        emit IStaking.LogStakingStakeCreated(stakeNftId, stakeInfo.targetNftId, stakeInfo.stakedAmount, stakeInfo.lockedUntil, stakeOwner);

        // process stake amount
        _stake(stakeNftId, stakeInfo, targetInfo, targetInfo.lockingPeriod, stakeAmount);
    }


    function stake(
        NftId stakeNftId,
        bool updateRewards,
        bool restakeRewards,
        Seconds additionalLockingPeriod,
        Amount stakeAmount
    )
        external
        restricted()
    {
        // checks
        IStaking.StakeInfo storage stakeInfo = _getAndVerifyStake(stakeNftId);
        IStaking.TargetInfo storage targetInfo = _getAndVerifyTarget(stakeInfo.targetNftId);

        if (updateRewards) {
            _updateRewards(stakeNftId, stakeInfo, targetInfo);
        }

        if (restakeRewards) {
            _restakeRewards(stakeNftId, stakeInfo, targetInfo);
        }

        _stake(stakeNftId, stakeInfo, targetInfo, additionalLockingPeriod, stakeAmount);
    }


    function unstake(
        NftId stakeNftId,
        bool updateRewards,
        bool restakeRewards,
        Amount maxUnstakeAmount
    )
        external
        restricted()
        returns (Amount unstakedAmount)
    {
        // checks
        IStaking.StakeInfo storage stakeInfo = _getAndVerifyStake(stakeNftId);
        IStaking.TargetInfo storage targetInfo = _getAndVerifyTarget(stakeInfo.targetNftId);

        if (updateRewards) {
            _updateRewards(stakeNftId, stakeInfo, targetInfo);
        }

        if (restakeRewards) {
            _restakeRewards(stakeNftId, stakeInfo, targetInfo);
        }

        return _unstake(stakeNftId, stakeInfo, targetInfo, maxUnstakeAmount);
    }


    function updateRewards(NftId stakeNftId)
        external
        restricted()
    {
        // checks
        IStaking.StakeInfo storage stakeInfo = _getAndVerifyStake(stakeNftId);
        IStaking.TargetInfo storage targetInfo = _getAndVerifyTarget(stakeInfo.targetNftId);
        _updateRewards(stakeNftId, stakeInfo, targetInfo);
    }


    function restakeRewards(
        NftId stakeNftId,
        bool updateRewards
    )
        external
        restricted()
    {
        // checks
        IStaking.StakeInfo storage stakeInfo = _getAndVerifyStake(stakeNftId);
        IStaking.TargetInfo storage targetInfo = _getAndVerifyTarget(stakeInfo.targetNftId);

        if (updateRewards) {
            _updateRewards(stakeNftId, stakeInfo, targetInfo);
        }

        _restakeRewards(stakeNftId, stakeInfo, targetInfo);
    }


    function claimRewards(
        NftId stakeNftId,
        bool updateRewards,
        Amount maxClaimAmount
    )
        external
        restricted()
        returns (Amount claimedAmount)
    {
        // checks
        IStaking.StakeInfo storage stakeInfo = _getAndVerifyStake(stakeNftId);
        IStaking.TargetInfo storage targetInfo = _getAndVerifyTarget(stakeInfo.targetNftId);

        if (updateRewards) {
            _updateRewards(stakeNftId, stakeInfo, targetInfo);
        }

        claimedAmount = _claimRewards(stakeNftId, stakeInfo, targetInfo, maxClaimAmount);
    }

    //--- view functions -----------------------------------------------//

    function getStakingReader() external view returns (StakingReader stakingReader){
        return _reader;
    }

    function getTargetManager() external view returns (ITargetLimitHandler targetLimitHandler ){
        return _targetLimitHandler;
    }


    function exists(NftId stakeNftId) external view returns (bool) { 
        return _stakeInfo[stakeNftId].lastUpdateIn.gtz();
    }


    function getRequiredStakeBalance(NftId targetNftId)
        public
        view
        returns (Amount requiredStakeAmount)
    {
        address [] memory tokens = _targetToken[targetNftId];
        if (tokens.length == 0) {
            return AmountLib.zero();
        }

        requiredStakeAmount = AmountLib.zero();
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

            requiredStakeAmount = requiredStakeAmount + tvlAmount.multiplyWith(stakingRate);
        }
    }


    /// @dev Returns true iff current stake amount is still locked
    function isStakeLocked(NftId stakeNftId) public view returns (bool) { 
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


    /// @dev Returns the target limit infos for the specified target.
    function getLimitInfo(NftId targetNftId) external view returns (IStaking.LimitInfo memory limitInfo) { 
        return _limitInfo[targetNftId]; 
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

    //--- internal functions -----------------------------------------------//

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

        // target info
        IStaking.TargetInfo storage targetInfo = _targetInfo[targetNftId];
        targetInfo.stakedAmount = AmountLib.zero();
        targetInfo.rewardAmount = AmountLib.zero();
        targetInfo.reserveAmount = AmountLib.zero();
        targetInfo.limitAmount = AmountLib.max();

        targetInfo.objectType = objectType;
        targetInfo.lockingPeriod = lockingPeriod;
        targetInfo.rewardRate = rewardRate;
        targetInfo.chainId = ChainIdLib.fromNftId(targetNftId);
        targetInfo.lastUpdateIn = BlocknumberLib.current();

        // limit info
        IStaking.LimitInfo storage limitInfo = _limitInfo[targetNftId];
        limitInfo.marginAmount = AmountLib.zero();
        limitInfo.hardLimitAmount = AmountLib.max();
        limitInfo.lastUpdateIn = BlocknumberLib.current();

        // add new target to target set
        _targetNftIdSet.add(targetNftId);
    }


    function _spendRewardReserves(
        NftId targetNftId, 
        IStaking.TargetInfo storage targetInfo,
        Amount dipAmount
    )
        private
    {
        Blocknumber lastUpdateIn = _decreaseReserves(targetNftId, targetInfo, dipAmount);

        // logging
        emit IStaking.LogStakingRewardReservesSpent(
            targetNftId,
            dipAmount,
            targetInfo.reserveAmount,
            lastUpdateIn);
    }


    function _decreaseReserves(
        NftId targetNftId,
        IStaking.TargetInfo storage targetInfo, 
        Amount dipAmount
    )
        private
        returns ( Blocknumber lastUpdateIn)
    {
        lastUpdateIn = targetInfo.lastUpdateIn;

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
    }


    function _updateRewards(
        NftId stakeNftId,
        IStaking.StakeInfo storage stakeInfo,
        IStaking.TargetInfo storage targetInfo
    )
        internal
        returns (Amount rewardIncreaseAmount)
    {
        // return if reward rate is zero
        if (targetInfo.rewardRate.eqz()) {
            return rewardIncreaseAmount;
        }

        // get seconds since last update on stake
        Seconds duration = SecondsLib.toSeconds(
            block.timestamp - stakeInfo.lastUpdateAt.toInt());

        // return if duration is zero
        if (duration.eqz()) {
            return AmountLib.zero();
        }
        
        // calculate reward increase since
        rewardIncreaseAmount = StakingLib.calculateRewardAmount(
            targetInfo.rewardRate,
            duration,
            stakeInfo.stakedAmount);

        // update target + stake
        targetInfo.rewardAmount = targetInfo.rewardAmount + rewardIncreaseAmount;
        stakeInfo.rewardAmount = stakeInfo.rewardAmount + rewardIncreaseAmount;
        Blocknumber lastUpdateIn = _setLastUpdatesToCurrent(stakeInfo, targetInfo);

        // logging
        emit IStaking.LogStakingStakeRewardsUpdated(
            stakeNftId, 
            rewardIncreaseAmount, 
            stakeInfo.stakedAmount, 
            stakeInfo.rewardAmount, 
            stakeInfo.lockedUntil,
            lastUpdateIn);
    }


    function _restakeRewards(
        NftId stakeNftId,
        IStaking.StakeInfo storage stakeInfo,
        IStaking.TargetInfo storage targetInfo
    )
        internal
        returns (Amount restakeAmount)
    {
        restakeAmount = stakeInfo.rewardAmount;

        // return if reward amount is zero
        if (restakeAmount.eqz()) {
            return restakeAmount;
        }

        // check restaking amount does not exceed target max staked amount
        _checkMaxStakedAmount(stakeInfo.targetNftId, targetInfo, restakeAmount);

        // use up reserves for newly staked dips
        _spendRewardReserves(stakeInfo.targetNftId, targetInfo, restakeAmount);

        // update target + stake
        targetInfo.stakedAmount = targetInfo.stakedAmount + restakeAmount;
        targetInfo.rewardAmount = targetInfo.rewardAmount - restakeAmount;
        stakeInfo.stakedAmount = stakeInfo.stakedAmount + restakeAmount;
        stakeInfo.rewardAmount = AmountLib.zero();
        Blocknumber lastUpdateIn = _setLastUpdatesToCurrent(stakeInfo, targetInfo);

        // logging
        emit IStaking.LogStakingRewardsRestaked(
            stakeNftId,
            restakeAmount, 
            stakeInfo.stakedAmount, 
            AmountLib.zero(), 
            stakeInfo.lockedUntil,
            lastUpdateIn);
    }


    function _stake(
        NftId stakeNftId,
        IStaking.StakeInfo storage stakeInfo,
        IStaking.TargetInfo storage targetInfo,
        Seconds maxAdditionalLockingPeriod,
        Amount stakeAmount
    )
        internal
    {
        // return if reward amount is zero
        if (stakeAmount.eqz()) {
            return;
        }

        // check restaking amount does not exceed target max staked amount
        _checkMaxStakedAmount(stakeInfo.targetNftId, targetInfo, stakeAmount);

        // update target + stake
        targetInfo.stakedAmount = targetInfo.stakedAmount + stakeAmount;
        stakeInfo.stakedAmount = stakeInfo.stakedAmount + stakeAmount;

        // increase locked until if applicable
        Seconds additionalLockingPeriod = SecondsLib.min(maxAdditionalLockingPeriod, targetInfo.lockingPeriod);
        if (stakeAmount.gtz() && additionalLockingPeriod.gtz()) {
            stakeInfo.lockedUntil = stakeInfo.lockedUntil.addSeconds(additionalLockingPeriod);
        }

        Blocknumber lastUpdateIn = _setLastUpdatesToCurrent(stakeInfo, targetInfo);

        // logging
        emit IStaking.LogStakingStaked(
            stakeNftId,
            stakeAmount, 
            stakeInfo.stakedAmount, 
            stakeInfo.rewardAmount, 
            stakeInfo.lockedUntil,
            lastUpdateIn);
    }


    function _claimRewards(
        NftId stakeNftId,
        IStaking.StakeInfo storage stakeInfo,
        IStaking.TargetInfo storage targetInfo,
        Amount maxClaimAmount
    )
        internal
        returns (Amount claimAmount)
    {
        claimAmount = AmountLib.min(maxClaimAmount, stakeInfo.rewardAmount);

        // return if no rewards to claim
        if (claimAmount.eqz()) {
            return claimAmount;
        }

        // effects
        // use up reserves for claimed rewards
        _spendRewardReserves(stakeInfo.targetNftId, targetInfo, claimAmount);

        // update target + stake
        targetInfo.rewardAmount = targetInfo.rewardAmount - claimAmount;
        stakeInfo.rewardAmount = stakeInfo.rewardAmount - claimAmount;
        Blocknumber lastUpdateIn = _setLastUpdatesToCurrent(stakeInfo, targetInfo);

        // logging
        emit IStaking.LogStakingRewardsClaimed(
            stakeNftId,
            claimAmount, 
            stakeInfo.stakedAmount, 
            stakeInfo.rewardAmount, 
            stakeInfo.lockedUntil,
            lastUpdateIn);
    }


    function _unstake(
        NftId stakeNftId,
        IStaking.StakeInfo storage stakeInfo,
        IStaking.TargetInfo storage targetInfo,
        Amount maxUnstakeAmount
    )
        internal
        returns (Amount unstakedAmount)
    {
        unstakedAmount = AmountLib.min(maxUnstakeAmount, stakeInfo.stakedAmount);

        // return if no stakes to claim
        if (unstakedAmount.eqz()) {
            return unstakedAmount;
        }

        // check if stake is still locked
        if (isStakeLocked(stakeNftId)) {
            revert IStaking.ErrorStakingStakeLocked(stakeNftId, stakeInfo.lockedUntil);
        }

        // update target + stake
        targetInfo.stakedAmount = targetInfo.stakedAmount - unstakedAmount;
        stakeInfo.stakedAmount = stakeInfo.stakedAmount - unstakedAmount;
        Blocknumber lastUpdateIn = _setLastUpdatesToCurrent(stakeInfo, targetInfo);

        // logging
        emit IStaking.LogStakingUnstaked(
            stakeNftId,
            unstakedAmount, 
            stakeInfo.stakedAmount, 
            stakeInfo.rewardAmount, 
            stakeInfo.lockedUntil,
            lastUpdateIn);
    }


    function _setLastUpdatesToCurrent(
        IStaking.StakeInfo storage stakeInfo,
        IStaking.TargetInfo storage targetInfo
    )
        internal
        returns (Blocknumber lastUpdateIn)
    {
        targetInfo.lastUpdateIn = BlocknumberLib.current();
        lastUpdateIn = _setStakeLastUpdatesToCurrent(stakeInfo);
    }


    function _setStakeLastUpdatesToCurrent(
        IStaking.StakeInfo storage stakeInfo
    )
        internal
        returns (Blocknumber lastUpdateIn)
    {
        lastUpdateIn = stakeInfo.lastUpdateIn;
        stakeInfo.lastUpdateIn = BlocknumberLib.current();
        stakeInfo.lastUpdateAt = TimestampLib.current();
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
        if (targetInfo.stakedAmount + additionalstakedAmount > targetInfo.limitAmount) {
            revert IStaking.ErrorStakingTargetMaxStakedAmountExceeded(
                targetNftId,
                targetInfo.limitAmount,
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


    function _getAndVerifyLimit(
        NftId targetNftId
    )
        private
        view
        returns (
            IStaking.LimitInfo storage limitInfo
        )
    {
        limitInfo = _limitInfo[targetNftId];

        if (limitInfo.lastUpdateIn.eqz()) {
            revert ErrorStakingStoreLimitNotInitialized(targetNftId);
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
