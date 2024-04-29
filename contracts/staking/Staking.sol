// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {ObjectType, REGISTRY, STAKING} from "../type/ObjectType.sol";
import {NftId} from "../type/NftId.sol";
import {Version, VersionLib, VersionPartLib} from "../type/Version.sol";

import {Amount} from "../type/Amount.sol";
import {Component} from "../shared/Component.sol";
import {IStaking} from "./IStaking.sol";
import {IVersionable} from "../shared/IVersionable.sol";
import {KeyValueStore} from "../shared/KeyValueStore.sol";
import {Timestamp} from "../type/Timestamp.sol";
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
        mapping(uint256 chainId => mapping(address token => UFixed stakingRate)) _stakingRate;
        mapping(NftId targetNftId => UFixed rewardRate) _rewardRate;
        mapping(NftId targetNftId => Amount reserveAmount) _rewardReserveAmount;
        mapping(NftId targetNftId => Amount stakedAmount) _stakedAmount;
        mapping(NftId targetNftId => mapping(address token => Amount tvlAmount)) _tvlAmount;
    }

    function _getStakingStorage() private pure returns (StakingStorage storage $) {
        assembly {
            $.slot := STAKING_LOCATION_V1
        }
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
            address dipTokenAddress,
            address initialOwner
        ) = abi.decode(data, (address, address, address, address));

        initializeComponent(
            initialAuthority,
            registryAddress, 
            IRegistry(registryAddress).getNftId(), 
            CONTRACT_NAME,
            dipTokenAddress,
            STAKING(), 
            false, // is interceptor
            initialOwner, 
            "", // registry data
            ""); // component data

        // create the staking token handler
        _createAndSetTokenHandler();

        registerInterface(type(IStaking).interfaceId);
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
    function registerTarget(NftId targetNftId)
        external
        virtual
        // restricted // service to service access
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

    // staking functions
    function createStake(NftId targetNftId, Amount dipAmount) external returns(NftId stakeNftId) {}
    function stake(NftId stakeNftId, Amount dipAmount) external {}
    function restakeRewards(NftId stakeNftId) external {}
    function restakeToNewTarget(NftId stakeNftId, NftId newTarget) external {}
    function unstake(NftId stakeNftId) external {}
    function unstake(NftId stakeNftId, Amount dipAmount) external {}
    function claimRewards(NftId stakeNftId) external {}

    // view and pure functions (staking reader?)
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
    function getTargetInfo() external view returns (NftId stakeNftId) {}

    function getTvlAmount(NftId targetNftId, address token) external view returns (Amount tvlAmount) {
        return _getStakingStorage()._tvlAmount[targetNftId][token];
    }

    function getStakedAmount(NftId targetNftId) external view returns (Amount stakeAmount) {
        return _getStakingStorage()._stakedAmount[targetNftId];
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

}
