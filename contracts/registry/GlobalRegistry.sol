// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {NftId, NftIdLib} from "../type/NftId.sol";
import {VersionPart} from "../type/Version.sol";
import {ObjectType, REGISTRY} from "../type/ObjectType.sol";

import {IGlobalRegistry} from "./IGlobalRegistry.sol";
import {Registry} from "./Registry.sol";
import {RegistryAdmin} from "./RegistryAdmin.sol";

contract GlobalRegistry is 
    Registry,
    IGlobalRegistry
{
    using EnumerableSet for EnumerableSet.AddressSet;

    error ErrorGlobalRegistryDeploymentNotOnMainnet(uint chainId);
    error ErrorGlobalRegistryChainRegistryAlreadyRegistered(uint chainId, address chainRegistry);
    error ErrorGlobalRegistryChainRegistryAddressInvalid(uint chainId, address chainRegistry);

    mapping(uint chanId => address registry) _registryAddressByChainId;
    uint256[] _chainId;

    uint constant public MAINNET_CHAIN_ID = 1;


    constructor(RegistryAdmin admin) Registry(admin, address(this)) 
    {}

    function registerChainRegistry(uint chainId, address chainRegistryAddress)
        external
        restricted
        returns (NftId chainRegistryNftId)
    {
        if(chainId == MAINNET_CHAIN_ID) {
            // TODO better naming
            revert ErrorGlobalRegistryChainRegistryAlreadyRegistered(chainId, address(this));
        }

        // TODO allow for the same address to be registered on multiple chains
        if(_nftIdByAddress[chainRegistryAddress] != NftIdLib.zero()) {
            revert ErrorGlobalRegistryChainRegistryAddressInvalid(chainId, chainRegistryAddress);
        }
        // redundant -> chainRegistryId is chainId dependent, chainNft will revert if chainRegistryId is already minted
        if(_registryAddressByChainId[chainId] != address(0)) {
            revert ErrorGlobalRegistryChainRegistryAlreadyRegistered(chainId, _registryAddressByChainId[chainId]);
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
    // TODO returns 0 for mainnet
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

    /// @dev makes no registration, just reverts if not on mainnet
    function _registerRegistry() 
        internal
        virtual
        override
        onlyInitializing
        returns (NftId registryNftId)
    {
        if(block.chainid != MAINNET_CHAIN_ID) {
            revert ErrorGlobalRegistryDeploymentNotOnMainnet(block.chainid);
        }

        return _globalRegistryNftId;
    }
}
