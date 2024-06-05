// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ICreateX} from "../../lib/createx/src/ICreateX.sol";

import {InitializableCustom} from "../shared/InitializableCustom.sol";

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

    ICreateX public constant _createX = ICreateX(0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed);
    bytes32 _salt = "0x1234567890";

    constructor(RegistryAdmin admin, address initializeOwner)
        Registry(admin, initializeOwner)
    {}

    // TODO caller restrictions?
    // TODO the only ever deployer per chain id?
    function registerChainRegistry(uint chainId, address deployer)
        external
        onlyReleaseManager() // or restricted to GIF_ADMIN / GIF_MANAGER
        returns (NftId chainRegistryNftId, address chainRegistryAddress)
    {
        // calculate chain registry token id
        uint chainRegistryId = _chainNft.calculateTokenId(REGISTRY_TOKEN_SEQUENCE_ID, chainId);
        chainRegistryNftId = NftIdLib.toNftId(chainRegistryId);
        // calculate chainRegistryAddress
        address chainRegistryAddress = _computeChainRegistryAddress(deployer);

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

    function _computeChainRegistryAddress(address deployer)
        private
        returns (address chainRegistryAddress)
    {
        address initializeOwner = deployer;// deployer does initialization
        // calculate registryAdminAddress
        bytes32 initCodeHash = keccak256(
            abi.encodePacked(
                type(RegistryAdmin).creationCode,
                abi.encode(initializeOwner) 
            )
        );
        address chainRegistryAdmin = _createX.computeCreate2Address(_salt, initCodeHash, deployer);
        //chainRegistryAdmin = _createX.computeCreate2Address(_salt, initCodeHash);// <- if deployer is the same createX address
        //chainRegistryAdmin = _createX.computeCreate3Address(_salt, deployer);
        //chainRegistryAdmin = _createX.computeCreate3Address(_salt);// <- if deployer is the same createX address

        // calculate chainRegistryAddress
        initCodeHash = keccak256(
            abi.encodePacked(
                type(Registry).creationCode, 
                abi.encode(chainRegistryAdmin, initializeOwner)
            )
        );
        chainRegistryAddress = _createX.computeCreate2Address(_salt, initCodeHash, deployer);
    }

    function getChainRegistry(uint chainId) public returns (address) {
        return _registryAddressByChainId[chainId];
    }

    function _registerGlobalRegistry()
        internal 
        virtual
        override
        returns (NftId globalRegistryNftId)
    {
        uint256 globalRegistryId = _chainNft.calculateTokenId(REGISTRY_TOKEN_SEQUENCE_ID, 1);
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
        override
        onlyInitializing
        returns (NftId registryNftId)
    {
        uint256 registryId = _chainNft.calculateTokenId(REGISTRY_TOKEN_SEQUENCE_ID, block.chainid);
        //uint256 globalRegistryId = _chainNft.calculateTokenId(REGISTRY_TOKEN_SEQUENCE_ID, 1);

        if(registryId != _globalRegistryNftId.toInt()) {
            revert ErrorGlobalRegistryDeploymentNotOnMainnet(block.chainid);
        }

        return _globalRegistryNftId;
    }
}
