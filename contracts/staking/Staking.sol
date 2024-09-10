// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IRegistry} from "../registry/IRegistry.sol";
import {IRelease} from "../registry/IRelease.sol";
import {IStaking} from "./IStaking.sol";
import {IStakingService} from "./IStakingService.sol";
import {IVersionable} from "../upgradeability/IVersionable.sol";

import {Amount, AmountLib} from "../type/Amount.sol";
import {Blocknumber} from "../type/Blocknumber.sol";
import {ChainId, ChainIdLib} from "../type/ChainId.sol";
import {Component} from "../shared/Component.sol";
import {IComponent} from "../shared/IComponent.sol";
import {IComponentService} from "../shared/IComponentService.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType, COMPONENT, STAKE, STAKING} from "../type/ObjectType.sol";
import {Seconds, SecondsLib} from "../type/Seconds.sol";
import {Registerable} from "../shared/Registerable.sol";
import {ReleaseRegistry} from "../registry/ReleaseRegistry.sol";
import {StakingLib} from "./StakingLib.sol";
import {StakingReader} from "./StakingReader.sol";
import {StakingStore} from "./StakingStore.sol";
import {TargetManagerLib} from "./TargetManagerLib.sol";
import {Timestamp} from "../type/Timestamp.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";
import {TokenHandlerDeployerLib} from "../shared/TokenHandlerDeployerLib.sol";
import {TokenRegistry} from "../registry/TokenRegistry.sol";
import {UFixed} from "../type/UFixed.sol";
import {Version, VersionLib, VersionPart, VersionPartLib} from "../type/Version.sol";
import {Versionable} from "../upgradeability/Versionable.sol";

