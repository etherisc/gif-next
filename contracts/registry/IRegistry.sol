// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {NftId} from "../type/NftId.sol";
import {ObjectType} from "../type/ObjectType.sol";
import {VersionPart} from "../type/Version.sol";
import {Timestamp} from "../type/Timestamp.sol";

/// @title Chain Registry interface.
/// A chain registry holds all protocol relevant objects with basic metadata.
/// Registered objects include services, instances, products, pools, policies, bundles, stakes and more.
/// Registered objects are represented by NFTs.
interface IRegistry is IERC165 {

    event LogRegistration(NftId nftId, NftId parentNftId, ObjectType objectType, bool isInterceptor, address objectAddress, address initialOwner);
    event LogServiceRegistration(VersionPart majorVersion, ObjectType domain);

    // register()
    error ErrorRegistryCallerNotRegistryService();
    error ErrorRegistryService(address service);

    // registerService()
    error ErrorRegistryCallerNotReleaseRegistry();
    error ErrorRegistryServiceAddressZero(); 
    error ErrorRegistryServiceVersionZero(); 
    error ErrorRegistryNotService(address service, ObjectType objectType);
    error ErrorRegistryServiceParentNotRegistry(NftId parentNftId);
    error ErrorRegistryDomainZero(address service);
    error ErrorRegistryDomainAlreadyRegistered(address service, VersionPart version, ObjectType domain);

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

    struct ReleaseInfo {
        VersionPart version;
        bytes32 salt;
        address[] addresses;
        string[] names;
        ObjectType[] domains;
        Timestamp activatedAt;
        Timestamp disabledAt;
    }

    /// @dev Register an object with a known core type.
    /// The function returns a newly minted object NFT ID.
    /// May not be used to register services.
    function register(ObjectInfo memory info) external returns (NftId nftId);

    /// @dev Register a service with using the provided domain and version.
    /// The function returns a newly minted service NFT ID.
    /// May only be used to register services.
    function registerService(
        ObjectInfo memory serviceInfo, 
        VersionPart serviceVersion, 
        ObjectType serviceDomain
    ) external returns(NftId nftId);

    /// @dev Register an object with a custom type.
    /// The function returns a newly minted object NFT ID.
    /// This function is reserved for GIF releases > 3.
    /// May not be used to register known core types.
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

    function getReleaseRegistryAddress() external view returns (address);

    function getStakingAddress() external view returns (address);

    function getTokenRegistryAddress() external view returns (address);

    function getRegistryAdminAddress() external view returns (address);

    function getAuthority() external view returns (address);
}