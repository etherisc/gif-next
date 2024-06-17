// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {NftId} from "../type/NftId.sol";
import {ObjectType} from "../type/ObjectType.sol";
import {VersionPart} from "../type/Version.sol";
import {Timestamp} from "../type/Timestamp.sol";
import {RoleId} from "../type/RoleId.sol";

interface IRegistry is IERC165 {

    event LogRegistration(NftId nftId, NftId parentNftId, ObjectType objectType, bool isInterceptor, address objectAddress, address initialOwner);
    event LogServiceRegistration(VersionPart majorVersion, ObjectType domain);

    // registerService()
    error ErrorRegistryCallerNotReleaseManager();
    error ErrorRegistryDomainZero(address service);
    error ErrorRegistryDomainAlreadyRegistered(address service, VersionPart version, ObjectType domain);

    // register()
    error ErrorRegistryCallerNotRegistryService();

    // registerWithCustomTypes()
    error ErrorRegistryCoreTypeRegistration();

    // _register()
    error ErrorRegistryParentAddressZero();
    error ErrorRegistryTypesCombinationInvalid(ObjectType objectType, ObjectType parentType);
    error ErrorRegistryContractAlreadyRegistered(address objectAddress);

    struct ObjectInfo {
        NftId nftId;
        NftId parentNftId;
        ObjectType objectType;
        bool isInterceptor;
        address objectAddress;
        address initialOwner;
        bytes data;
    }

    // TODO cleanup
    struct ReleaseInfo {
        VersionPart version;
        bytes32 salt;
        address[] addresses;
        string[] names;
        RoleId[][] serviceRoles;
        string[][] serviceRoleNames;
        RoleId[][] functionRoles;
        string[][] functionRoleNames;
        bytes4[][][] selectors;
        ObjectType[] domains;
        Timestamp activatedAt;
        Timestamp disabledAt;
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

    function getNftId(address objectAddress) external view returns (NftId nftId);

    function ownerOf(NftId nftId) external view returns (address);

    function ownerOf(address contractAddress) external view returns (address);

    function getObjectInfo(NftId nftId) external view returns (ObjectInfo memory info);

    function getObjectInfo(address object) external view returns (ObjectInfo memory info);

    function isRegistered(NftId nftId) external view returns (bool);

    function isRegistered(address contractAddress) external view returns (bool);

    function isRegisteredService(address contractAddress) external view returns (bool);

    function isRegisteredComponent(address object) external view returns (bool);

    function isActiveRelease(VersionPart version) external view returns (bool);

    function getServiceAddress(
        ObjectType serviceDomain, 
        VersionPart releaseVersion
    ) external view returns (address serviceAddress);

    function getProtocolNftId() external view returns (NftId protocolNftId);

    function getNftId() external view returns (NftId nftId);

    function getOwner() external view returns (address);

    // TODO refactor the address getters below to contract getters
    function getChainNftAddress() external view returns (address);

    function getReleaseManagerAddress() external view returns (address);

    function getReleaseAccessManagerAddress(VersionPart version) external view returns (address);

    function getStakingAddress() external view returns (address);

    function getTokenRegistryAddress() external view returns (address);

    function getRegistryAdminAddress() external view returns (address);

    function getAuthority() external view returns (address);
}