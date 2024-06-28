// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;


import {NftId, NftIdLib} from "../type/NftId.sol";
import {VersionPart} from "../type/Version.sol";
import {ObjectType, REGISTRY} from "../type/ObjectType.sol";

import {IGlobalRegistry} from "./IGlobalRegistry.sol";
import {Registry} from "./Registry.sol";
import {RegistryAdmin} from "./RegistryAdmin.sol";
import {MainnetContract} from "../shared/MainnetContract.sol";

contract GlobalRegistry is
    MainnetContract, 
    Registry,
    IGlobalRegistry
{

    error ErrorGlobalRegistryChainRegistryAlreadyRegistered(uint chainId, address chainRegistry);
    error ErrorGlobalRegistryChainRegistryAddressInvalid(uint chainId, address chainRegistry);

    mapping(uint chanId => address registry) _registryAddressByChainId;
    uint256[] _chainId;

    constructor(RegistryAdmin admin) Registry(admin, address(this)) 
    {}

    /// @dev registers a registry contract for a specified chain
    //  only one chain registry per chain
    //  each chain registry have unique address (sort of share same address space)
    function registerChainRegistry(uint chainId, address chainRegistryAddress)
        external
        restricted
        returns (NftId chainRegistryNftId)
    {
        // TODO allow for the same address to be registered on multiple chains
        if(_nftIdByAddress[chainRegistryAddress] != NftIdLib.zero()) {
            revert ErrorGlobalRegistryChainRegistryAddressInvalid(chainId, chainRegistryAddress);
        }

        // calculate chain registry token id
        uint chainRegistryId = _chainNft.calculateTokenId(REGISTRY_TOKEN_SEQUENCE_ID, chainId);
        chainRegistryNftId = NftIdLib.toNftId(chainRegistryId);

        _info[chainRegistryNftId] = ObjectInfo({
            nftId: chainRegistryNftId,
            parentNftId: _registryNftId,
            objectType: REGISTRY(),
            isInterceptor: false,
            objectAddress: chainRegistryAddress, // TODO consider "chainId:address" format
            initialOwner: NFT_LOCK_ADDRESS,
            data: ""  
        });

        _nftIdByAddress[chainRegistryAddress] = chainRegistryNftId;
        _registryAddressByChainId[chainId] = chainRegistryAddress;
        _chainId.push(chainId);

        _chainNft.mint(NFT_LOCK_ADDRESS, chainRegistryId);
    }

    //------------- public view functions -------------//
    function getChainRegistryAddress(uint chainId) public view returns (address) {
        return _registryAddressByChainId[chainId];
    }

    function getChainId(uint idx) public view returns (uint) {
        return _chainId[idx];
    }

    function chainIds() public view returns (uint) {
        return _chainId.length;
    }

    // Internals
        /// @dev global registry registration
    function _registerRegistry(address globalRegistry) 
        internal
        virtual
        override
        returns (NftId globalRegistryNftId)
    {
        uint256 globalRegistryId = _chainNft.GLOBAL_REGISTRY_ID();
        globalRegistryNftId = NftIdLib.toNftId(globalRegistryId);

        _info[globalRegistryNftId] = ObjectInfo({
            nftId: globalRegistryNftId,
            parentNftId: _protocolNftId,
            objectType: REGISTRY(),
            isInterceptor: false,
            objectAddress: globalRegistry,
            initialOwner: NFT_LOCK_ADDRESS,
            data: ""
        });
        _nftIdByAddress[address(this)] = globalRegistryNftId;
        // global registry specific
        _registryAddressByChainId[MAINNET_CHAIN_ID] = address(this);
        _chainId.push(MAINNET_CHAIN_ID);

        _chainNft.mint(NFT_LOCK_ADDRESS, globalRegistryId);
    }

}
