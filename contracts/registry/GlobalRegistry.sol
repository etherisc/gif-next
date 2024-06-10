// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ICreateX} from "../../lib/createx/src/ICreateX.sol";

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
    error ErrorGlobalRegistryDeploymentNotOnMainnet(uint chainId);
    error ErrorGlobalRegistryChainRegistryAlreadyRegistered(uint chainId, address chainRegistry);
    error ErrorGlobalRegistryChainRegistryAddressInvalid(uint chainId, address chainRegistry);

    mapping(uint chanId => address registry) _registryAddressByChainId;

    uint constant public MAINNET_CHAIN_ID = 1;
    ICreateX public constant _createX = ICreateX(0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed);
    bytes32 public constant _salt = "0x1234567890"; // salt used to deploy on L2

    // TODO still preferable to know registry address at chainId xyz without asking registry on chainId 1?
    // TODO caller restrictions?
    // TODO the only ever deployer per chain id?
    // if no registrations at all -> then code and deployer are not future proof...
    function registerChainRegistry(uint chainId, address deployer)
        external
        onlyReleaseManager() // or restricted to GIF_ADMIN / GIF_MANAGER
        returns (NftId chainRegistryNftId, address chainRegistryAddress)
    {
        // calculate chain registry token id
        uint chainRegistryId = _chainNft.calculateTokenId(REGISTRY_TOKEN_SEQUENCE_ID, chainId);
        chainRegistryNftId = NftIdLib.toNftId(chainRegistryId);
        // calculate chain registry address, independent of chainId
        address chainRegistryAddress = _computeChainRegistryAddress(deployer);

        if(chainId == 1) {
            // TODO must revert on attempt to register with chainId 1
            // ideally "_chainNft.calculateTokenId(REGISTRY_TOKEN_SEQUENCE_ID, 1);" must return  globalRegistryId (and revert later when minting)
        }

        // TODO !!! If deployed to the same addresses on each chain??? !!!
        if(_nftIdByAddress[chainRegistryAddress] != NftIdLib.zero()) {
            revert ErrorGlobalRegistryChainRegistryAddressInvalid(chainId, chainRegistryAddress);
        }

        if(_registryAddressByChainId[chainId] != address(0)) {
            revert ErrorGlobalRegistryChainRegistryAlreadyRegistered(chainId, _registryAddressByChainId[chainId]);
        }

        _registryAddressByChainId[chainId] = chainRegistryAddress;
        _nftIdByAddress[chainRegistryAddress] = chainRegistryNftId;
        _info[chainRegistryNftId] = ObjectInfo({
            nftId: chainRegistryNftId,
            parentNftId: _protocolNftId,
            objectType: REGISTRY(),
            isInterceptor: false,
            objectAddress: chainRegistryAddress, // as contract on chainId (need "chainId:address" format) OR address(0) as object
            initialOwner: NFT_LOCK_ADDRESS,
            data: ""  
        });

        _chainNft.mint(NFT_LOCK_ADDRESS, chainRegistryId);
    }

    function getChainRegistry(uint chainId) public returns (address) {
        return _registryAddressByChainId[chainId];
    }

    function _computeChainRegistryAddress(address deployer)
        private
        returns (address chainRegistryAddress)
    {
        // [0..19] - deployer address, [20] - cross-chain redeploy protection, [21..31] - salt
        bytes32 permissionedSalt = bytes32(abi.encodePacked(bytes20(uint160(deployer)), bytes1(hex"00"), _salt));
        chainRegistryAddress = _createX.computeCreate2Address(_salt, _initCodeHash, deployer);
    }

    function _registerGlobalRegistry()
        internal 
        virtual
        override
        onlyInitializing
        returns (NftId globalRegistryNftId)
    {
        // TODO .GLOBAL_REGISTRY_ID() MUST BE equal to .calculateTokenId(regestrySequenceId, 1)
        uint256 globalRegistryId = _chainNft.GLOBAL_REGISTRY_ID();
        globalRegistryNftId = NftIdLib.toNftId(globalRegistryId);

        _info[globalRegistryNftId] = ObjectInfo({
            nftId: globalRegistryNftId,
            parentNftId: _protocolNftId,
            objectType: REGISTRY(),
            isInterceptor: false,
            objectAddress: address(this),
            initialOwner: NFT_LOCK_ADDRESS,
            data: ""
        });

        _nftIdByAddress[address(this)] = globalRegistryNftId;

        _chainNft.mint(NFT_LOCK_ADDRESS, globalRegistryId);
    }

    /// @dev checks network, reverts if not mainnet
    function _registerRegistry() 
        internal
        virtual
        override
        onlyInitializing
        returns (NftId registryNftId)
    {
        // TODO just require block.chainId == MAINNET_CHAIN_ID
        uint256 registryId = _chainNft.calculateTokenId(REGISTRY_TOKEN_SEQUENCE_ID, block.chainid);
        uint256 globalRegistryId = _chainNft.calculateTokenId(REGISTRY_TOKEN_SEQUENCE_ID, MAINNET_CHAIN_ID);
        // TODO "_globalRegistryNftId" have special value given by GLOBAL_REGISTRY_ID() function, you never get it by calculation
        if(registryId != globalRegistryId) {
            revert ErrorGlobalRegistryDeploymentNotOnMainnet(block.chainid);
        }

        return _globalRegistryNftId;
    }
}
