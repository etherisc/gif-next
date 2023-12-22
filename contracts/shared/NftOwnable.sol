// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {INftOwnable} from "./INftOwnable.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {NftId, zeroNftId} from "../types/NftId.sol";

contract NftOwnable is INftOwnable {

    IRegistry internal _registry;
    NftId private _nftId;
    address private _initialOwner; 

    modifier onlyOwner() {
        address owner = getOwner();

        // owner == address(0) is eg uninitialized upgradable contract
        if (owner != address(0) && msg.sender != owner) {
            revert ErrorNotOwner(msg.sender);
        }
        _;
    }

    constructor() {
        _initialOwner = msg.sender;
    }

    /// @dev initialization for upgradable contracts
    function _initializeNftOwnable(
        address initialOwner,
        address registryAddress
    )
        internal
        virtual
    {
        _initialOwner = initialOwner;
        _linkToRegistry(registryAddress);
    }

    /// @dev fetch nft from registry after registration
    function linkToRegisteredNftId() public {
        if (_nftId.gtz()) {
            revert ErrorAlreadyLinked(address(_registry), _nftId);
        }

        if (address(_registry) == address(0)) {
            revert ErrorRegistryNotInitialized();
        }

        address contractAddress = address(this);

        if (!_registry.isRegistered(contractAddress)) {
            revert ErrorContractNotRegistered(contractAddress);
        }

        _nftId = _registry.getNftId(contractAddress);
    }

    // TODO likely need an additinoal internal function for components

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
            revert ErrorAlreadyLinked(address(_registry), _nftId);
        }

        _linkToRegistry(registryAddress);

        if (!_registry.isRegistered(contractAddress)) {
            revert ErrorContractNotRegistered(contractAddress);
        }

        _nftId = _registry.getNftId(contractAddress);

        return _nftId;
    }


    function getRegistry() public view virtual override returns (IRegistry) {
        return _registry;
    }


    function getNftId() public view virtual override returns (NftId) {
        return _nftId;
    }


    function getOwner() public view virtual override returns (address) {
        if (_nftId.gtz()) {
            return _registry.ownerOf(_nftId);
        }

        return _initialOwner;
    }


    function _linkToRegistry(address registryAddress)
        internal
    {
        if (address(_registry) != address(0)) {
            revert ErrorRegistryAlreadyInitialized(address(_registry));
        }

        if (registryAddress == address(0)) {
            revert ErrorRegistryAddressZero();
        }

        _registry = IRegistry(registryAddress);

        if (!_registry.supportsInterface(type(IRegistry).interfaceId)) {
            revert ErrorNotRegistry(registryAddress);
        }
    }
}