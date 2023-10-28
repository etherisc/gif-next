// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Version, VersionPart, VersionLib} from "../../contracts/types/Version.sol";
import {NftId, toNftId} from "../../contracts/types/NftId.sol";
import {ObjectType} from "../../contracts/types/ObjectType.sol";

import {IChainNft} from "../../contracts/registry/IChainNft.sol";
import {ChainNft} from "../../contracts/registry/ChainNft.sol";
import {Registry} from "../../contracts/registry/Registry.sol";

// V02 is used to test upgradeability gas usage/byte code footprint - both MUST BE constant, the same as with V01
// 1) introduces no changes to storage 
// 2) uses _initialize() from V01
// 3) implements empty _upgrade()
contract RegistryV02 is Registry
{
    // @custom:storage-location erc7201:gif-next.contracts.registry.Registry.sol
    struct StorageV2 {
        // copy pasted from V1
        mapping(NftId nftId => ObjectInfo info) _info;
        mapping(address object => NftId nftId) _nftIdByAddress;
        mapping(ObjectType objectType => bool) _isValidType;
        mapping(ObjectType objectType => mapping(ObjectType objectParentType => bool)) _isValidParentType;

        mapping(NftId nftId => string stringValue) _string;
        mapping(bytes32 serviceNameHash => mapping(VersionPart majorVersion => address service)) _service;

        NftId _nftId;
        IChainNft _chainNft;
        ChainNft _chainNftInternal;
        address _initialOwner;

        address _protocolOwner;
    }

    function getVersion() 
        public 
        pure 
        virtual override 
        returns (Version)
    {
        return VersionLib.toVersion(1, 1, 0);
    } 

    function _upgrade(bytes memory data)
        internal
        onlyInitializing
        virtual override
    {}

    function _getStorageV2() private pure returns (StorageV2 storage $) {
        assembly {
            $.slot := REGISTRY_LOCATION_V1
        }
    }
}