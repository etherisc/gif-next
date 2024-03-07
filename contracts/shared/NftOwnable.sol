// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

// import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol"; 

import {ERC165} from "./ERC165.sol";
import {INftOwnable} from "./INftOwnable.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {NftId, zeroNftId} from "../types/NftId.sol";
import {RegistryLinked} from "./RegistryLinked.sol";

contract NftOwnable is
    ERC165,
    RegistryLinked,
    INftOwnable
{
    // keccak256(abi.encode(uint256(keccak256("etherisc.storage.NftOwnable")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 public constant NFT_OWNABLE_STORAGE_LOCATION_V1 = 0x07ebcf49758b6ed3af50fa146bec0abe157c0218fe65dc0874c286e9d5da4f00;

    struct NftOwnableStorage {
        // IRegistry _registry;
        NftId _nftId;
        address _initialOwner; 
    }

    /// @dev enforces msg.sender is owner of nft (or initial owner of nft ownable)
    modifier onlyOwner() {
        if (msg.sender != getOwner()) {
            revert ErrorNotOwner(msg.sender);
        }
        _;
    }


    /// @dev initialization for upgradable contracts
    // used in _initializeRegisterable
    function initializeNftOwnable(
        address initialOwner,
        address registryAddress
    )
        public
        virtual
        onlyInitializing()
    {
        _setInitialOwner(initialOwner);

        initializeRegistryLinked(registryAddress);
        initializeERC165();
        registerInterface(type(INftOwnable).interfaceId);
    }


    function initializeOwner(address initialOwner)
        public
        initializer()
    {
        _setInitialOwner(initialOwner);
        initializeERC165();
        registerInterface(type(INftOwnable).interfaceId);
    }


    /// @dev links this contract to nft after registration
    // needs to be done once per registered contract and 
    // reduces registry calls to check ownership
    // does not need any protection as function can only do the "right thing"
    function linkToRegisteredNftId()
        public
        virtual
    {
        NftOwnableStorage storage $ = _getNftOwnableStorage();

        if ($._nftId.gtz()) {
            revert ErrorAlreadyLinked(address(getRegistry()), $._nftId);
        }

        if (address(getRegistry()) == address(0)) {
            revert ErrorRegistryNotInitialized();
        }

        address contractAddress = address(this);

        if (!getRegistry().isRegistered(contractAddress)) {
            revert ErrorContractNotRegistered(contractAddress);
        }

        $._nftId = getRegistry().getNftId(contractAddress);
    }


    // function getRegistry() public view virtual override returns (IRegistry) {
    //     return _getNftOwnableStorage()._registry;
    // }

    function getNftId() public view virtual override returns (NftId) {
        return _getNftOwnableStorage()._nftId;
    }

    function getInitialOwner() public view returns (address) {
        return _getNftOwnableStorage()._initialOwner;
    }

    function getOwner() public view virtual override returns (address) {
        NftOwnableStorage storage $ = _getNftOwnableStorage();

        if ($._nftId.gtz()) {
            return getRegistry().ownerOf($._nftId);
        }

        return $._initialOwner;
    }

    /// @dev set initialOwner
    /// initial owner may only be set during initialization
    function _setInitialOwner(address initialOwner)
        internal
        virtual
        onlyInitializing()
    {
        if(initialOwner == address(0)) {
            revert ErrorInitialOwnerZero();
        }

        _getNftOwnableStorage()._initialOwner = initialOwner;
    }

    // TODO check if function can be refactored to work with a registry address set in an initializer
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
        NftOwnableStorage storage $ = _getNftOwnableStorage();

        if ($._nftId.gtz()) {
            revert ErrorAlreadyLinked(address(getRegistry()), $._nftId);
        }

        _setRegistry(registryAddress);

        if (!getRegistry().isRegistered(nftOwnableAddress)) {
            revert ErrorContractNotRegistered(nftOwnableAddress);
        }

        $._nftId = getRegistry().getNftId(nftOwnableAddress);

        return $._nftId;
    }


    // function _setRegistry(address registryAddress)
    //     private
    // {
    //     NftOwnableStorage storage $ = _getNftOwnableStorage();

    //     if (address($._registry) != address(0)) {
    //         revert ErrorRegistryAlreadyInitialized(address($._registry));
    //     }

    //     if (registryAddress == address(0)) {
    //         revert ErrorRegistryAddressZero();
    //     }

    //     if (registryAddress.code.length == 0) {
    //         revert ErrorNotRegistry(registryAddress);
    //     }

    //     $._registry = IRegistry(registryAddress);

    //     try $._registry.supportsInterface(type(IRegistry).interfaceId) returns (bool isRegistry) {
    //         if (!isRegistry) {
    //             revert ErrorNotRegistry(registryAddress);
    //         }
    //     } catch {
    //         revert ErrorNotRegistry(registryAddress);
    //     }
    // }


    function _getNftOwnableStorage() private pure returns (NftOwnableStorage storage $) {
        assembly {
            $.slot := NFT_OWNABLE_STORAGE_LOCATION_V1
        }
    }
}