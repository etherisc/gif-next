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

    modifier onlyOwner() virtual {
        requireSenderIsOwner();
        _;
    }

    constructor(
        address registryAddress,
        NftId parentNftId
    )
        ERC165()
    {
        require(
            address(registryAddress) != address(0),
            "ERROR:RGB-010:REGISTRY_ZERO"
        );

        _registry = IRegistry(registryAddress);
        require(
            _registry.supportsInterface(type(IRegistry).interfaceId),
            "ERROR:RGB-011:NOT_REGISTRY"
        );

        _parentNftId = parentNftId;
        require(
            _registry.isRegistered(_parentNftId),
            "ERROR:RGB-012:PARENT_NOT_REGISTERED"
        );

        _initialOwner = msg.sender;

        // register support for IRegisterable
        _registerInterface(type(IRegisterable).interfaceId);
    }

    // from IRegistryLinked
    function register() public onlyOwner virtual override returns (NftId nftId) {
        return _registry.register(address(this));
    }

    function getRegistry() public view virtual override returns (IRegistry registry) {
        return _registry;
    }

    function getInitialOwner() public view override returns (address initialOwner) {
        return _initialOwner;
    }

    function getOwner() public view override returns (address owner) {
        NftId nftId = getNftId();
        if(_registry.getNftId(address(this)) == zeroNftId()) {
            return _initialOwner;
        }

        return _registry.getOwner(nftId);
    }

    function getNftId() public view override returns (NftId nftId) {
        return _registry.getNftId(address(this));
    }

    function getParentNftId() public view override returns (NftId nftId) {
        return _parentNftId;
    }

    function getData() public view virtual override returns (bytes memory data) {
        return "";
    }

    function requireSenderIsOwner() public view virtual override returns (bool senderIsOwner){
        require(
            msg.sender == getOwner(),
            "ERROR:RGB-020:NOT_OWNER"
        );

        return true;
    }

}
