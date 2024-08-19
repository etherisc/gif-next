// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IRegistry} from "../registry/IRegistry.sol";
import {IRegistryService} from "../registry/IRegistryService.sol";
import {IRelease} from "../registry/IRelease.sol";
import {IStaking} from "./IStaking.sol";
import {IVersionable} from "../upgradeability/IVersionable.sol";

import {Amount, AmountLib} from "../type/Amount.sol";
import {Component} from "../shared/Component.sol";
import {IComponent} from "../shared/IComponent.sol";
import {IComponentService} from "../shared/IComponentService.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType, COMPONENT, STAKING} from "../type/ObjectType.sol";
import {Seconds} from "../type/Seconds.sol";
import {Registerable} from "../shared/Registerable.sol";
import {StakeManagerLib} from "./StakeManagerLib.sol";
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
        StakingStore _store;
        StakingReader _reader;
        NftId _protocolNftId;
    }

    modifier onlyRegistry() {
        if (msg.sender != address(getRegistry())) {
            revert ErrorStakingNotRegistry(msg.sender);
        }
        _;
    }


    modifier onlyStake(NftId stakeNftId) {
        if (!_getStakingStorage()._store.exists(stakeNftId)) {
            revert ErrorStakingNotStake(stakeNftId);
        }
        _;
    }


    modifier onlyTarget(NftId targetNftId) {
        if (!_getStakingStorage()._store.getTargetNftIdSet().exists(targetNftId)) {
            revert ErrorStakingNotTarget(targetNftId);
        }
        _;
    }

    function initializeTokenHandler()
        external
        onlyRegistry()
    {
        StakingStorage storage $ = _getStakingStorage();

        if(address($._tokenHandler) != address(0)) {
            revert ErrorStakingTokenHandlerAlreadyInitialized(address($._tokenHandler));
        }

        $._tokenHandler = TokenHandlerDeployerLib.deployTokenHandler(
            address(getRegistry()),
            address(this),
            address(getToken()), 
            getRegistry().getAuthority());
    }


    function approveTokenHandler(IERC20Metadata token, Amount amount)
        public
        restricted() // TODO consider deleting this -> under control of RegistryAdmin -> can not be locked, see similar functions below
        onlyOwner()
    {
        _approveTokenHandler(token, amount);
    }


    // set/update staking reader
    function setStakingReader(StakingReader stakingReader)
        external
        virtual
        onlyOwner()
    {
        if(stakingReader.getStaking() != IStaking(this)) {
            revert ErrorStakingStakingReaderStakingMismatch(address(stakingReader.getStaking()));
        }

        _getStakingStorage()._reader = stakingReader;
    }


    // rate management 
    function setStakingRate(uint256 chainId, address token, UFixed stakingRate)
        external
        virtual
        onlyOwner()
    {
        StakingStorage storage $ = _getStakingStorage();
        
        if (!$._tokenRegistry.isRegistered(chainId, token)) {
            revert ErrorStakingTokenNotRegistered(chainId, token);
        }

        UFixed oldStakingRate = $._store.getStakingRate(chainId, token);
        $._store.setStakingRate(chainId, token, stakingRate);

        emit LogStakingStakingRateSet(chainId, token, oldStakingRate, stakingRate);
    }

    // target management

    function registerTarget(
        NftId targetNftId,
        ObjectType expectedObjectType,
        uint256 chainId,
        Seconds initialLockingPeriod,
        UFixed initialRewardRate
    )
        external
        virtual
        restricted()
    {
        TargetManagerLib.checkTargetParameters(
            getRegistry(), 
            _getStakingStorage()._reader,
            targetNftId, 
            expectedObjectType, 
            initialLockingPeriod, 
            initialRewardRate);

        _getStakingStorage()._store.createTarget(
            targetNftId,
            TargetInfo({
                objectType: expectedObjectType,
                chainId: chainId,
                lockingPeriod: initialLockingPeriod,
                rewardRate: initialRewardRate}));
    }


    function setLockingPeriod(
        NftId targetNftId, 
        Seconds lockingPeriod
    )
        external
        virtual
        restricted()
        onlyTarget(targetNftId)
    {
        (
            Seconds oldLockingPeriod,
            TargetInfo memory targetInfo
        ) = TargetManagerLib.updateLockingPeriod(
            this,
            targetNftId,
            lockingPeriod);
        
        _getStakingStorage()._store.updateTarget(targetNftId, targetInfo);

        emit LogStakingLockingPeriodSet(targetNftId, oldLockingPeriod, lockingPeriod);
    }

    // TODO add function to set protocol reward rate: onlyOwner
    // get protocol nft id (from where)

    function setRewardRate(NftId targetNftId, UFixed rewardRate)
        external
        virtual
        restricted()
        onlyTarget(targetNftId)
    {
        (
            UFixed oldRewardRate,
            TargetInfo memory targetInfo
        ) = TargetManagerLib.updateRewardRate(
            this,
            targetNftId,
            rewardRate);
        
        _getStakingStorage()._store.updateTarget(targetNftId, targetInfo);

        emit LogStakingRewardRateSet(targetNftId, oldRewardRate, rewardRate);
    }


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


    function increaseTotalValueLocked(NftId targetNftId, address token, Amount amount)
        external
        virtual
        restricted() // only pool service
        returns (Amount newBalance)
    {
        StakingStorage storage $ = _getStakingStorage();
        uint chainId = $._reader.getTargetInfo(targetNftId).chainId;
        UFixed stakingRate = $._reader.getStakingRate(chainId, token);
        newBalance = $._store.increaseTotalValueLocked(targetNftId, stakingRate, token, amount);
    }


    function decreaseTotalValueLocked(NftId targetNftId, address token, Amount amount)
        external
        virtual
        restricted() // only pool service
        returns (Amount newBalance)
    {
        StakingStorage storage $ = _getStakingStorage();
        uint chainId = $._reader.getTargetInfo(targetNftId).chainId;
        UFixed stakingRate = $._reader.getStakingRate(chainId, token);
        newBalance = $._store.decreaseTotalValueLocked(targetNftId, stakingRate, token, amount);
    }


    function registerRemoteTarget(NftId targetNftId, TargetInfo memory targetInfo)
        external
        virtual
        restricted()
        onlyOwner // or CCIP
    {
        
    }

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
    {
        StakingStorage storage $ = _getStakingStorage();
        Timestamp lockedUntil = StakeManagerLib.checkCreateParameters(
            $._reader,
            targetNftId,
            stakeAmount);

        // create new stake
        $._store.create(
            stakeNftId, 
            StakeInfo({
                lockedUntil: lockedUntil}));
        
        // update target stake balance
        $._store.increaseStake(
            stakeNftId,
            targetNftId, 
            stakeAmount);
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
        stakeBalance = StakeManagerLib.stake(
            getRegistry(),
            $._reader,
            $._store,
            stakeNftId,
            stakeAmount);
    }


    function restake(
        NftId stakeNftId, 
        NftId newTargetNftId
    )
        external
        virtual
        restricted() // only staking service
        onlyStake(stakeNftId)
        returns (NftId newStakeNftId)
    {
        // TODO add check that allows additional staking amount
        StakingStorage storage $ = _getStakingStorage();

        // TODO implement
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
        rewardsClaimedAmount = $._store.claimUpTo(
            stakeNftId,
            targetNftId, 
            AmountLib.max());

        // update reward reserves
        $._store.decreaseReserves(targetNftId, rewardsClaimedAmount);
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
        
        StakeManagerLib.checkUnstakeParameters($._reader, stakeNftId);
        
        // update rewards since last update
        NftId targetNftId = _updateRewards($._reader, $._store, stakeNftId);

        // unstake all available dips
        (
            unstakedAmount, 
            rewardsClaimedAmount
        ) = $._store.unstakeUpTo(
            stakeNftId,
            targetNftId,
            AmountLib.max(), // unstake all stakes
            AmountLib.max()); // claim all rewards

        // update reward reserves
        $._store.decreaseReserves(targetNftId, rewardsClaimedAmount);
    }


    //--- view functions ----------------------------------------------------//

    function getStakingReader() public view returns (StakingReader reader) {
        return _getStakingStorage()._reader;
    }

    function getStakingStore() external view returns (StakingStore stakingStore) {
        return _getStakingStorage()._store;
    }

    function getTokenRegistryAddress() external view returns (address tokenRegistry) {
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
        (Amount rewardIncrement, ) = StakeManagerLib.calculateRewardIncrease(
            reader, 
            stakeNftId,
            rewardRate);

        store.updateRewards(
            stakeNftId, 
            targetNftId,
            rewardIncrement);
    }


    function _approveTokenHandler(IERC20Metadata token, Amount amount)
        internal
        virtual override
    {
        IComponentService(_getServiceAddress(COMPONENT())).approveStakingTokenHandler(
            token, 
            amount);
    }


    function _initialize(
        address owner, 
        bytes memory data
    )
        internal
        virtual override
        initializer()
    {
        (
            address registryAddress,
            address tokenRegistryAddress,
            address stakingStoreAddress,
            address stakingOwner
        ) = abi.decode(data, (address, address, address, address));

        // only admin(authority) and dip token address are set in registry at this point
        IRegistry registry = IRegistry(registryAddress);
        address authority = registry.getAuthority();
        TokenRegistry tokenRegistry = TokenRegistry(tokenRegistryAddress);
        address dipTokenAddress = tokenRegistry.getDipTokenAddress();

        // wiring to external contracts
        StakingStorage storage $ = _getStakingStorage();
        $._protocolNftId = registry.getProtocolNftId();
        $._store = StakingStore(stakingStoreAddress);
        $._reader = StakingStore(stakingStoreAddress).getStakingReader();
        $._tokenRegistry = TokenRegistry(tokenRegistryAddress);

        _initializeComponent(
            authority,
            registryAddress, 
            registry.getNftId(), // parent nft id
            CONTRACT_NAME,
            dipTokenAddress,
            STAKING(), 
            false, // is interceptor
            stakingOwner, 
            "", // registry data
            ""); // component data

        _registerInterface(type(IStaking).interfaceId);
    }


    function _getStakingStorage() private pure returns (StakingStorage storage $) {
        assembly {
            $.slot := STAKING_LOCATION_V1
        }
    }
}
