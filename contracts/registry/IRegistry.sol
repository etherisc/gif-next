// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {ChainNft} from "./ChainNft.sol";
import {NftId} from "../types/NftId.sol";
import {ObjectType} from "../types/ObjectType.sol";
import {VersionPart} from "../types/Version.sol";

interface IRegistry is IERC165 {

    event LogInitialMajorVersionSet(VersionPart majorVersion);
    event LogMajorVersionSet(VersionPart majorVersionMax);
    event LogRegistration(ObjectInfo info);
    event LogServiceRegistration(VersionPart majorVersion, ObjectType serviceType); 

    // setMajorVersion()
    error NotOwner(address account);
    error MajorVersionMaxIncreaseInvalid(VersionPart newMajorVersionMax, VersionPart existingMaxMajorVersion);

    // register()
    error NotRegistryService();
    error ZeroParentAddress();
    error InvalidTypesCombination(ObjectType objectType, ObjectType parentType);
    error ContractAlreadyRegistered(address objectAddress);
    error InvalidServiceVersion(VersionPart majorVersion);
    error ServiceAlreadyRegistered(ObjectType serviceType, VersionPart majorVersion);

    struct ObjectInfo {
        NftId nftId;
        NftId parentNftId;
        ObjectType objectType;
        bool isInterceptor;
        address objectAddress;
        address initialOwner;
        bytes data;
    }// TODO delete nftId and initialOwner(if not used) from struct
    // TODO strong disagree, keep nftId there (lets keep get object info return object consistent)

    function registerService(ObjectInfo memory service) external returns(NftId nftId);

    function register(ObjectInfo memory info) external returns (NftId nftId);

    function setServiceActive(VersionPart version, ObjectType serviceType, bool state) external;

    function getMajorVersionMin() external view returns (VersionPart);

    function getMajorVersionMax() external view returns (VersionPart);

    function getMajorVersion() external view returns (VersionPart);

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

    function getServiceAddress(
        ObjectType serviceType, 
        VersionPart releaseVersion
    ) external view returns (address serviceAddress);

    function getChainNft() external view returns (ChainNft);

    function getOwner() external view returns (address);
}