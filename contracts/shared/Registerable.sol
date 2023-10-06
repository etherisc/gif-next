// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {NftId, zeroNftId} from "../types/NftId.sol";
import {ObjectType} from "../types/ObjectType.sol";

import {IRegistry} from "../registry/IRegistry.sol";
import {IRegisterable} from "./IRegisterable.sol";

import {ERC165} from "./ERC165.sol";

abstract contract Registerable is
    ERC165,
    IRegisterable
{
    IRegistry internal immutable _registry;
    NftId internal immutable _parentNftId;
    address internal immutable _initialOwner;
    ObjectType internal immutable _objectType;
    //bytes internal immutable _data;

    modifier onlyOwner() virtual {
        require(
            msg.sender == getOwner(),
            "ERROR:RGB-001:NOT_OWNER"
        );
        _;
    }

    constructor(
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

        _registry = IRegistry(registryAddress);
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
        _initialOwner= msg.sender;
        //_data = data;

        // register support for IRegisterable
        _registerInterface(type(IRegisterable).interfaceId);
    }

    function getRegistry() public view virtual returns (IRegistry registry) {
        return _registry;
    }

    function getOwner() public view virtual returns (address) {
        return _registry.ownerOf(address(this));
    }

    function getNftId() public view virtual returns (NftId nftId) {
        return _registry.getNftId(address(this));
    }

    function getInfo() external view virtual returns (IRegistry.ObjectInfo memory) {
        return _registry.getObjectInfo(address(this));
    }

    function getInitialInfo() public view virtual returns (IRegistry.ObjectInfo memory) {
        return IRegistry.ObjectInfo(
            zeroNftId(),
            _parentNftId,
            _objectType,
            address(this),
            _initialOwner,
            ""
        );
    }
}
