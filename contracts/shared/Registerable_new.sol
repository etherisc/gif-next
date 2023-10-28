// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {NftId, zeroNftId} from "../types/NftId.sol";
import {ObjectType} from "../types/ObjectType.sol";

//import {IRegistry} from "../registry/IRegistry.sol";
//import {IRegisterable} from "./IRegisterable.sol";
import {IRegistry_new} from "../registry/IRegistry_new.sol";
import {IRegisterable_new} from "./IRegisterable_new.sol";
import {Versionable} from "./Versionable.sol";

import {ERC165} from "./ERC165.sol";

// Stateless Registerable is easyer to integrate with Versionable  ??
abstract contract Registerable_new is
    ERC165,
    IRegisterable_new,
    Versionable
{
    // keccak256(abi.encode(uint256(keccak256("gif-next.contracts.shared.Registerable.sol")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 public constant REGISTERABLE_LOCATION_V1 = 0x6548007c3f4340f82f348c576c0ff69f4f529cadd5ad41f96aae61abceeaa300;

    struct RegisterableStorage {
        IRegistry_new _registry;
        //NftId _parentNftId;
        //address _initialOwner;
        //ObjectType _objectType;
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

    function _initialize_registerable(IRegistry_new registry)
        internal
        onlyInitializing
        virtual
    {
        RegisterableStorage storage $ = _getRegisterableStorage();
        $._registry = registry;
    }

    /*constructor(
        address registryAddress,
        NftId parentNftId,
        ObjectType objectType
    )
        ERC165()
    {
        // TODO validate objectType

        require(
            address(registryAddress) != address(0),
            "ERROR:RGB-010:REGISTRY_ZERO"
        );

        _registry = IRegistry_My(registryAddress);
        require(
            _registry.supportsInterface(type(IRegistry).interfaceId),
            "ERROR:RGB-011:NOT_REGISTRY"
        );

        
        require(
            _registry.isRegistered(parentNftId),
            "ERROR:RGB-012:PARENT_NOT_REGISTERED"
        );

        _parentNftId = parentNftId;
        _objectType = objectType;
        _initialOwner = msg.sender;
        //_data = data;

        // register support for IRegisterable
        _registerInterface(type(IRegisterable).interfaceId);
    }*/

    // from IOwnable
    function getOwner() public view virtual returns (address) {
        return _getRegisterableStorage()._registry.ownerOf(address(this));
    }

    // from IRegistry
    function getRegistry() public view virtual returns (IRegistry_new registry) {
        return _getRegisterableStorage()._registry;
    }

    function getNftId() public view virtual returns (NftId nftId) {
        return _getRegisterableStorage()._registry.getNftId(address(this));
    }

    function getInfo() external view virtual returns (IRegistry_new.ObjectInfo memory) {
        return _getRegisterableStorage()._registry.getObjectInfo(address(this));
    }
    // each registerable must define 
    function getInitialInfo() public pure virtual returns (IRegistry_new.ObjectInfo memory);
    /*function getInitialInfo() public view virtual returns (IRegistry.ObjectInfo memory) {
        return IRegistry.ObjectInfo(
            zeroNftId(),
            _parentNftId,
            _objectType,
            address(this),
            _initialOwner,
            ""
        );
    }
    */
}