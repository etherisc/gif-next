// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IOwnable} from "./IOwnable.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {NftId, zeroNftId} from "../types/NftId.sol";

contract NftOwnable is
    IOwnable
{
    error ErrorNftOwnableUnauthorized(address account);

    error ErrorAlreadyInitialized(address registry, NftId nftId);
    error ErrorRegistryAlreadyInitialized(address registry);
    error ErrorRegistryNotInitialized();
    error ErrorRegistryAddressZero();
    error ErrorContractNotRegistered(address contractAddress);

    IRegistry internal _registry;
    NftId private _nftId;
    address private _initialOwner; 

    modifier onlyOwner() {
        address owner = getOwner();

        // owner == address(0) is eg uninitialized upgradable contract
        if (owner != address(0) && msg.sender != owner) {
            revert ErrorNftOwnableUnauthorized(msg.sender);
        }
        _;
    }

    constructor() {
        _initialOwner = msg.sender;
    }

    // function only needed during bootstrapping on a new chain
    function linkToRegistry(
        address registryAddress,
        address contractAddress
    )
        internal
        onlyOwner()
        returns (NftId)
    {
        if (_nftId.gtz()) {
            revert ErrorAlreadyInitialized(address(_registry), _nftId);
        }

        if (address(_registry) != address(0)) {
            revert ErrorRegistryAlreadyInitialized(address(_registry));
        }

        if (registryAddress == address(0)) {
            revert ErrorRegistryAddressZero();
        }

        _registry = IRegistry(registryAddress);

        if (!_registry.isRegistered(contractAddress)) {
            revert ErrorContractNotRegistered(contractAddress);
        }

        _nftId = _registry.getNftId(contractAddress);

        return _nftId;
    }


    function getRegistry() external view returns (IRegistry) {
        return _registry;
    }


    function getNftId() external view returns (NftId) {
        return _nftId;
    }


    function getOwner() public view returns (address) {
        if (_nftId.gtz()) {
            return _registry.ownerOf(_nftId);
        }

        return _initialOwner;
    }
}