// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

//import {Initializable} from "@openzeppelin5/contracts/proxy/utils/Initializable.sol";

import {Version, VersionPart, VersionLib} from "../../contracts/types/Version.sol";
import {NftId} from "../../contracts/types/NftId.sol";
import {ObjectType} from "../../contracts/types/ObjectType.sol";

import {IChainNft} from "../../contracts/registry/IChainNft.sol";
import {ChainNft} from "../../contracts/registry/ChainNft.sol";
import {RegistryUpgradeable} from "../../contracts/registry/RegistryUpgradeable.sol";


contract RegistryV02 is RegistryUpgradeable
{

    //--- constants -----------------------------------------------------------------
    // the same address as V1
    // keccak256(abi.encode(uint256(keccak256("etherisc.storage.Registry")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant STORAGE_LOCATION_V2 = 0x6548007c3f4340f82f348c576c0ff69f4f529cadd5ad41f96aae61abceeaa300;

    //--- storage layout -------------------------------------------------------------

    // @custom:storage-location erc7201:etherisc.storage.Registry
    struct StorageV2 {

        // copy of V1
        mapping(NftId nftId => ObjectInfo info) info;
        mapping(address object => NftId nftId) nftIdByAddress;
        mapping(ObjectType objectType => bool) isValidType;
        mapping(ObjectType objectType => mapping(ObjectType objectParentType => bool)) isValidParentType;

        mapping(NftId nftId => string stringValue) name;
        mapping(bytes32 serviceNameHash => mapping(VersionPart majorVersion => address service)) service;

        NftId nftId;
        IChainNft chainNft;
        ChainNft chainNftInternal;
        address initialOwner;
        address protocolOwner;

        // V2 addition
        uint dataV2;
    }
    //--- state --------------------------------------------------------------------

    //--- external/public state changing functions  --------------------------------

    //--- external/public view and pure functions  --------------------------------

    function getDataV2()
        public
        view
        returns(uint)
    {
        return _getStorageV2().dataV2;
    }

    //--- from Versionable --------------------------------------
    function initialize(
        address implementation, 
        address activatedBy,
        bytes memory data
    )
        public
        virtual override
        initializer
    {
        _updateVersionHistory(implementation, activatedBy);
        _initializeV02(data);
    }  

    function upgrade(
        address newImplementation, 
        address activatedBy,
        bytes memory data
    )
        external
        virtual override
        reinitializer(VersionLib.toUint64(getVersion()))
    {
        _updateVersionHistory(newImplementation, activatedBy);
        _upgradeFromV01();
    }

    function getVersion()
        public
        pure
        override
        returns (Version)
    {
        return VersionLib.toVersion(1, 1, 0);
    } 


    function _initializeV02(bytes memory data)
        internal
        onlyInitializing
    {
        _initializeV01(data);
        _upgradeFromV01();
    }

    function _upgradeFromV01()
        private
        onlyInitializing
    {
        StorageV2 storage $ = _getStorageV2();
        $.dataV2 = type(uint).max; 
    }

    function _getStorageV2()
        private
        pure 
        returns (StorageV2 storage s)
    {
        // solhint-disable no-inline-assembly
        assembly {
            s.slot := STORAGE_LOCATION_V2
        }
    }

}