// SPDX-License-Identifier: Apache-2.0
/*pragma solidity ^0.8.20;

import {Version, VersionPart, VersionLib} from "../../contracts/types/Version.sol";
import {NftId, toNftId} from "../../contracts/types/NftId.sol";
import {ObjectType} from "../../contracts/types/ObjectType.sol";

import {IChainNft} from "../../contracts/registry/IChainNft.sol";
import {ChainNft} from "../../contracts/registry/ChainNft.sol";
import {RegistryV03} from "./RegistryV03.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";

// Versionable::_updateVersionHistory upgrade
// private function upgrade -> make old version unreachebale
// need to override intialize() and upgrade() -> but they are not (MUST not be) virtual....

contract RegistryV04 is RegistryV03
{
    // the same as V1
    // keccak256(abi.encode(uint256(keccak256("gif-next.contracts.registry.Registry.sol")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant REGISTRY_LOCATION_V4 = 0x6548007c3f4340f82f348c576c0ff69f4f529cadd5ad41f96aae61abceeaa300;

    // @custom:storage-location erc7201:gif-next.contracts.registry.Registry.sol
    struct StorageV4 {
        // copy pasted from V3
        mapping(NftId nftId => ObjectInfo info) _info;
        mapping(address object => NftId nftId) _nftIdByAddress;

        mapping(NftId registrator => mapping(
                ObjectType objectType => bool)) _isApproved;

        mapping(ObjectType objectType => mapping(
                ObjectType parentType => bool)) _isValidCombination;

        mapping(NftId nftId => string stringValue) _string;
        mapping(bytes32 serviceNameHash => mapping(
                VersionPart majorVersion => address service)) _service;

        NftId _nftId;
        IChainNft _chainNft;
        ChainNft _chainNftInternal;

        address _protocolOwner;

        uint dataV3;
    }

    function getVersion() 
        public 
        pure 
        virtual override 
        returns (Version)
    {
        return VersionLib.toVersion(1, 3, 0);
    } 

    // TODO using functions from version 1...
    function _initialize(address protocolOwner, bytes memory data)
        internal
        initializer
        virtual override
    {
        StorageV4 storage $ = _getStorageV4();

        require(
            address($._chainNft) == address(0),
            "ERROR:REG-005:ALREADY_INITIALIZED"
        );
        $._protocolOwner = protocolOwner;

        // deploy NFT 
        $._chainNftInternal = new ChainNft(address(this));// adds 10kb to deployment size
        $._chainNft = IChainNft($._chainNftInternal);
        
        // initial registry setup
        _registerProtocol();
        $._nftId = _registerRegistry();

        // set object parent relations
        _setupValidObjectParentCombinations();

        _registerInterface(type(IRegistry).interfaceId);

        // V3 addition
        $.dataV3 = type(uint).max;
    }

    function _upgrade(bytes memory data)
        internal
        virtual override
        onlyInitializing
    {
        // new changes 
    }

    function _getStorageV4() private pure returns (StorageV4 storage $) {
        assembly {
            $.slot := REGISTRY_LOCATION_V4
        }
    }
}*/