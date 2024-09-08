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
import {ChainId} from "../type/ChainId.sol";
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
    function approveTokenHandler(IERC20Metadata token, Amount amount)
        public
        restricted()
        onlyOwner()
    {
        Amount oldApprovalAmount = _approveTokenHandler(token, amount);

        emit LogStakingTokenHandlerApproved(address(token), amount, oldApprovalAmount);
    }

    //--- token management --------------------------------------------------//

    /// @inheritdoc IStaking
    function addToken(
        ChainId chainId, 
        address token
    )
        external
        restricted() // token registry
    {
        _getStakingStorage()._store.addToken(chainId, token);

        emit LogStakingTokenAdded(chainId, token);
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
        _getStakingStorage()._store.setLockingPeriod(targetNftId, lockingPeriod);
        // emit LogStakingTargetLockingPeriodSet(targetNftId, oldLockingPeriod, lockingPeriod);
    }


    /// @inheritdoc IStaking
    function setRewardRate(NftId targetNftId, UFixed rewardRate)
        external
        virtual
        restricted()
        onlyTarget(targetNftId)
    {
        _getStakingStorage()._store.setRewardRate(targetNftId, rewardRate);
        // emit LogStakingTargetRewardRateSet(targetNftId, oldRewardRate, rewardRate);
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
        // update book keeping of reward reserves
        StakingStorage storage $ = _getStakingStorage();
        newBalance = $._store.increaseReserves(targetNftId, dipAmount);
    }


    /// @inheritdoc IStaking
    function withdrawRewardReserves(NftId targetNftId, Amount dipAmount)
        external
        virtual
        restricted()
        returns (Amount newBalance)
    {
        // update book keeping of reward reserves
        StakingStorage storage $ = _getStakingStorage();
        newBalance = $._store.decreaseReserves(targetNftId, dipAmount);
    }


    /// @inheritdoc IStaking
    function addTargetToken(NftId targetNftId, address token)
        external
        virtual
        restricted()
        onlyTarget(targetNftId)
    {
        _getStakingStorage()._store.addTargetToken(targetNftId, token);
        // TODO add logging
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

        // TODO add logging
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

        // TODO add logging
    }


    // TODO add to interface and implement
    function registerRemoteTarget(NftId targetNftId, TargetInfo memory targetInfo)
        external
        virtual
        restricted()
        onlyOwner // or CCIP
    {
        
    }

    // TODO add to interface and implement
    function updateRemoteTvl(NftId targetNftId, address token, Amount amount)
        external
        virtual
        restricted()
        onlyOwner // or CCIP
    {
        
    }

    //--- staking functions -------------------------------------------------//

    function createStake(
        NftId stakeNftId, 
        NftId targetNftId, 
        Amount stakeAmount
    )
        external
        virtual
        restricted() // only staking service
        returns (NftId)
    {
        StakingStorage storage $ = _getStakingStorage();
        $._store.createStake(stakeNftId, targetNftId, stakeAmount);

        emit LogStakingStakeRegistered(stakeNftId, targetNftId, stakeAmount);
    }


    function stake(
        NftId stakeNftId, 
        Amount stakeAmount
    )
        external
        virtual
        restricted() // only staking service
        onlyStake(stakeNftId)
        returns (Amount stakeBalance)
    {
        StakingStorage storage $ = _getStakingStorage();
        $._store.increaseStakeBalances(
            stakeNftId,
            stakeAmount,
            AmountLib.zero(),
            SecondsLib.zero()); // TODO define effect on locking period

        // TODO add logging
    }


    function unstake(NftId stakeNftId)
        external
        virtual
        restricted() // only staking service
        onlyStake(stakeNftId)
        returns (
            Amount unstakedAmount,
            Amount rewardsClaimedAmount
        )
    {
        StakingStorage storage $ = _getStakingStorage();

        (
            unstakedAmount,
            rewardsClaimedAmount
        ) = _unstakeAll($, stakeNftId);

        // TODO add logging
    }


    function _unstakeAll(StakingStorage storage $, NftId stakeNftId)
        internal
        virtual
        returns (
            Amount unstakedAmount,
            Amount rewardsClaimedAmount
        )
    {
        // additional checks (most checks are done prior to calling this function)
        if ($._store.isStakeLocked(stakeNftId)) {
            revert ErrorStakingStakeLocked(stakeNftId, $._store.getStakeInfo(stakeNftId).lockedUntil);
        }

        // update rewards since last update
        NftId targetNftId = _updateRewards($._reader, $._store, stakeNftId);

        (
            unstakedAmount, 
            rewardsClaimedAmount
        ) = $._store.decreaseStakeBalances(
            stakeNftId,
            AmountLib.max(), // unstake all stakes
            AmountLib.max()); // claim all rewards
    }


    function restake(
        NftId stakeNftId, 
        NftId newTargetNftId
    )
        external
        virtual
        restricted() // only staking service
        onlyStakeOwner(stakeNftId)
        returns (
            NftId newStakeNftId,
            Amount newStakedAmount
        )
    {
        StakingStorage storage $ = _getStakingStorage();
        address stakeOwner = msg.sender;

        (
            Amount unstakedAmount,
            Amount rewardsClaimedAmount
        ) = _unstakeAll($, stakeNftId);

        newStakeNftId = $._stakingService.createStakeObject(newTargetNftId, stakeOwner);
        newStakedAmount = unstakedAmount + rewardsClaimedAmount;
        $._store.createStake(newStakeNftId, newTargetNftId, newStakedAmount);

        emit LogStakingStakeRestaked(newStakeNftId, newTargetNftId, newStakedAmount, stakeOwner, stakeNftId);
    }

    function updateRewards(NftId stakeNftId)
        external
        virtual
        restricted() // only staking service
        onlyStake(stakeNftId)
    {
        StakingStorage storage $ = _getStakingStorage();
        _updateRewards($._reader, $._store, stakeNftId);
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
        NftId targetNftId = _updateRewards($._reader, $._store, stakeNftId);

        // unstake all available rewards
        (, rewardsClaimedAmount) = $._store.decreaseStakeBalances(
            stakeNftId,
            AmountLib.zero(), // unstake dip amount
            AmountLib.max()); // unstake reward amount

        // TODO add logging
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



    function _updateRewards(
        StakingReader reader,
        StakingStore store,
        NftId stakeNftId
    )
        internal
        virtual
        returns (NftId targetNftId)
    {
        UFixed rewardRate;

        (targetNftId, rewardRate) = reader.getTargetRewardRate(stakeNftId);
        (Amount rewardIncrement, ) = StakingLib.calculateRewardIncrease(
            reader, 
            stakeNftId,
            rewardRate);

        store.increaseStakeBalances(
            stakeNftId, 
            AmountLib.zero(),
            rewardIncrement,
            SecondsLib.zero());
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

        if (protocolInfo.lastUpdatedIn.eqz()) {
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
