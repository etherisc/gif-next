// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Version, VersionPart, VersionLib} from "../../contracts/types/Version.sol";
import {NftId, toNftId} from "../../contracts/types/NftId.sol";
import {ObjectType} from "../../contracts/types/ObjectType.sol";

import {IChainNft} from "../../contracts/registry/IChainNft.sol";
import {ChainNft} from "../../contracts/registry/ChainNft.sol";
import {RegistryV02} from "./RegistryV02.sol";

contract RegistryV03 is RegistryV02
{
    // @custom:storage-location erc7201:gif-next.contracts.registry.Registry.sol
    struct StorageV3 {

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

        // new vars
        uint dataV3;
    }

    function _getStorageV3() private pure returns (StorageV3 storage $) {
        assembly {
            $.slot := LOCATION_V1
        }
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
        // copy paste from V1 
        // change getter function
        address protocolOwner = abi.decode(data, (address));
        StorageV3 storage $ = _getStorageV3();

        $._initialOwner = msg.sender;
        $._protocolOwner = protocolOwner;

        $._chainNftInternal = new ChainNft(address(this));// adds 10kb to deployment size
        $._chainNft = IChainNft($._chainNftInternal);
        
        // initial registry setup
        _registerProtocol();
        $._nftId = _registerRegistry();

        // setup rules for further registrations
        _setupValidTypes();
        _setupValidParentTypes();

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

    // new func
    function getDataV3() public view returns(uint) {
        StorageV3 storage $ = _getStorageV3();
        return $.dataV3;
    }
}