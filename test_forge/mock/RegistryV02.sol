// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Version, VersionPart, VersionLib} from "../../contracts/types/Version.sol";
import {NftId, toNftId} from "../../contracts/types/NftId.sol";
import {ObjectType} from "../../contracts/types/ObjectType.sol";

import {IChainNft} from "../../contracts/registry/IChainNft.sol";
import {ChainNft} from "../../contracts/registry/ChainNft.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";

// V02 is used to test upgradeability gas usage/byte code footprint - both MUST BE constant, mostly the same as with V01
// 1) introduces no changes to storage and code
// 2) defines new storage slot constant with the same address, defines new getter
// 2) copy pastes storage struct from V01, chages only the name
// 3) copy pastes _initialize() from V01, changes only the getter 
// 4) implements empty _upgrade()
contract RegistryV02 is Registry
{
    // the same as V1
    // keccak256(abi.encode(uint256(keccak256("gif-next.contracts.registry.Registry.sol")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant REGISTRY_LOCATION_V2 = 0x6548007c3f4340f82f348c576c0ff69f4f529cadd5ad41f96aae61abceeaa300;

    // @custom:storage-location erc7201:gif-next.contracts.registry.Registry.sol
    struct StorageV2 {
        // copy pasted from V1
        mapping(NftId nftId => IRegistry.ObjectInfo info) _info;
        mapping(address object => NftId nftId) _nftIdByAddress;

        mapping(NftId registrator => mapping(
                ObjectType objectType => bool)) _isApproved;

        mapping(ObjectType objectType => mapping(
                ObjectType parentType => bool)) _isValidParentType;

        mapping(NftId nftId => string stringValue) _string;
        mapping(bytes32 serviceNameHash => mapping(
                VersionPart majorVersion => address service)) _service;

        NftId _nftId;
        IChainNft _chainNft;
        ChainNft _chainNftInternal;

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

    function _initialize(address protocolOwner, bytes memory data)
        internal
        onlyInitializing
        virtual override
    {
        StorageV2 storage $ = _getStorageV2();

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
        _setupValidParentTypes();
    }

    function _upgrade(bytes memory data)
        internal
        onlyInitializing
        virtual override
    {}

    function _getStorageV2() private pure returns (StorageV2 storage $) {
        assembly {
            $.slot := REGISTRY_LOCATION_V2
        }
    }
}