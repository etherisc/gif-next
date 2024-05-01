// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {ObjectType, STAKING, INSTANCE, PROTOCOL} from "../type/ObjectType.sol";
import {NftId, NftIdLib} from "../type/NftId.sol";
import {Version, VersionLib, VersionPartLib} from "../type/Version.sol";

import {Amount} from "../type/Amount.sol";
import {ChainNft} from "../registry/ChainNft.sol";
import {Component} from "../shared/Component.sol";
import {IStaking} from "./IStaking.sol";
import {IVersionable} from "../shared/IVersionable.sol";
import {KeyValueStore} from "../shared/KeyValueStore.sol";
import {LibNftIdSet} from "../type/NftIdSet.sol";
import {Timestamp, TimestampLib} from "../type/Timestamp.sol";
import {TokenRegistry} from "../registry/TokenRegistry.sol";
import {UFixed} from "../type/UFixed.sol";
import {Versionable} from "../shared/Versionable.sol";

import {IRegistry} from "../registry/IRegistry.sol";

contract Staking is 
    KeyValueStore,
    Component,
    Versionable,
    IStaking
{
    string public constant CONTRACT_NAME = "Staking";
    uint8 private constant GIF_MAJOR_VERSION = 3;

    // keccak256(abi.encode(uint256(keccak256("gif-next.contracts.component.Staking.sol")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 public constant STAKING_LOCATION_V1 = 0xafe8d4462b2ed26a47154f4b8f6d1497d2f772496965791d25bd456e342b7f00;

    struct StakingStorage {
        LibNftIdSet.Set _targets;
        LibNftIdSet.Set _activeTargets;
        TokenRegistry _tokenRegistry;

        mapping(NftId targetNftId => UFixed rewardRate) _rewardRate;
        mapping(NftId targetNftId => Amount reserveAmount) _rewardReserveAmount;
        mapping(uint256 chainId => mapping(address token => UFixed stakingRate)) _stakingRate;

        mapping(NftId targetNftId => TargetInfo info) _targetInfo;
        mapping(NftId targetNftId => Amount stakedAmount) _stakedAmount;
        mapping(NftId targetNftId => mapping(address token => Amount tvlAmount)) _tvlAmount;
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

    // rate management 
    function setStakingRate(uint256 chainId, address token, UFixed stakingRate)
        external
        virtual
        onlyOwner
    {

    }

    // reward management 
    function setRewardRate(NftId targetNftId, UFixed rewardRate)
        external
        virtual
        // onlyNftOwner(targetNftId)
    {
        
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

    // target management
    function registerInstanceTarget(NftId targetNftId)
        external
        virtual
        // restricted // instance service access
    {
        _registerTarget(
            targetNftId,
            INSTANCE(),
            block.chainid);
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

    // staking functions
    function createStake(NftId targetNftId, Amount dipAmount) external returns(NftId stakeNftId) {}
    function stake(NftId stakeNftId, Amount dipAmount) external {}
    function restakeRewards(NftId stakeNftId) external {}
    function restakeToNewTarget(NftId stakeNftId, NftId newTarget) external {}
    function unstake(NftId stakeNftId) external {}
    function unstake(NftId stakeNftId, Amount dipAmount) external {}
    function claimRewards(NftId stakeNftId) external {}


    // view and pure functions (staking reader?)
    function isTargetTypeSupported(ObjectType objectType) public pure returns (bool isSupported) {
        if(objectType == PROTOCOL()) { return true; }
        if(objectType == INSTANCE()) { return true; }

        return false;
    }


    function getStakingRate(uint256 chainId, address token) external view returns (UFixed stakingRate) {
        return _getStakingStorage()._stakingRate[chainId][token];
    }

    function getRewardRate(NftId targetNftId) external view returns (UFixed rewardRate) {
        return _getStakingStorage()._rewardRate[targetNftId];
    }

    function getRewardReserves(NftId targetNftId) external view returns (Amount rewardReserveAmount)  {
        return _getStakingStorage()._rewardReserveAmount[targetNftId];
    }


    function getStakeInfo() external view returns (NftId stakeNftId) {}

    function targets() external view returns (uint256) {
        return LibNftIdSet.size(_getStakingStorage()._targets);
    }

    function getTargetNftId(uint256 idx) external view returns (NftId targetNftId) {
        return LibNftIdSet.getElementAt(_getStakingStorage()._targets, idx);
    }

    function activeTargets() external view returns (uint256) {
        return LibNftIdSet.size(_getStakingStorage()._activeTargets);
    }

    function getActiveTargetNftId(uint256 idx) external view returns (NftId targetNftId) {
        return LibNftIdSet.getElementAt(_getStakingStorage()._activeTargets, idx);
    }

    function isTarget(NftId targetNftId) public view returns (bool) {
        return LibNftIdSet.contains(_getStakingStorage()._targets, targetNftId);
    }

    function isActive(NftId targetNftId) public view returns (bool) {
        return LibNftIdSet.contains(_getStakingStorage()._activeTargets, targetNftId);
    }

    function getTargetInfo(NftId targetNftId) external view returns (TargetInfo memory info) {
        return _getStakingStorage()._targetInfo[targetNftId];
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
            address initialOwner
        ) = abi.decode(data, (address, address, address));

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

        // set token registry
        _getStakingStorage()._tokenRegistry = TokenRegistry(
            address(tokenRegistry));

        // execute additional setup steps
        _createAndSetTokenHandler();
        _registerProtocolTarget();

        registerInterface(type(IStaking).interfaceId);
    }


    function _registerTarget(
        NftId targetNftId,
        ObjectType expectedObjectType,
        uint256 chainId
    )
        internal
    {
        StakingStorage storage $ = _getStakingStorage();

        // target nft id must not be zero
        if (targetNftId.eqz()) {
            revert ErrorStakingTargetNftIdZero();
        }

        // only accept "new" targets to be registered
        if (isTarget(targetNftId)) {
            revert ErrorStakingTargetAlreadyRegistered(targetNftId);
        }

        // target object type must be allowed
        if (!isTargetTypeSupported(expectedObjectType)) {
            revert ErrorStakingTargetTypeNotSupported(targetNftId, expectedObjectType);
        }

        // target nft id must be known and registered with the expected object type
        IRegistry registry = getRegistry();
        if (!registry.isRegistered(targetNftId)) {
            revert ErrorStakingTargetNotFound(targetNftId);
        } else {
            // check that expected object type matches with registered object type
            ObjectType actualObjectType = registry.getObjectInfo(targetNftId).objectType;
            if (actualObjectType != expectedObjectType) {
                revert ErrorStakingTargetUnexpectedObjectType(targetNftId, expectedObjectType, actualObjectType);
            }
        }

        // record target info
        $._targetInfo[targetNftId] = TargetInfo({
            objectType: expectedObjectType,
            chainId: chainId,
            createdAt: TimestampLib.blockTimestamp()
        });

        // add target nft id to all/active sets
        LibNftIdSet.add($._targets, targetNftId);
        LibNftIdSet.add($._activeTargets, targetNftId);

        emit LogStakingTargetAdded(targetNftId, expectedObjectType, chainId);
    }


    function _setTokenRegistry() internal {
        StakingStorage storage $ = _getStakingStorage();

        $._tokenRegistry = TokenRegistry(
            getRegistry().getTokenRegistryAddress());
    }


    function _registerProtocolTarget() internal {
        uint256 protocolId = ChainNft(
            getRegistry().getChainNftAddress()).PROTOCOL_NFT_ID();

        NftId protocolNftId = NftIdLib.toNftId(protocolId);
        _registerTarget(
            protocolNftId,
            PROTOCOL(),
            1); // protocol is registered on mainnet
    }


    function _getStakingStorage() private pure returns (StakingStorage storage $) {
        assembly {
            $.slot := STAKING_LOCATION_V1
        }
    }

}
