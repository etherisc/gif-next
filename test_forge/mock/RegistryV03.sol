// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Version, VersionPart, VersionLib} from "../../contracts/types/Version.sol";
import {NftId, toNftId} from "../../contracts/types/NftId.sol";
import {ObjectType} from "../../contracts/types/ObjectType.sol";

import {IChainNft} from "../../contracts/registry/IChainNft.sol";
import {ChainNft} from "../../contracts/registry/ChainNft.sol";
import {RegistryV02} from "./RegistryV02.sol";

import {ObjectType, PROTOCOL, REGISTRY, TOKEN, SERVICE, INSTANCE, STAKE, PRODUCT, DISTRIBUTION, ORACLE, POOL, POLICY, BUNDLE} from "../../contracts/types/ObjectType.sol";

contract RegistryV03 is RegistryV02
{
    // the same as V1
    // keccak256(abi.encode(uint256(keccak256("gif-next.contracts.registry.Registry.sol")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant REGISTRY_LOCATION_V3 = 0x6548007c3f4340f82f348c576c0ff69f4f529cadd5ad41f96aae61abceeaa300;

    // @custom:storage-location erc7201:gif-next.contracts.registry.Registry.sol
    struct StorageV3 {
        // copy pasted from V1
        mapping(NftId nftId => ObjectInfo info) _info;
        mapping(address object => NftId nftId) _nftIdByAddress;

        mapping(NftId registrator => mapping(
                ObjectType objectType => bool)) _isAllowed;

        mapping(ObjectType objectType => mapping(
                ObjectType parentType => bool)) _isValidParentType;

        mapping(NftId nftId => string stringValue) _string;
        mapping(bytes32 serviceNameHash => mapping(
                VersionPart majorVersion => address service)) _service;

        NftId _nftId;
        IChainNft _chainNft;
        ChainNft _chainNftInternal;

        address _protocolOwner;

        // new vars
        uint dataV3;
    }

    // new func
    function getDataV3() public view returns(uint) {
        StorageV3 storage $ = _getStorageV3();
        return $.dataV3;
    }

    function getVersion() 
        public 
        pure 
        virtual override 
        returns (Version)
    {
        return VersionLib.toVersion(1, 2, 0);
    } 

    function _initialize(bytes memory data)
        internal
        onlyInitializing
        virtual override
    {
        address protocolOwner = abi.decode(data, (address));
        StorageV3 storage $ = _getStorageV3();

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

        // set default allowance for registry owner
        _setupAllowance();

        // new addition
        $.dataV3 = type(uint).max;
    }

    function _upgrade(bytes memory data)
        internal
        virtual override
        onlyInitializing
    {
        // new changes 
        StorageV3 storage $ = _getStorageV3();
        $.dataV3 = type(uint).max; 
    }

    function _getStorageV3() private pure returns (StorageV3 storage $) {
        assembly {
            $.slot := REGISTRY_LOCATION_V3
        }
    }
}