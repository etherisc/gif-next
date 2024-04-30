// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {NftId} from "../type/NftId.sol";
import {ObjectType} from "../type/ObjectType.sol";
import {VersionPart} from "../type/Version.sol";
import {Timestamp} from "../type/Timestamp.sol";

interface IRegistry is IERC165 {

    event LogRegistration(NftId nftId, NftId parentNftId, ObjectType objectType, bool isInterceptor, address objectAddress, address initialOwner);
    event LogServiceRegistration(VersionPart majorVersion, ObjectType domain);

    // registerService()
    error CallerNotReleaseManager();
    error ServiceAlreadyRegistered(address service);

    // register()
    error CallerNotRegistryService();
    error ServiceRegistration();

    // registerWithCustomTypes()
    error CoreTypeRegistration();

    // setTokenRegistry()
    error TokenRegistryZero();
    error TokenRegistryAlreadySet(address tokenRegistry);

    // _register()
    error ZeroParentAddress();
    error InvalidTypesCombination(ObjectType objectType, ObjectType parentType);
    error ContractAlreadyRegistered(address objectAddress);

    // _registerStaking()
    error StakingAlreadyRegistered(address stakingAddress);

    struct ObjectInfo {
        NftId nftId;
        NftId parentNftId;
        ObjectType objectType;
        bool isInterceptor;
        address objectAddress;
        address initialOwner;
        bytes data;
    }

    struct ReleaseInfo {
        ObjectType[] domains;
        Timestamp createdAt;
        //Timestamp updatedAt;
    }

    function registerService(
        ObjectInfo memory serviceInfo, 
        VersionPart serviceVersion, 
        ObjectType serviceDomain
    ) external returns(NftId nftId);

    function register(ObjectInfo memory info) external returns (NftId nftId);

    function registerWithCustomType(ObjectInfo memory info) external returns (NftId nftId);

    function getInitialVersion() external view returns (VersionPart);

    function getNextVersion() external view returns (VersionPart);

    function getLatestVersion() external view returns (VersionPart);

    function getReleaseInfo(VersionPart version) external view returns (ReleaseInfo memory);

    function getObjectCount() external view returns (uint256);

    function getNftId() external view returns (NftId nftId);

    function getNftId(address objectAddress) external view returns (NftId nftId);

    function ownerOf(NftId nftId) external view returns (address);

    function ownerOf(address contractAddress) external view returns (address);

    function getObjectInfo(NftId nftId) external view returns (ObjectInfo memory info);

    function getObjectInfo(address object) external view returns (ObjectInfo memory info);

    function isRegistered(NftId nftId) external view returns (bool);

    function isRegistered(address contractAddress) external view returns (bool);

    function isRegisteredService(address contractAddress) external view returns (bool);

    function isRegisteredComponent(address object) external view returns (bool);

    function isValidRelease(VersionPart version) external view returns (bool);

    function getServiceAddress(
        ObjectType serviceDomain, 
        VersionPart releaseVersion
    ) external view returns (address serviceAddress);

    function getStakingAddress() external view returns (address staking);

    function getTokenRegistryAddress() external view returns (address);

    function getReleaseManagerAddress() external view returns (address);

    function getChainNftAddress() external view returns (address);

    function getOwner() external view returns (address);
}