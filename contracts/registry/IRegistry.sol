// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {NftId} from "../types/NftId.sol";
import {ObjectType} from "../types/ObjectType.sol";

interface IOwnable {
    function getOwner() external view returns (address owner);
}

interface IRegistryLinked {
    event LogDebug(uint256 idx, address module, string comment);

    function getRegistry() external view returns (IRegistry registry);
}

interface IRegisterable is IOwnable, IRegistryLinked {
    function register() external returns (NftId nftId);

    function getNftId() external view returns (NftId nftId);

    function getParentNftId() external view returns (NftId parentNftId);

    function getType() external view returns (ObjectType objectType);

    function getData() external view returns (bytes memory data);

    function isRegisterable() external pure returns (bool);

    function getInitialOwner() external view returns (address initialOwner);

    function isRegistered() external view returns (bool);
}

interface IRegistry {
    struct RegistryInfo {
        NftId nftId;
        NftId parentNftId;
        ObjectType objectType;
        address objectAddress;
        address initialOwner;
    }

    function register(address objectAddress) external returns (NftId nftId);

    function registerObjectForInstance(
        NftId parentNftid,
        ObjectType objectType,
        address initialOwner
    ) external returns (NftId nftId);

    function getObjectCount() external view returns (uint256);

    function getNftId(
        address objectAddress
    ) external view returns (NftId nftId);

    function getInfo(
        NftId nftId
    ) external view returns (RegistryInfo memory info);

    function getOwner(NftId nftId) external view returns (address ownerAddress);

    function isRegistered(address objectAddress) external view returns (bool);

    function getNftAddress() external view returns (address nft);
}
