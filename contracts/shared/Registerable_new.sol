// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin5/contracts/proxy/utils/Initializable.sol"; 

import {NftId, zeroNftId} from "../types/NftId.sol";
import {ObjectType} from "../types/ObjectType.sol";

//import {IRegistry} from "../registry/IRegistry.sol";
//import {IRegisterable} from "./IRegisterable.sol";
import {IRegistry_new} from "../registry/IRegistry_new.sol";
import {IRegisterable_new} from "./IRegisterable_new.sol";
import {Versionable} from "./Versionable.sol";

import {ERC165} from "./ERC165.sol";

abstract contract Registerable_new is
    ERC165, // TODO not v5, not upgradeable 
    IRegisterable_new,
    Initializable
{
    // keccak256(abi.encode(uint256(keccak256("gif-next.contracts.shared.Registerable.sol")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 public constant REGISTERABLE_LOCATION_V1 = 0x6548007c3f4340f82f348c576c0ff69f4f529cadd5ad41f96aae61abceeaa300;

    struct RegisterableStorage {
        IRegistry_new _registry;
        NftId _parentNftId;
        address _initialOwner;
        ObjectType _objectType;
        //bytes _data;
    }

    function _getRegisterableStorage() private pure returns (RegisterableStorage storage $) {
        assembly {
            $.slot := REGISTERABLE_LOCATION_V1
        }
    }

    modifier onlyOwner() virtual {
        require(
            msg.sender == getOwner(),
            "ERROR:RGB-001:NOT_OWNER"
        );
        _;
    }

    function _initializeRegisterable(
        address registryAddress,
        NftId parentNftId,
        ObjectType objectType
        //bytes memory data
    )
        internal
        onlyInitializing
        virtual
    {
        require(
            registryAddress != address(0),
            "ERROR:RGB-010:REGISTRY_ZERO"
        );

        IRegistry_new registry = IRegistry_new(registryAddress);
        require(
            registry.supportsInterface(type(IRegistry_new).interfaceId),
            "ERROR:RGB-011:NOT_REGISTRY"
        );

        RegisterableStorage storage $ = _getRegisterableStorage();
        $._registry = registry;
        $._parentNftId = parentNftId;
        $._objectType = objectType;
        $._initialOwner = msg.sender; // TODO correct? if during proxy deployment only?
        //$._data = data;

        _registerInterface(type(Registerable_new).interfaceId);
    }

    // from IOwnable
    function getOwner() public view virtual returns (address) {
        return _getRegisterableStorage()._registry.ownerOf(address(this));
    }

    // from IRegisterable
    function getRegistry() public view virtual returns (IRegistry_new registry) {
        return _getRegisterableStorage()._registry;
    }

    function getNftId() public view virtual returns (NftId nftId) {
        return _getRegisterableStorage()._registry.getNftId(address(this));
    }

    /*function getInfo() public view virtual returns (IRegistry_new.ObjectInfo memory) {
        return _getRegisterableStorage()._registry.getObjectInfo(address(this));
    }

    function getInitialInfo() public view virtual returns (IRegistry_new.ObjectInfo memory) {
        RegisterableStorage storage $ = _getRegisterableStorage();
        return IRegistry_new.ObjectInfo(
            zeroNftId(),
            $._parentNftId,
            $._objectType,
            address(this), 
            $._initialOwner,
            ""
        );
    }*/

    function getInfo() 
        public 
        view 
        virtual 
        returns (IRegistry_new.ObjectInfo memory, bytes memory data) 
    {
        return (
            _getRegisterableStorage()._registry.getObjectInfo(address(this)),
            bytes("")
        );
    }

    function getInitialInfo() 
        public 
        view 
        virtual 
        returns (IRegistry_new.ObjectInfo memory, bytes memory data) 
    {
        RegisterableStorage storage $ = _getRegisterableStorage();
        return (
            IRegistry_new.ObjectInfo(
                zeroNftId(),
                $._parentNftId,
                $._objectType,
                address(this), 
                $._initialOwner,
                ""
            ),
            bytes("")
        );
    }
}