// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IRegistry} from "../registry/IRegistry.sol";
import {IRelease} from "../registry/IRelease.sol";
import {IStaking} from "./IStaking.sol";
import {IStakingService} from "./IStakingService.sol";
import {ITargetLimitHandler} from "./ITargetLimitHandler.sol";
import {IVersionable} from "../upgradeability/IVersionable.sol";

import {Amount, AmountLib} from "../type/Amount.sol";
import {Blocknumber} from "../type/Blocknumber.sol";
import {ChainId, ChainIdLib} from "../type/ChainId.sol";
import {Component} from "../shared/Component.sol";
import {IComponent} from "../shared/IComponent.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType, PROTOCOL, INSTANCE, STAKE, STAKING, TARGET} from "../type/ObjectType.sol";
import {Seconds, SecondsLib} from "../type/Seconds.sol";
import {Registerable} from "../shared/Registerable.sol";
import {StakingLib} from "./StakingLib.sol";
import {StakingReader} from "./StakingReader.sol";
import {StakingStore} from "./StakingStore.sol";
import {TargetHandler} from "./TargetHandler.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";
import {TokenHandlerDeployerLib} from "../shared/TokenHandlerDeployerLib.sol";
import {TokenRegistry} from "../registry/TokenRegistry.sol";
import {UFixed, UFixedLib} from "../type/UFixed.sol";
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
        TargetHandler _targetHandler;
        StakingStore _store;
        StakingReader _reader;
        NftId _protocolNftId;
    }


    modifier onlyStakeOwner(NftId stakeNftId) {
        _checkTypeAndOwner(stakeNftId, STAKE(), true);
        _;
    }


    modifier onlyTarget(NftId targetNftId) {
        _checkTypeAndOwner(targetNftId, TARGET(), false);
        _;
    }


    modifier onlyTargetOwner(NftId targetNftId) {
        _checkTypeAndOwner(targetNftId, TARGET(), true);
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

    function setSupportInfo(
        ObjectType targetType,
        bool isSupported,
        bool allowNewTargets,
        bool allowCrossChain,
        Amount minStakingAmount,
        Amount maxStakingAmount,
        Seconds minLockingPeriod,
        Seconds maxLockingPeriod,
        UFixed minRewardRate,
        UFixed maxRewardRate
    )
        external
        virtual
        restricted()
        onlyOwner()
    {
        StakingStorage storage $ = _getStakingStorage();
        $._store.setSupportInfo(
            targetType,
            isSupported,
            allowNewTargets,
            allowCrossChain,
            minStakingAmount,
            maxStakingAmount,
            minLockingPeriod,
            maxLockingPeriod,
            minRewardRate,
            maxRewardRate);
    }


    /// @inheritdoc IStaking
    function setUpdateTriggers(
        uint16 tvlUpdatesTrigger,
        UFixed minTvlRatioTrigger
    )
        external
        restricted()
    {
        StakingStorage storage $ = _getStakingStorage();
        $._targetHandler.setUpdateTriggers(tvlUpdatesTrigger, minTvlRatioTrigger);
    }


    /// @inheritdoc IStaking
    function setProtocolLockingPeriod(Seconds newLockingPeriod)
        external
        virtual
        restricted()
        onlyOwner()
    {
        StakingStorage storage $ = _getStakingStorage();
        $._store.setLockingPeriod($._protocolNftId, newLockingPeriod);
    }


    /// @inheritdoc IStaking
    function setProtocolRewardRate(UFixed newRewardRate)
        external
        virtual
        restricted()
        onlyOwner()
    {
        StakingStorage storage $ = _getStakingStorage();
        $._store.setRewardRate($._protocolNftId, newRewardRate);
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
        // effects
        StakingStorage storage $ = _getStakingStorage();
        address oldStakingService = address($._stakingService);
        $._stakingService = StakingLib.checkAndGetStakingService(getRegistry(), release);

        emit LogStakingStakingServiceSet(address($._stakingService), release, oldStakingService);
    }


    /// @inheritdoc IStaking
    function setStakingReader(address reader)
        external
        virtual
        restricted()
        onlyOwner()
    {
        StakingReader stakingReader = StakingReader(reader);

        if(stakingReader.getStaking() != IStaking(this)) {
            revert ErrorStakingStakingReaderStakingMismatch(address(stakingReader.getStaking()));
        }

        StakingStorage storage $ = _getStakingStorage();
        $._reader = stakingReader;
        $._store.setStakingReader(reader);
    }


    // TODO move to TargetHandler?
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
        StakingStorage storage $ = _getStakingStorage();
        Amount oldAllowanceAmount = AmountLib.toAmount(
            token.allowance(
                address(this), 
                address($._tokenHandler)));

        // staking token handler approval via its own implementation in staking service
        $._stakingService.approveTokenHandler(
            token, 
            amount);

        emit LogStakingTokenHandlerApproved(address(token), amount, oldAllowanceAmount);
    }

    //--- target management -------------------------------------------------//


    /// @inheritdoc IStaking
    function refillRewardReserves(NftId targetNftId, Amount dipAmount)
        external
        virtual
        restricted()
        onlyTarget(targetNftId)
        returns (Amount newBalance)
    {
        address transferFrom = msg.sender;
        _refillRewardReserves(targetNftId, dipAmount, transferFrom);
    }


    /// @inheritdoc IStaking
    function withdrawRewardReserves(NftId targetNftId, Amount dipAmount)
        external
        virtual
        restricted()
        onlyTarget(targetNftId)
        returns (Amount newBalance)
    {
        address transferTo;
    
        // case 1: protocol target: staking owner is recipient
        if (targetNftId == getRegistry().getProtocolNftId()) {
            // verify that the caller is the staking owner
            transferTo = getOwner();
            if (msg.sender != transferTo) {
                revert ErrorStakingNotStakingOwner();
            }

        // case 2: same chain target: target owner is recipient
        } else if (ChainIdLib.isCurrentChain(targetNftId)) {
            // verify that the caller is the target owner
            transferTo = getRegistry().ownerOf(targetNftId);
            if (msg.sender != transferTo) {
                revert ErrorStakingNotNftOwner(targetNftId);
            }

        // case 3: cross-chain target: TODO decide how to handle and implement
        } else {
            revert("Cross-chain target not supported");
        }

        newBalance = _withdrawRewardReserves(targetNftId, dipAmount, transferTo);
    }


    /// @inheritdoc IStaking
    function refillRewardReservesByService(NftId targetNftId, Amount dipAmount, address transferFrom)
        external
        virtual
        restricted()
        onlyTarget(targetNftId)
        returns (Amount newBalance)
    {
        _refillRewardReserves(targetNftId, dipAmount, transferFrom);
    }


    /// @inheritdoc IStaking
    function withdrawRewardReservesByService(NftId targetNftId, Amount dipAmount, address transferTo)
        external
        virtual
        restricted()
        onlyTarget(targetNftId)
        returns (Amount newBalance)
    {
        // check that service does not withdraw from protocol target 
        if (targetNftId == getRegistry().getProtocolNftId()) {
            revert ErrorStakingTargetTypeNotSupported(targetNftId, PROTOCOL());
        }

        // default: on-chain target owner is recipient
        address targetOwner = getRegistry().ownerOf(targetNftId);
        return _withdrawRewardReserves(targetNftId, dipAmount, targetOwner);
    }


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
    }


    /// @inheritdoc IStaking
    function setRewardRate(NftId targetNftId, UFixed rewardRate)
        external
        virtual
        restricted()
        onlyTarget(targetNftId)
    {
        _getStakingStorage()._store.setRewardRate(targetNftId, rewardRate);
    }


    // TODO refactor into setTargetLimits
    /// @inheritdoc IStaking
    function setMaxStakedAmount(NftId targetNftId, Amount stakeLimitAmount)
        external
        virtual
        restricted()
        onlyTarget(targetNftId)
    {
        StakingStorage storage $ = _getStakingStorage();
        $._store.setMaxStakedAmount(targetNftId, stakeLimitAmount);
    }


    /// @inheritdoc IStaking
    function setTargetLimits(NftId targetNftId, Amount marginAmount, Amount limitAmount)
        external
        virtual
        restricted()
        onlyTargetOwner(targetNftId)
    {
        StakingStorage storage $ = _getStakingStorage();
        $._store.setTargetLimits(targetNftId, marginAmount, limitAmount);
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

        if (! $._store.hasTokenInfo(chainId, token)) {
            _addToken($, chainId, token);
        }
        
        $._store.addTargetToken(targetNftId, token);

        // TODO move logging to store
        emit LogStakingTargetTokenAdded(targetNftId, chainId, token);
    }


    /// @inheritdoc IStaking
    function increaseTotalValueLocked(NftId targetNftId, address token, Amount amount)
        external
        virtual
        restricted() // only pool service
    {
        StakingStorage storage $ = _getStakingStorage();
        $._store.increaseTotalValueLocked(targetNftId, token, amount);
    }


    /// @inheritdoc IStaking
    function decreaseTotalValueLocked(NftId targetNftId, address token, Amount amount)
        external
        virtual
        restricted() // only pool service
    {
        StakingStorage storage $ = _getStakingStorage();
        $._store.decreaseTotalValueLocked(targetNftId, token, amount);
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

    //--- public functions --------------------------------------------------//

    /// @inheritdoc IStaking
    function updateTargetLimit(NftId targetNftId)
        external
        restricted()
    {
        StakingStorage storage $ = _getStakingStorage();
        $._store.updateTargetLimit(targetNftId);
    }


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
        // effects (includes further checks in service)
        StakingStorage storage $ = _getStakingStorage();
        stakeNftId = $._stakingService.createStakeObject(targetNftId, stakeOwner);
        $._store.createStake(stakeNftId, targetNftId, stakeOwner, stakeAmount);

        // interactions
        if (stakeAmount.gtz()) {
            $._stakingService.pullDipToken(stakeAmount, stakeOwner);
        }
    }

    //--- stake owner functions ---------------------------------------------//


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
        $._store.stake(
            stakeNftId, 
            true, // update rewards
            true, // restake rewards
            SecondsLib.max(), // max additional locking duration
            stakeAmount);

        // collect staked DIP token via staking service
        if (stakeAmount.gtz()) {
            address stakeOwner = getRegistry().ownerOf(stakeNftId);
            $._stakingService.pullDipToken(stakeAmount, stakeOwner);
        }
    }


    /// @inheritdoc IStaking
    function unstake(NftId stakeNftId)
        external
        virtual
        restricted()
        onlyStakeOwner(stakeNftId)
        returns (Amount unstakedAmount)
    {
        StakingStorage storage $ = _getStakingStorage();
        unstakedAmount = $._store.unstake(
            stakeNftId, 
            true, // update rewards
            true, // restake rewards
            AmountLib.max()); // unstake up to this amount

        // transfer unstaked DIP token via staking service
        if (unstakedAmount.gtz()) {
            address stakeOwner = getRegistry().ownerOf(stakeNftId);
            $._stakingService.pushDipToken(unstakedAmount, stakeOwner);
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

        // step 1: unstake as much as possible
        newStakedAmount = $._store.unstake(
            stakeNftId, 
            true, // update rewards
            true, // restake rewards
            AmountLib.max()); // unstake up to this amount

        // step 2: create new stake with full unstaked amount
        address stakeOwner = getRegistry().ownerOf(stakeNftId);
        newStakeNftId = $._stakingService.createStakeObject(newTargetNftId, stakeOwner);
        $._store.createStake(newStakeNftId, newTargetNftId, stakeOwner, newStakedAmount);

        // logging
        emit LogStakingStakeRestaked(newStakeNftId, newTargetNftId, newStakedAmount, stakeOwner, stakeNftId);
    }


    function updateRewards(NftId stakeNftId)
        external
        virtual
        restricted()
        onlyStakeOwner(stakeNftId)
        returns (Amount newRewardAmount)
    {
        StakingStorage storage $ = _getStakingStorage();
        $._store.updateRewards(stakeNftId);
    }


    function claimRewards(NftId stakeNftId)
        external
        virtual
        restricted()
        onlyStakeOwner(stakeNftId)
        returns (
            Amount claimedAmount
        )
    {
        StakingStorage storage $ = _getStakingStorage();
        claimedAmount = $._store.claimRewards(
            stakeNftId, 
            true, 
            AmountLib.max());

        // collect staked DIP token by staking service
        if (claimedAmount.gtz()) {
            // interactions
            address stakeOwner = getRegistry().ownerOf(stakeNftId);
            $._stakingService.pushDipToken(claimedAmount, stakeOwner);
        }
    }


    //--- view functions ----------------------------------------------------//

    function getStakingReader() public virtual view returns (StakingReader reader) {
        return _getStakingStorage()._reader;
    }

    function getTargetHandler() external virtual view returns (TargetHandler targetHandler) {
        return _getStakingStorage()._targetHandler;
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


    function _refillRewardReserves(NftId targetNftId, Amount dipAmount, address transferFrom)
        internal
        virtual
        returns (Amount newBalance)
    {
        // checks + effects
        StakingStorage storage $ = _getStakingStorage();
        newBalance = $._store.refillRewardReserves(targetNftId, dipAmount);

        // interactions
        // collect DIP token from target owner
        if (dipAmount.gtz()) {
            $._stakingService.pullDipToken(dipAmount, transferFrom);
        }
    }


    function _withdrawRewardReserves(NftId targetNftId, Amount dipAmount, address transferTo)
        internal
        virtual
        returns (Amount newBalance)
    {
        // checks + effects
        StakingStorage storage $ = _getStakingStorage();
        newBalance = $._store.withdrawRewardReserves(targetNftId, dipAmount);

        // interactions
        // transfer DIP token to designated address
        if (dipAmount.gtz()) {
            $._stakingService.pushDipToken(dipAmount, transferTo);
        }
    }


    function _addToken(
        StakingStorage storage $,
        ChainId chainId, 
        address token
    )
        internal
        virtual
    {
        $._store.addToken(chainId, token);
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
            address targetHandlerAddress,
            address stakingStoreAddress,
            address tokenRegistryAddress
        ) = abi.decode(data, (address, address, address, address));

        // wiring to external contracts
        IRegistry registry = IRegistry(registryAddress);
        StakingStorage storage $ = _getStakingStorage();
        $._protocolNftId = registry.getProtocolNftId();
        $._targetHandler = TargetHandler(targetHandlerAddress);
        $._store = StakingStore(stakingStoreAddress);
        $._reader = StakingStore(stakingStoreAddress).getStakingReader();
        $._tokenRegistry = TokenRegistry(tokenRegistryAddress);
        // staking service has to be set via setStakingService after deploying the first GIF release

        // initialize component
        __Component_init(
            registry.getAuthority(),
            address(registry), 
            registry.getNftId(), // parent nft id
            CONTRACT_NAME,
            STAKING(), 
            false, // is interceptor
            owner, 
            ""); // registry data

        // Protocol target is created in the StakingStore constructor.
        // This allows setting up the protocol target before the full 
        // staking authorization setup is in place.

        _registerInterface(type(IStaking).interfaceId);
    }


    function _checkTypeAndOwner(NftId nftId, ObjectType expectedObjectType, bool checkOwner)
        internal
        view
    {
        StakingStorage storage $ = _getStakingStorage();
        if (expectedObjectType == STAKE()) {
            if (!$._store.exists(nftId)) {
                revert ErrorStakingNotStake(nftId);
            }
        } else {
            if (expectedObjectType == TARGET()) {
                if (!$._store.getTargetSet().exists(nftId)) {
                    revert ErrorStakingNotTarget(nftId);
                }
            }
        }

        if (checkOwner) {
            address nftOwner = getRegistry().ownerOf(nftId);
            if (msg.sender != nftOwner) {
                revert ErrorStakingNotOwner(nftId, nftOwner, msg.sender);
            }
        }
    }


    function _getStakingStorage() private pure returns (StakingStorage storage $) {
        assembly {
            $.slot := STAKING_LOCATION_V1
        }
    }
}
