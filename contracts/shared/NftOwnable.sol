// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {INftOwnable} from "./INftOwnable.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {NftId, zeroNftId} from "../types/NftId.sol";

contract NftOwnable is INftOwnable {

    IRegistry internal _registry;
    NftId private _nftId;
    address private _initialOwner; 

    /// @dev enforces msg.sender is owner of nft (or initial owner of nft ownable)
    modifier onlyOwner() {
        if (msg.sender != getOwner()) {
            revert ErrorNotOwner(msg.sender);
        }
        _;
    }

    constructor() {
        _initialOwner = msg.sender;
    }

    function setInitialOwner(address initialOwner) public
        onlyOwner()
    {
        if (_nftId.gtz()) {
            revert ErrorAlreadyLinked(address(_registry), _nftId);
        }

        _initialOwner = initialOwner;
    }

    /// @dev links this contract to nft after registration
    // needs to be done once per registered contract and 
    // reduces registry calls to check ownership
    // does not need any protection as function can only do the "right thing"
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


    /// @dev initialization for upgradable contracts
    // used in _initializeRegisterable
    function _initializeNftOwnable(
        address initialOwner,
        address registryAddress
    )
        internal
        virtual
    {
        require(initialOwner > address(0), "NftOwnable: initial owner is 0");
        _initialOwner = initialOwner;
        _setRegistry(registryAddress);
    }


    /// @dev used in constructor of registry service manager
    // links ownership of registry service manager ot nft owner of registry service
    function _linkToNftOwnable(
        address registryAddress,
        address nftOwnableAddress
    )
        internal
        onlyOwner()
        returns (NftId)
    {
        if (_nftId.gtz()) {
            revert ErrorAlreadyLinked(address(_registry), _nftId);
        }

        _setRegistry(registryAddress);

        if (!_registry.isRegistered(nftOwnableAddress)) {
            revert ErrorContractNotRegistered(nftOwnableAddress);
        }

        _nftId = _registry.getNftId(nftOwnableAddress);

        return _nftId;
    }


    function _setRegistry(address registryAddress)
        private
    {
        if (address(_registry) != address(0)) {
            revert ErrorRegistryAlreadyInitialized(address(_registry));
        }

        if (registryAddress == address(0)) {
            revert ErrorRegistryAddressZero();
        }

        if (registryAddress.code.length == 0) {
            revert ErrorNotRegistry(registryAddress);
        }

        _registry = IRegistry(registryAddress);

        try _registry.supportsInterface(type(IRegistry).interfaceId) returns (bool isRegistry) {
            if (!isRegistry) {
                revert ErrorNotRegistry(registryAddress);
            }
        } catch {
            revert ErrorNotRegistry(registryAddress);
        }
    }
}