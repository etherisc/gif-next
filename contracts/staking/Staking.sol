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
import {KEEP_STATE} from "../type/StateId.sol";
import {LibNftIdSet} from "../type/NftIdSet.sol";
import {NftId, NftIdLib} from "../type/NftId.sol";
import {NftIdSetManager} from "../shared/NftIdSetManager.sol";
import {ObjectType, INSTANCE, PROTOCOL, STAKE, STAKING, TARGET} from "../type/ObjectType.sol";
import {Seconds, SecondsLib} from "../type/Seconds.sol";
import {StakingReader} from "./StakingReader.sol";
import {StakingStore} from "./StakingStore.sol";
import {TargetManagerLib} from "./TargetManagerLib.sol";
import {Timestamp, TimestampLib} from "../type/Timestamp.sol";
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

        mapping(uint256 chainId => mapping(address token => UFixed stakingRate)) _stakingRate;

        mapping(NftId targetNftId => Amount stakedAmount) _stakedAmount;
        mapping(NftId targetNftId => mapping(address token => Amount tvlAmount)) _tvlAmount;
    }


    modifier onlyNftOwner(NftId nftId) {
        // TODO deal with special case protocol target (=owner = registry service owner)
        if(msg.sender != getRegistry().ownerOf(nftId)) {
            revert ErrorStakingNotNftOwner(nftId);
        }
        _;
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


    // set/update staking reader
    function setStakingReader(StakingReader stakingReader)
        external
        virtual
        onlyOwner
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
        onlyOwner
    {

    }

    // reward management 

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
        // restricted // staking service access
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
                rewardRate: initialRewardRate,
                rewardReserveAmount: AmountLib.zero()}));

        emit LogStakingTargetAdded(targetNftId, expectedObjectType, chainId);
    }


    function setLockingPeriod(
        NftId targetNftId, 
        Seconds lockingPeriod
    )
        external
        virtual
        onlyNftOwner(targetNftId)
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


    function setRewardRate(NftId targetNftId, UFixed rewardRate)
        external
        virtual
        onlyNftOwner(targetNftId)
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
    {

    }

    function withdrawRewardReserves(NftId targetNftId, Amount dipAmount)
        external
        virtual
        // onlyNftOwner(targetNftId)
    {
        
    }


    function increaseTvl(NftId targetNftId, address token, Amount amount)
        external
        virtual
        // restricted // service to service access
    {

    }

    function decreaseTvl(NftId targetNftId, address token, Amount amount)
        external
        virtual
        // restricted // service to service access
    {

    }


    function registerRemoteTarget(NftId targetNftId, TargetInfo memory targetInfo)
        external
        virtual
        onlyOwner // or CCIP
    {
        
    }

    function updateRemoteTvl(NftId targetNftId, address token, Amount amount)
        external
        virtual
        onlyOwner // or CCIP
    {
        
    }

    //--- staking functions -----------------------------------------//
    function create(
        NftId stakeNftId, 
        NftId targetNftId, 
        Amount dipAmount
    )
        external
        virtual
    {
        _getStakingStorage()._store.create(
            stakeNftId, 
            targetNftId, 
            dipAmount);
    }


    function stake(NftId stakeNftId, Amount dipAmount) external {}
    function restakeRewards(NftId stakeNftId) external {}
    function restakeToNewTarget(NftId stakeNftId, NftId newTarget) external {}


    function unstake(NftId stakeNftId)
        external
        virtual
        onlyNftOwner(stakeNftId)
    {
    }


    function unstake(NftId stakeNftId, Amount dipAmount) external {}
    function claimRewards(NftId stakeNftId) external {}


    // view functions

    function getStakingReader() public view returns (StakingReader reader) {
        return _getStakingStorage()._reader;
    }

    function getStakingStore() external view returns (StakingStore stakingStore) {
        return _getStakingStorage()._store;
    }

    function getStakingRate(uint256 chainId, address token) external view returns (UFixed stakingRate) {
        return _getStakingStorage()._stakingRate[chainId][token];
    }

    function getTvlAmount(NftId targetNftId, address token) external view returns (Amount tvlAmount) {
        return _getStakingStorage()._tvlAmount[targetNftId][token];
    }

    function getStakedAmount(NftId targetNftId) external view returns (Amount stakeAmount) {
        return _getStakingStorage()._stakedAmount[targetNftId];
    }

    function getTokenRegistryAddress() external view returns (address tokenRegistry) {
        return address(_getStakingStorage()._tokenRegistry);
    }

    function calculateRewardIncrementAmount(
        NftId targetNftId,
        Timestamp rewardsLastUpdatedAt
    )
        public 
        virtual
        view 
        returns (Amount rewardIncrementAmount)
    {

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
            address initialAuthority,
            address registryAddress,
            address stakingStoreAddress,
            address stakingReaderAddress,
            address initialOwner
        ) = abi.decode(data, (address, address, address, address, address));

        IRegistry registry = IRegistry(registryAddress);
        TokenRegistry tokenRegistry = TokenRegistry(registry.getTokenRegistryAddress());
        address dipTokenAddress = address(tokenRegistry.getDipToken());

        initializeComponent(
            initialAuthority,
            registryAddress, 
            registry.getNftId(), 
            CONTRACT_NAME,
            dipTokenAddress,
            STAKING(), 
            false, // is interceptor
            initialOwner, 
            "", // registry data
            ""); // component data

        _createAndSetTokenHandler();

        // wiring to external contracts
        StakingStorage storage $ = _getStakingStorage();
        $._store = StakingStore(stakingStoreAddress);
        $._reader = StakingReader(stakingReaderAddress);
        $._tokenRegistry = TokenRegistry(
            address(tokenRegistry));

        // wiring to staking
        $._reader.setStakingDependencies(
            address(this),
            address($._store));

        registerInterface(type(IStaking).interfaceId);
    }


    function _getStakingStorage() private pure returns (StakingStorage storage $) {
        assembly {
            $.slot := STAKING_LOCATION_V1
        }
    }

}
