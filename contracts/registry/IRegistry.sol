// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {NftId} from "../types/NftId.sol";
import {ObjectType} from "../types/ObjectType.sol";
import {VersionPart} from "../types/Version.sol";
import {IChainNft} from "./IChainNft.sol";

interface IRegistry is IERC165 {
    struct ObjectInfo {
        NftId nftId;
        NftId parentNftId;
        ObjectType objectType;
        address objectAddress;
        address initialOwner;
        bytes data;
    }

    function register(address objectAddress) external returns (NftId nftId);

    function registerObjectForInstance(
        NftId parentNftid,
        ObjectType objectType,
        address initialOwner,
        bytes memory data
    ) external returns (NftId nftId);

    function getServiceAddress(string memory serviceName, VersionPart majorVersion) external view returns (address serviceAddress);

    function getObjectCount() external view returns (uint256);

    function getNftId(
        address objectAddress
    ) external view returns (NftId nftId);

    function getObjectInfo(
        NftId nftId
    ) external view returns (ObjectInfo memory info);

    function getName(
        NftId nftId
    ) external view returns (string memory name);

    function getOwner(NftId nftId) external view returns (address ownerAddress);

    function isRegistered(NftId nftId) external view returns (bool);

    function isRegistered(address objectAddress) external view returns (bool);

    function getChainNft() external view returns (IChainNft);
}