contract Staking is 
    Component,
    Versionable,
    IStaking
{
    string public constant CONTRACT_NAME = "Staking";

    // keccak256(abi.encode(uint256(keccak256("gif-next.contracts.component.Staking.sol")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 public constant STAKING_LOCATION_V1 = 0xafe8d4462b2ed26a47154f4b8f6d1497d2f772496965791d25bd456e342b7f00;

    struct StakingStorage {
        TokenRegistry _tokenRegistry;
        TokenHandler _tokenHandler;
        IStakingService _stakingService;
        StakingStore _store;
        StakingReader _reader;
        NftId _protocolNftId;
    }


    modifier onlyStake(NftId stakeNftId) {
        if (!_getStakingStorage()._store.exists(stakeNftId)) {
            revert ErrorStakingNotStake(stakeNftId);
        }
        _;
    }


    modifier onlyStakeOwner(NftId stakeNftId) {
        IRegistry registry = getRegistry();

        // check nft is stake object
        if (!registry.isObjectType(stakeNftId, STAKE())) {
            revert ErrorStakingNotStake(stakeNftId);
        }

        // check caller is owner of stake object
        if (msg.sender != registry.ownerOf(stakeNftId)) {
            revert ErrorStakingNotStakeOwner(stakeNftId, registry.ownerOf(stakeNftId), msg.sender);
        }

        _;
    }


    modifier onlyTarget(NftId targetNftId) {
        if (!_getStakingStorage()._store.getTargetSet().exists(targetNftId)) {
            revert ErrorStakingNotTarget(targetNftId);
        }
        _;
    }

    //--- contract intitialization -------------------------------------------

    function initializeTokenHandler()
        external
        virtual
    {
        if (msg.sender != address(getRegistry())) {
            revert ErrorStakingNotRegistry(msg.sender);
        }

        StakingStorage storage $ = _getStakingStorage();
        address dipToken = _getStakingStorage()._tokenRegistry.getDipTokenAddress();
        $._tokenHandler = TokenHandlerDeployerLib.deployTokenHandler(
            address(getRegistry()),
            address(this),
            dipToken, 
            getRegistry().getAuthority());
    }

    //--- staking owner functions -------------------------------------------//

    // TODO also make sure that protocol rewards can be refilled and withdrawn

    /// @inheritdoc IStaking
    function setProtocolLockingPeriod(Seconds newLockingPeriod)
        external
        virtual
        restricted()
        onlyOwner()
    {
        NftId protocolNftId = getRegistry().getProtocolNftId();
        (
            Seconds oldLockingPeriod,
            Blocknumber lastUpdatedIn
        ) = _getStakingStorage()._store.setLockingPeriod(protocolNftId, newLockingPeriod);

        emit LogStakingProtocolLockingPeriodSet(protocolNftId, newLockingPeriod, oldLockingPeriod, lastUpdatedIn);
    }


    /// @inheritdoc IStaking
    function setProtocolRewardRate(UFixed newRewardRate)
        external
        virtual
        restricted()
        onlyOwner()
    {
        NftId protocolNftId = getRegistry().getProtocolNftId();        
        (
            UFixed oldRewardRate,
            Blocknumber lastUpdatedIn
        ) = _getStakingStorage()._store.setRewardRate(protocolNftId, newRewardRate);
        emit LogStakingProtocolRewardRateSet(protocolNftId, newRewardRate, oldRewardRate, lastUpdatedIn);
    }


    /// @inheritdoc IStaking
    function setStakingRate(
        ChainId chainId, 
        address token, 
        UFixed stakingRate
    )
        external
        virtual
        restricted()
        onlyOwner()
    {
        (
            UFixed oldStakingRate,
            Blocknumber lastUpdateIn
        )  = _getStakingStorage()._store.setStakingRate(chainId, token, stakingRate);

        emit LogStakingStakingRateSet(chainId, token, stakingRate, oldStakingRate, lastUpdateIn);
    }


    /// @inheritdoc IStaking
    function setStakingService(VersionPart release)
        external
        virtual
        restricted()
        onlyOwner()
    {
        // checks
        if (!ReleaseRegistry(getRegistry().getReleaseRegistryAddress()).isActiveRelease(release)) {
            revert ErrorStakingReleaseNotActive(release);
        }

        address stakingServiceAddress = getRegistry().getServiceAddress(STAKING(), release);
        if (stakingServiceAddress == address(0)) {
            revert ErrorStakingServiceNotFound(release);
        }

        // effects
        address oldStakingService = address(_getStakingStorage()._stakingService);
        _getStakingStorage()._stakingService = IStakingService(stakingServiceAddress);

        emit LogStakingStakingServiceSet(stakingServiceAddress, release, oldStakingService);
    }


    /// @inheritdoc IStaking
    function setStakingReader(StakingReader stakingReader)
        external
        virtual
        restricted()
        onlyOwner()
    {
        if(stakingReader.getStaking() != IStaking(this)) {
            revert ErrorStakingStakingReaderStakingMismatch(address(stakingReader.getStaking()));
        }

        address oldReader = address(_getStakingStorage()._reader);
        _getStakingStorage()._reader = stakingReader;

        emit LogStakingStakingReaderSet(address(stakingReader), oldReader);
    }


    /// @inheritdoc IStaking
    function addToken(
        ChainId chainId, 
        address token
    )
        external
        virtual
        restricted()
        onlyOwner()
    {
        _addToken(
            _getStakingStorage(), chainId, token);
    }


    /// @inheritdoc IStaking
    function approveTokenHandler(IERC20Metadata token, Amount amount)
        public
        virtual
        restricted()
        onlyOwner()
    {
        Amount oldApprovalAmount = _approveTokenHandler(token, amount);

        emit LogStakingTokenHandlerApproved(address(token), amount, oldApprovalAmount);
    }

    //--- target management -------------------------------------------------//

    /// @inheritdoc IStaking
    function registerTarget(
        NftId targetNftId,
        ObjectType expectedObjectType,
        Seconds initialLockingPeriod,
        UFixed initialRewardRate
    )
        external
        virtual
        restricted() // staking service
    {
        // checks done by staking store
        _getStakingStorage()._store.createTarget(
            targetNftId,
            expectedObjectType,
            initialLockingPeriod,
            initialRewardRate);

        emit LogStakingTargetCreated(targetNftId, expectedObjectType, initialLockingPeriod, initialRewardRate, AmountLib.max());
    }


    /// @inheritdoc IStaking
    function setLockingPeriod(
        NftId targetNftId, 
        Seconds lockingPeriod
    )
        external
        virtual
        restricted()
        onlyTarget(targetNftId)
    {
        (Seconds oldLockingPeriod, ) = _getStakingStorage()._store.setLockingPeriod(targetNftId, lockingPeriod);
        emit LogStakingTargetLockingPeriodSet(targetNftId, lockingPeriod, oldLockingPeriod);
    }


    /// @inheritdoc IStaking
    function setRewardRate(NftId targetNftId, UFixed rewardRate)
        external
        virtual
        restricted()
        onlyTarget(targetNftId)
    {
        (UFixed oldRewardRate,) = _getStakingStorage()._store.setRewardRate(targetNftId, rewardRate);
        emit LogStakingTargetRewardRateSet(targetNftId, rewardRate, oldRewardRate);
    }


    /// @inheritdoc IStaking
    function setMaxStakedAmount(NftId targetNftId, Amount maxStakedAmount)
        external
        virtual
        restricted()
        onlyTarget(targetNftId)
    {
        _getStakingStorage()._store.setMaxStakedAmount(targetNftId, maxStakedAmount);
        // emit LogStakingTargetMaxStakedAmountSet(targetNftId, maxStakedAmount);
    }


    /// @inheritdoc IStaking
    function refillRewardReserves(NftId targetNftId, Amount dipAmount)
        external
        virtual
        restricted()
        returns (Amount newBalance)
    {
        // checks + effects
        StakingStorage storage $ = _getStakingStorage();
        newBalance = $._store.refillRewardReserves(targetNftId, dipAmount);

        // interactions
        // collect DIP token from target owner
        if (dipAmount.gtz()) {
            address targetOwner = getRegistry().ownerOf(targetNftId);
            $._stakingService.pullDipToken(dipAmount, targetOwner);
        }
    }


    /// @inheritdoc IStaking
    function withdrawRewardReserves(NftId targetNftId, Amount dipAmount)
        external
        virtual
        restricted()
        returns (Amount newBalance)
    {
        // checks + effects
        StakingStorage storage $ = _getStakingStorage();
        newBalance = $._store.withdrawRewardReserves(targetNftId, dipAmount);

        // interactions
        // transfer DIP token to target owner
        if (dipAmount.gtz()) {
            address targetOwner = getRegistry().ownerOf(targetNftId);
            $._stakingService.pushDipToken(dipAmount, targetOwner);
        }
    }


    /// @inheritdoc IStaking
    function addTargetToken(NftId targetNftId, address token)
        external
        virtual
        restricted()
        onlyTarget(targetNftId)
    {
        StakingStorage storage $ = _getStakingStorage();
        ChainId chainId = ChainIdLib.fromNftId(targetNftId);
        _addToken($, chainId, token);
        
        $._store.addTargetToken(targetNftId, token);

        emit LogStakingTargetTokenAdded(targetNftId, chainId, token);
    }


    /// @inheritdoc IStaking
    function increaseTotalValueLocked(NftId targetNftId, address token, Amount amount)
        external
        virtual
        restricted() // only pool service
        returns (Amount newBalance)
    {
        StakingStorage storage $ = _getStakingStorage();
        newBalance = $._store.increaseTotalValueLocked(targetNftId, token, amount);

        emit LogStakingTotalValueLockedIncreased(targetNftId, token, amount, newBalance);
    }


    /// @inheritdoc IStaking
    function decreaseTotalValueLocked(NftId targetNftId, address token, Amount amount)
        external
        virtual
        restricted() // only pool service
        returns (Amount newBalance)
    {
        StakingStorage storage $ = _getStakingStorage();
        newBalance = $._store.decreaseTotalValueLocked(targetNftId, token, amount);

        emit LogStakingTotalValueLockedDecreased(targetNftId, token, amount, newBalance);
    }


    // TODO add to interface and implement
    /// inheritdoc IStaking
    function registerRemoteTarget(NftId targetNftId, TargetInfo memory targetInfo)
        external
        virtual
        restricted()
        onlyOwner // or CCIP
    {
        
    }

    // TODO add to interface and implement
    /// @inheritdoc IStaking
    function updateRemoteTvl(NftId targetNftId, address token, Amount amount)
        external
        virtual
        restricted()
        onlyOwner // or CCIP
    {
        
    }

    //--- staking functions -------------------------------------------------//

    /// @inheritdoc IStaking
    function createStake(
        NftId targetNftId, 
        Amount stakeAmount,
        address stakeOwner
    )
        external
        virtual
        restricted()
        onlyTarget(targetNftId)
        returns (NftId stakeNftId)
    {
        StakingStorage storage $ = _getStakingStorage();

        // effects (includes further checks in service)
        stakeNftId = $._stakingService.createStakeObject(targetNftId, stakeOwner);
        Timestamp lockedUntil = $._store.createStake(stakeNftId, targetNftId, stakeAmount);

        emit LogStakingStakeCreated(stakeNftId, targetNftId, stakeAmount, lockedUntil, stakeOwner);

        // interactions
        $._stakingService.pullDipToken(stakeAmount, stakeOwner);
    }


    function _updateRewards(
        StakingStorage storage $, 
        NftId stakeNftId
    )
        internal 
        virtual 
        returns (
            Amount rewardIncreaseAmount,
            Seconds targetLockingPeriod,
            Amount stakeBalance,
            Amount rewardBalance,
            Timestamp lockedUntil
        )
    {
        (
            rewardIncreaseAmount,
            targetLockingPeriod,
            stakeBalance,
            rewardBalance,
            lockedUntil
        ) = $._store.updateRewards(stakeNftId);

        if (rewardIncreaseAmount.gtz()) {
            emit LogStakingStakeRewardsUpdated(stakeNftId, rewardIncreaseAmount, stakeBalance, rewardBalance, lockedUntil);
        }
    }


    /// @inheritdoc IStaking
    function stake(
        NftId stakeNftId, 
        Amount stakeAmount
    )
        external
        virtual
        restricted()
        onlyStakeOwner(stakeNftId)
        returns (Amount newStakeBalance)
    {
        StakingStorage storage $ = _getStakingStorage();

        // update rewards for stake (add rewards since last update)
        (
            Amount rewardIncreaseAmount,
            Seconds targetLockingPeriod,
            Amount stakeBalance,
            Amount rewardBalance,
            Timestamp lockedUntil
        ) = _updateRewards($, stakeNftId);

        // no additional locking duration if no additional stakes
        if (stakeAmount.eqz()) {
            targetLockingPeriod = SecondsLib.zero();
        }

        // increase stakes and restake rewards
        bool restakeRewards = true;
        if (restakeRewards && rewardBalance.gtz()) {
            emit LogStakingRewardsRestaked(stakeNftId, rewardBalance + rewardBalance, stakeBalance, AmountLib.zero(), lockedUntil);
        } 

        (
            stakeBalance,
            rewardBalance,
            lockedUntil
        ) = $._store.increaseStakes(
            stakeNftId,
            stakeAmount,
            targetLockingPeriod,
            restakeRewards); 

        // collect staked DIP token by staking service
        if (stakeAmount.gtz()) {
            emit LogStakingStaked(stakeNftId, stakeAmount, stakeBalance, rewardBalance, lockedUntil);

            // interactions
            address stakeOwner = getRegistry().ownerOf(stakeNftId);
            $._stakingService.pullDipToken(stakeAmount, stakeOwner);
        }
    }


    /// @inheritdoc IStaking
    function unstake(NftId stakeNftId)
        external
        virtual
        restricted() // only staking service
        onlyStakeOwner(stakeNftId)
        returns (
            Amount unstakedAmount,
            Amount rewardsClaimedAmount
        )
    {
        StakingStorage storage $ = _getStakingStorage();
        bool restakeRewards = true;
        Timestamp lockedUntil;

        (
            unstakedAmount,
            rewardsClaimedAmount,
            lockedUntil
        ) = _unstakeAll(
            $, 
            stakeNftId,
            restakeRewards); // restake rewards

        // collect staked DIP token by staking service
        Amount collectedAmount = unstakedAmount + rewardsClaimedAmount;
        if (collectedAmount.gtz()) {

            // interactions
            address stakeOwner = getRegistry().ownerOf(stakeNftId);
            $._stakingService.pushDipToken(collectedAmount, stakeOwner);
        }
    }


    /// @inheritdoc IStaking
    function restake(
        NftId stakeNftId, 
        NftId newTargetNftId
    )
        external
        virtual
        restricted() // only staking service
        onlyStakeOwner(stakeNftId)
        onlyTarget(newTargetNftId)
        returns (
            NftId newStakeNftId,
            Amount newStakedAmount
        )
    {
        StakingStorage storage $ = _getStakingStorage();
        address stakeOwner = msg.sender;

        (
            Amount unstakedAmount,
            Amount rewardsClaimedAmount,
        ) = _unstakeAll($, stakeNftId, true); // restake rewards

        newStakeNftId = $._stakingService.createStakeObject(newTargetNftId, stakeOwner);
        newStakedAmount = unstakedAmount + rewardsClaimedAmount;
        $._store.createStake(
            newStakeNftId, 
            newTargetNftId, 
            newStakedAmount);

        emit LogStakingStakeRestaked(newStakeNftId, newTargetNftId, newStakedAmount, stakeOwner, stakeNftId);
    }


    function updateRewards(NftId stakeNftId)
        external
        virtual
        restricted() // only staking service
        onlyStake(stakeNftId)
        returns (Amount newRewardAmount)
    {
        _updateRewards(
            _getStakingStorage(), 
            stakeNftId);
    }


    function claimRewards(NftId stakeNftId)
        external
        virtual
        restricted() // only staking service
        onlyStake(stakeNftId)
        returns (
            Amount rewardsClaimedAmount
        )
    {
        StakingStorage storage $ = _getStakingStorage();

        // update rewards since last update
        _updateRewards($, stakeNftId);

        (
            Amount restakedRewardAmount,
            Amount unstakedAmount,
            Amount claimedAmount,
            Amount stakedBalance,
            Amount rewardBalance,
            Timestamp lockedUntil
        ) = $._store.decreaseStakes(
            stakeNftId,
            AmountLib.zero(), // unstake dip amount
            AmountLib.max(), // unstake reward amount
            false); // restake rewards

        // collect staked DIP token by staking service
        if (claimedAmount.gtz()) {
            emit LogStakingRewardsClaimed(stakeNftId, claimedAmount, stakedBalance, rewardBalance, lockedUntil);

            // interactions
            address stakeOwner = getRegistry().ownerOf(stakeNftId);
            $._stakingService.pushDipToken(claimedAmount, stakeOwner);
        }
    }


    //--- view functions ----------------------------------------------------//

    function getStakingReader() public virtual view returns (StakingReader reader) {
        return _getStakingStorage()._reader;
    }

    function getStakingStore() external virtual view returns (StakingStore stakingStore) {
        return _getStakingStorage()._store;
    }

    function getTokenRegistryAddress() external virtual view returns (address tokenRegistry) {
        return address(_getStakingStorage()._tokenRegistry);
    }

    function getTokenHandler() public virtual override(Component, IComponent) view returns (TokenHandler tokenHandler) {
        return _getStakingStorage()._tokenHandler;
    }

    // from IRegisterable
    function getRelease()
        public 
        pure 
        virtual override (IRelease, Registerable)
        returns(VersionPart)
    {
        return VersionPartLib.toVersionPart(3);
    }

    // from IVersionable
    function getVersion()
        public 
        pure 
        virtual override (Component, IVersionable, Versionable)
        returns(Version)
    {
        return VersionLib.toVersion(3,0,0);
    }

    //--- internal functions ------------------------------------------------//

    function _unstakeAll(
        StakingStorage storage $, 
        NftId stakeNftId,
        bool restakeRewards
    )
        internal
        virtual
        returns (
            Amount unstakedAmount,
            Amount claimedAmount,
            Timestamp lockedUntil
        )
    {
        // additional checks (most checks are done prior to calling this function)
        if ($._store.isStakeLocked(stakeNftId)) {
            revert ErrorStakingStakeLocked(stakeNftId, $._store.getStakeInfo(stakeNftId).lockedUntil);
        }

        // update rewards since last update
        (,,,, lockedUntil) = _updateRewards($, stakeNftId);
        Amount restakedRewardAmount;
        Amount stakeBalance;
        Amount rewardBalance;

        (
            restakedRewardAmount,
            unstakedAmount,
            claimedAmount,
            stakeBalance,
            rewardBalance,
        ) = $._store.decreaseStakes(
            stakeNftId,
            AmountLib.max(), // unstake all stakes
            AmountLib.max(), // claim all rewards
            restakeRewards);

        if (restakedRewardAmount.gtz()) {
            emit LogStakingRewardsRestaked(stakeNftId, restakedRewardAmount, stakeBalance + unstakedAmount, rewardBalance + claimedAmount, lockedUntil);
        }

        if (unstakedAmount.gtz() || claimedAmount.gtz()) {
            emit LogStakingUnstaked(stakeNftId, unstakedAmount + claimedAmount, stakeBalance, rewardBalance, lockedUntil);
        }
    }


    function _calculateRewardIncrease(
        UFixed targetRewardRate,
        StakeInfo memory stakeInfo
    )
        internal
        virtual
        returns (Amount rewardIncreaseAmount)
    {
        Seconds duration = SecondsLib.toSeconds(
            block.timestamp - stakeInfo.lastUpdateAt.toInt());
        
        return StakingLib.calculateRewardAmount(
            targetRewardRate,
            duration,
            stakeInfo.stakedAmount);
    }


    function _addToken(
        StakingStorage storage $,
        ChainId chainId, 
        address token
    )
        internal
        virtual
    {
        if ($._store.getTokenInfo(chainId, token).lastUpdateIn.eqz()) {
            $._store.addToken(chainId, token);

            emit LogStakingTokenAdded(chainId, token);
        }
    }


    function _approveTokenHandler(
        IERC20Metadata token, 
        Amount amount)
        internal
        virtual override
        returns (Amount oldAllowanceAmount)
    {
        oldAllowanceAmount = AmountLib.toAmount(
            token.allowance(address(this), address(_getStakingStorage()._tokenHandler)));

        // staking token handler approval via its own implementation in staking service
        IComponentService(_getServiceAddress(STAKING())).approveTokenHandler(
            token, 
            amount);
    }


    /// @dev top level initializer (upgradable contract)
    function _initialize(
        address owner, 
        bytes memory data
    )
        internal
        virtual override
        onlyInitializing()
    {
        (
            address registryAddress,
            address tokenRegistryAddress,
            address stakingStoreAddress
        ) = abi.decode(data, (address, address, address));

        // wiring to external contracts
        IRegistry registry = IRegistry(registryAddress);
        StakingStorage storage $ = _getStakingStorage();
        $._protocolNftId = registry.getProtocolNftId();
        $._store = StakingStore(stakingStoreAddress);
        $._reader = StakingStore(stakingStoreAddress).getStakingReader();
        $._tokenRegistry = TokenRegistry(tokenRegistryAddress);
        // staking service has to be set via setStakingService after deploying the first GIF release

        __Component_init(
            registry.getAuthority(),
            address(registry), 
            registry.getNftId(), // parent nft id
            CONTRACT_NAME,
            STAKING(), 
            false, // is interceptor
            owner, 
            "", // registry data
            ""); // component data

        // Protocol target is created in the StakingStore constructor.
        // This allows setting up the protocol target before the full 
        // staking authorization setup is in place.
        _checkAndLogProtocolTargetCreation();

        _registerInterface(type(IStaking).interfaceId);
    }


    function _checkAndLogProtocolTargetCreation()
        internal 
        virtual
    {
        StakingStorage storage $ = _getStakingStorage();
        TargetInfo memory protocolInfo = $._store.getTargetInfo($._protocolNftId);

        if (protocolInfo.lastUpdateIn.eqz()) {
            revert ErrorStakingTargetNotFound($._protocolNftId);
        }

        emit LogStakingTargetCreated($._protocolNftId, protocolInfo.objectType, protocolInfo.lockingPeriod, protocolInfo.rewardRate, protocolInfo.maxStakedAmount);
    }


    function _getStakingStorage() private pure returns (StakingStorage storage $) {
        assembly {
            $.slot := STAKING_LOCATION_V1
        }
    }
}
