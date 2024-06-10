// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount, AmountLib} from "../type/Amount.sol";
import {ChainNft} from "../registry/ChainNft.sol";
import {Component} from "../shared/Component.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {IRegistryService} from "../registry/IRegistryService.sol";
import {IStaking} from "./IStaking.sol";
import {IVersionable} from "../shared/IVersionable.sol";
import {Key32} from "../type/Key32.sol";
import {LibNftIdSet} from "../type/NftIdSet.sol";
import {NftId, NftIdLib} from "../type/NftId.sol";
import {NftIdSetManager} from "../shared/NftIdSetManager.sol";
import {ObjectType, INSTANCE, PROTOCOL, STAKE, STAKING, TARGET} from "../type/ObjectType.sol";
import {Seconds, SecondsLib} from "../type/Seconds.sol";
import {StakeManagerLib} from "./StakeManagerLib.sol";
import {StakingReader} from "./StakingReader.sol";
import {StakingStore} from "./StakingStore.sol";
import {TargetManagerLib} from "./TargetManagerLib.sol";
import {Timestamp, TimestampLib} from "../type/Timestamp.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";
import {TokenRegistry} from "../registry/TokenRegistry.sol";
import {UFixed, UFixedLib} from "../type/UFixed.sol";
import {Version, VersionLib} from "../type/Version.sol";
import {Versionable} from "../shared/Versionable.sol";

contract Staking is 
    Component,
    Versionable,
    IStaking
{
    string public constant CONTRACT_NAME = "Staking";
    uint8 private constant GIF_MAJOR_VERSION = 3;

    // keccak256(abi.encode(uint256(keccak256("gif-next.contracts.component.Staking.sol")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 public constant STAKING_LOCATION_V1 = 0xafe8d4462b2ed26a47154f4b8f6d1497d2f772496965791d25bd456e342b7f00;

    struct StakingStorage {
        IRegistryService _registryService;
        TokenRegistry _tokenRegistry;
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


    modifier onlyTarget(NftId targetNftId) {
        if (!_getStakingStorage()._store.getTargetManager().exists(targetNftId)) {
            revert ErrorStakingNotTarget(targetNftId);
        }
        _;
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
        // TODO add check that stake locking is in the past
        StakingStorage storage $ = _getStakingStorage();

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



    //--- other functions ---------------------------------------------------//

    function collectDipAmount(address from, Amount dipAmount)
        external
        restricted() // only staking service
    {
        TokenHandler tokenHandler = getTokenHandler();
        address stakingWallet = getWallet();

        StakeManagerLib.checkDipBalanceAndAllowance(
            getToken(), 
            from, 
            address(tokenHandler), 
            dipAmount);

        tokenHandler.transfer(from, stakingWallet, dipAmount);
    }


    function transferDipAmount(address to, Amount dipAmount)
        external
        restricted() // only staking service
    {
        TokenHandler tokenHandler = getTokenHandler();
        address stakingWallet = getWallet();

        StakeManagerLib.checkDipBalanceAndAllowance(
            getToken(), 
            stakingWallet, 
            address(tokenHandler), 
            dipAmount);

        tokenHandler.transfer(stakingWallet, to, dipAmount);
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


    // from Versionable
    function getVersion()
        public 
        pure 
        virtual override (IVersionable, Versionable)
        returns(Version)
    {
        return VersionLib.toVersion(GIF_MAJOR_VERSION,0,0);
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


    function _initialize(
        address owner, 
        bytes memory data
    )
        internal
        virtual override
        initializer
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

        initializeComponent(
            authority,
            registryAddress, 
            registry.getNftId(), 
            CONTRACT_NAME,
            dipTokenAddress,
            STAKING(), 
            false, // is interceptor
            stakingOwner, 
            "", // registry data
            ""); // component data

        _createAndSetTokenHandler();

        // wiring to external contracts
        StakingStorage storage $ = _getStakingStorage();
        $._protocolNftId = getRegistry().getProtocolNftId();
        $._store = StakingStore(stakingStoreAddress);
        $._reader = StakingStore(stakingStoreAddress).getStakingReader();
        $._tokenRegistry = TokenRegistry(tokenRegistryAddress);

        registerInterface(type(IStaking).interfaceId);
    }


    function _getStakingStorage() private pure returns (StakingStorage storage $) {
        assembly {
            $.slot := STAKING_LOCATION_V1
        }
    }
}
