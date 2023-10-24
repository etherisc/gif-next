// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Version, VersionPart, VersionLib} from "../../contracts/types/Version.sol";
import {NftId} from "../../contracts/types/NftId.sol";
import {ObjectType} from "../../contracts/types/ObjectType.sol";

import {IChainNft} from "../../contracts/registry/IChainNft.sol";
import {ChainNft} from "../../contracts/registry/ChainNft.sol";
import {RegistryUpgradeable} from "../../contracts/registry/RegistryUpgradeable.sol";


contract RegistryV02 is RegistryUpgradeable
{
    // @custom:storage-location erc7201:etherisc.storage.Registry
    struct RegistryStorageV2 {

        // copy of V1
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
    
    /*struct RegistryStorageV2 {
        uint dataV2;
    }*/

    // the same address as V1
    // keccak256(abi.encode(uint256(keccak256("etherisc.storage.Registry")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant RegistryStorageLocationV2 = 0x6548007c3f4340f82f348c576c0ff69f4f529cadd5ad41f96aae61abceeaa300;

    // or use internal _getRegistryStorageV1() or _getRegistryStorage() ???
    function _getRegistryStorageV2() private pure returns (RegistryStorageV2 storage $) {
        assembly {
            $.slot := RegistryStorageLocationV2
        }
    }

    function getRegistryDataV2() public view returns(uint) {
        RegistryStorageV2 storage $ = _getRegistryStorageV2();
        return $.dataV2;
    }

    
    function initialize(
        address implementation, 
        address activatedBy,
        bytes memory initializationData
    )
        public
        virtual
        override
        initializer
    {
        // activate V2
        _activate(implementation, activatedBy);

        address protocolOwner = abi.decode(initializationData, (address));
        //  = getDataV1(activationData);

        _initializeV02(protocolOwner);
    }  

    function upgrade(
        address newImplementation, 
        address activatedBy,
        bytes memory upgradeData
    )
        external
        virtual override
        reinitializer(VersionLib.toUint64(getVersion()))
    {
        // activate V2
        _activate(newImplementation, activatedBy);

        address protocolOwner = abi.decode(upgradeData, (address));
        //  = getDataV1(activationData);

        _upgradeFromV01(protocolOwner);
    }

    function getVersion() public pure override returns (Version)
    {
        return VersionLib.toVersion(1, 1, 0);
    } 

    // custom initializer is cheaper in terms of gas usage
    // but more expensive in terms of code space accupied
    function _initializeV02(address protocolOwner)
        internal
    {
        _initializeV01(protocolOwner);

        _upgradeFromV01(protocolOwner);
    }

    function _upgradeFromV01(address protocolOwner)
        private
        onlyInitializing
    {
        // V02 specific 
        RegistryStorageV2 storage $ = _getRegistryStorageV2();

        $.dataV2 = type(uint).max; 
    }
}