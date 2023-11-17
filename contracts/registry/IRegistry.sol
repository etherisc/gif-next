// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin5/contracts/utils/introspection/IERC165.sol";

import {NftId} from "../types/NftId.sol";
import {ObjectType} from "../types/ObjectType.sol";
import {VersionPart} from "../types/Version.sol";
import {IChainNft} from "./IChainNft.sol";

interface IRegistry is IERC165 {

    event LogObjectRegistered(NftId nftId, NftId parentNftId, ObjectType objectType, address objectAddress, address initialOwner);

    event LogServiceRegistered(address service, string serviceName, VersionPart majorVersion); 

    event LogApproval(NftId nftId, ObjectType objectType);

    struct ObjectInfo {
        NftId nftId;
        NftId parentNftId;
        ObjectType objectType;
        address objectAddress;
        address initialOwner;
        bytes data;
    }

    function register(ObjectInfo memory info) external returns (NftId nftId);
    
    function registerFrom(
        address from, 
        ObjectInfo memory info
    ) external returns (NftId nftId);

    function approve(
        NftId registrar,
        ObjectType object,
        ObjectType parent
    ) external;

    function allowance(
        NftId registrar,
        ObjectType object
    ) external view returns (bool);

    function getObjectCount() external view returns (uint256);

    //nftIdOf
    function getNftId(address objectAddress) external view returns (NftId nftId);
    // nameOf
    function getName(NftId nftId) external view returns (string memory name);

    function ownerOf(NftId nftId) external view returns (address);

    function ownerOf(address contractAddress) external view returns (address);
    // infoOf()
    function getObjectInfo(NftId nftId) external view returns (ObjectInfo memory info);
    // infoOf()
    function getObjectInfo(address object) external view returns (ObjectInfo memory info);

    function isRegistered(NftId nftId) external view returns (bool);

    function isRegistered(address contractAddress) external view returns (bool);

    function getServiceAddress(
        string memory serviceName, 
        VersionPart majorVersion
    ) external view returns (address serviceAddress);

    function getProtocolOwner() external view returns (address);

    function getChainNft() external view returns (IChainNft);
}