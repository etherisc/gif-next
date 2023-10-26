// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Version, VersionPart, VersionLib} from "../../contracts/types/Version.sol";
import {NftId, toNftId} from "../../contracts/types/NftId.sol";
import {ObjectType} from "../../contracts/types/ObjectType.sol";

import {IChainNft} from "../../contracts/registry/IChainNft.sol";
import {ChainNft} from "../../contracts/registry/ChainNft.sol";
import {RegistryUpgradeable} from "../../contracts/registry/RegistryUpgradeable.sol";


contract RegistryV02 is RegistryUpgradeable
{
    // @custom:storage-location erc7201:etherisc.storage.Registry
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

        // V2 addition
        uint dataV2;
    }
    
    function _getStorageV02() private pure returns (StorageV2 storage $) {
        assembly {
            $.slot := locationV1
        }
    }

    function getDataV2() public view returns(uint) {
        StorageV2 storage $ = _getStorageV02();
        return $.dataV2;
    }

    function getVersion() 
        public 
        pure 
        virtual override 
        returns (Version)
    {
        return VersionLib.toVersion(1, 1, 0);
    } 

    // do not define if no changes to storage
    function _initialize(bytes memory data)
        internal
        virtual override
        onlyInitializing
    {
        // copy paste from V1 
        // change getter function
        address protocolOwner = abi.decode(data, (address));
        StorageV2 storage $ = _getStorageV02();

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

        //new in this version 
        $.dataV2 = type(uint).max;
    }

    function _upgrade(bytes memory data)
        internal
        virtual override
        onlyInitializing
    {
        // add changes 
        StorageV2 storage $ = _getStorageV02();
        $.dataV2 = type(uint).max; 
    }
}