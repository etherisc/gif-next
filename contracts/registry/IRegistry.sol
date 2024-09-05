// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {IRelease} from "./IRelease.sol";

import {NftId} from "../type/NftId.sol";
import {ObjectType} from "../type/ObjectType.sol";
import {VersionPart} from "../type/Version.sol";

/// @title Chain Registry interface.
/// A chain registry holds all protocol relevant objects with basic metadata.
/// Registered objects include services, instances, products, pools, policies, bundles, stakes and more.
/// Registered objects are represented by NFTs.
/// When on mainnet registry is global and keeps arbitrary number of chain registries residing on different chain ids.
/// When not on mainnet registry keeps the only object residing on different chain id (on mainnet) - global registry.
interface IRegistry is
    IERC165
{

    event LogRegistration(NftId nftId, NftId parentNftId, ObjectType objectType, bool isInterceptor, address objectAddress, address initialOwner);
    event LogServiceRegistration(VersionPart majorVersion, ObjectType domain);
    event LogChainRegistryRegistration(NftId nftId, uint256 chainId, address chainRegistryAddress);

    // initialize
    error ErrorRegistryCallerNotDeployer();

    // register()
    error ErrorRegistryObjectTypeNotSupported(ObjectType objectType);

    // registerRegistry()
    error ErrorRegistryNotOnMainnet(uint256 chainId);
    error ErrorRegistryChainRegistryChainIdZero(NftId nftId);
    error ErrorRegistryChainRegistryAddressZero(NftId nftId, uint256 chainId);
    error ErrorRegistryChainRegistryNftIdInvalid(NftId nftId, uint256 chainId);
    error ErrorRegistryChainRegistryAlreadyRegistered(NftId nftId, uint256 chainId);

    // registerService()
    error ErrorRegistryServiceAddressZero(); 
    error ErrorRegistryServiceVersionZero(address service);

    // TODO cleanup
    //error ErrorRegistryServiceVersionMismatch(address service, VersionPart serviceVersion, VersionPart releaseVersion);
    //error ErrorRegistryServiceVersionNotDeploying(address service, VersionPart version);
    error ErrorRegistryServiceDomainZero(address service, VersionPart version);
    error ErrorRegistryNotService(address service, ObjectType objectType);
    error ErrorRegistryServiceParentNotRegistry(address service, VersionPart version, NftId parentNftId);
    error ErrorRegistryServiceDomainAlreadyRegistered(address service, VersionPart version, ObjectType domain);

    // registerWithCustomTypes()
    error ErrorRegistryCoreTypeRegistration();

    // _register()
    error ErrorRegistryGlobalRegistryAsParent(address objectAddress, ObjectType objectType);
    error ErrorRegistryTypeCombinationInvalid(address objectAddress, ObjectType objectType, ObjectType parentType);
    error ErrorRegistryContractAlreadyRegistered(address objectAddress);

    struct ObjectInfo {
        // slot 0
        NftId nftId;
        NftId parentNftId;
        ObjectType objectType;
        bool isInterceptor;
        // slot 1
        address objectAddress;
        // slot 2
        address initialOwner;
        // slot 3
        bytes data;
    }

    /// @dev Registers a registry contract for a specified chain.
    /// Only one chain registry may be registered per chain
    function registerRegistry(
        NftId nftId, 
        uint256 chainId, 
        address chainRegistryAddress
    ) external;

    /// @dev Register a service with using the provided domain and version.
    /// The function returns a newly minted service NFT ID.
    /// May only be used to register services.
    function registerService(
        ObjectInfo memory serviceInfo, 
        VersionPart serviceVersion, 
        ObjectType serviceDomain
    ) external returns(NftId nftId);

    /// @dev Register an object with a known core type.
    /// The function returns a newly minted object NFT ID.
    /// May not be used to register services.
    function register(ObjectInfo memory info) external returns (NftId nftId);

    /// @dev Register an object with a custom type.
    /// The function returns a newly minted object NFT ID.
    /// This function is reserved for GIF releases > 3.
    /// May not be used to register known core types.
    function registerWithCustomType(ObjectInfo memory info) external returns (NftId nftId);

    function getInitialVersion() external view returns (VersionPart);

    function getNextVersion() external view returns (VersionPart);

    function getLatestVersion() external view returns (VersionPart);

    function getReleaseInfo(VersionPart release) external view returns (IRelease.ReleaseInfo memory);

    /// @dev Returns the number of supported chains.
    function chainIds() external view returns (uint256);

    /// @dev Returns the chain id at the specified index.
    function getChainId(uint256 idx) external view returns (uint256);

    /// @dev Returns the NFT ID of the registry for the specified chain.
    function getRegistryNftId(uint256 chainId) external returns (NftId nftId); 

    function getObjectCount() external view returns (uint256);

    function getNftIdForAddress(address objectAddress) external view returns (NftId nftId);

    function ownerOf(NftId nftId) external view returns (address);

    function isOwnerOf(NftId nftId, address expectedOwner) external view returns (bool);

    function ownerOf(address contractAddress) external view returns (address);

    function getObjectInfo(NftId nftId) external view returns (ObjectInfo memory info);

    function getParentNftId(NftId nftId) external view returns (NftId parentNftId);

    function isObjectType(NftId nftId, ObjectType expectedObjectType) external view returns (bool);

    function isObjectType(address contractAddress, ObjectType expectedObjectType) external view returns (bool);

    function getObjectAddress(NftId nftId) external view returns (address objectAddress);

    /// @dev Returns the object info for the specified object address.
    //  MUST not be used with chain registry address (resides on different chan id)
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