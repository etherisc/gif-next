// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IChainNft} from "./IChainNft.sol";
import {IRegistry, IRegistryLinked, IRegisterable} from "./IRegistry.sol";
import {NftId, toNftId, NftIdLib} from "../types/NftId.sol";
import {ObjectType, toObjectType} from "../types/ObjectType.sol";

contract RegistryLinked is IRegistryLinked {

    IRegistry internal _registry;
    
    constructor(address registry) {
        _registry = IRegistry(registry);
    }

    function getRegistry() external view override returns(IRegistry registry) {
        return _registry;
    }

}


abstract contract Registerable is 
    RegistryLinked,
    IRegisterable
{
    using NftIdLib for NftId;

    address private _initialOwner;
    
    constructor(address registry)
        RegistryLinked(registry)
    {
        _initialOwner = msg.sender;
    }

    // getType, getData and register need to be implemented by concrete contract

    function isRegisterable() external pure override returns(bool) {
        return true;
    }

    function getInitialOwner() public view override returns(address deployer) {
        return _initialOwner;
    }

    function isRegistered() public view override returns(bool) {
        NftId nftId = _registry.getNftId(address(this));
        return nftId.gtz();
    }

    function getNftId() public view override returns(NftId nftId) {
        return _registry.getNftId(address(this));
    }

    function getOwner() public view override returns(address owner) {
        NftId id = _registry.getNftId(address(this));
        owner = _registry.getOwner(id);
        return owner != address(0) ? owner : _initialOwner;
    }

}

contract Registry is IRegistry {
    using NftIdLib for NftId;

    string public constant EMPTY_URI = "";

    mapping(NftId nftId => RegistryInfo info) private _info;
    mapping(NftId nftId => address owner) private _owner;
    mapping(address object => NftId nftId) private _nftIdByAddress;

    IChainNft private _chainNft;

    function initialize(address chainNft) external {
        require(address(_chainNft) == address(0), "ERROR:REG-001:ALREADY_INITIALIZED");
        _chainNft = IChainNft(chainNft);
    }

    function TOKEN() public pure override returns(ObjectType) { return toObjectType(30); }
    function INSTANCE() public pure override returns(ObjectType) { return toObjectType(40); }
    function PRODUCT() public pure override returns(ObjectType) { return toObjectType(50); }
    function ORACLE() public pure override returns(ObjectType) { return toObjectType(60); }
    function POOL() public pure override returns(ObjectType) { return toObjectType(70); }
    function POLICY() public pure override returns(ObjectType) { return toObjectType(80); }
    function BUNDLE() public pure override returns(ObjectType) { return toObjectType(90); }

    function register(address objectAddress) external override returns(NftId nftId) {
        require(_nftIdByAddress[objectAddress].eqz(), "ERROR:REG-002:ALREADY_REGISTERED");

        IRegisterable registerable = IRegisterable(objectAddress);
        require(registerable.isRegisterable(), "ERROR:REG-003:NOT_REGISTERABLE");

        // check parent exists (for objects not instances)
        if(registerable.getType() != INSTANCE()) {
            RegistryInfo memory parentInfo = _info[registerable.getParentNftId()];
            require(parentInfo.nftId.gtz(), "ERROR:REG-004:PARENT_NOT_FOUND");
            // check validity of parent relation, valid relations are
            // policy -> product, bundle -> pool, product -> instance, pool -> instance
        }

        uint256 mintedTokenId = _chainNft.mint(
            registerable.getInitialOwner(), 
            EMPTY_URI);
        nftId = toNftId(mintedTokenId);
    
        RegistryInfo memory info = RegistryInfo(
            nftId,
            registerable.getParentNftId(),
            registerable.getType(),
            objectAddress,
            registerable.getInitialOwner()
        );

        _info[nftId] = info;
        _nftIdByAddress[objectAddress] = nftId;

        // add logging
    }


    function registerObjectForInstance(
        NftId parentNftId,
        ObjectType objectType,
        address initialOwner
    )
        external 
        override
        // TODO add onlyRegisteredInstance
        returns(NftId nftId)
    {
        // TODO add more validation
        require(
            objectType == POLICY() || objectType == BUNDLE(),
            "ERROR:REG-005:TYPE_INVALID");

        uint256 mintedTokenId = _chainNft.mint(
            initialOwner,
            EMPTY_URI);
        nftId = toNftId(mintedTokenId);

        RegistryInfo memory info = RegistryInfo(
            nftId,
            parentNftId,
            objectType,
            address(0),
            initialOwner
        );

        _info[nftId] = info;

        // add logging
    }


    function getObjectCount() external view override returns(uint256) {
        return _chainNft.totalSupply();
    }


    function getNftId(address object) external view override returns(NftId id) {
        return _nftIdByAddress[object];
    }


    function isRegistered(address object) external view override returns(bool) {
        return _nftIdByAddress[object].gtz();
    }


    function getInfo(NftId nftId) external view override returns(RegistryInfo memory info) {
        return _info[nftId];
    }

    function getOwner(NftId nftId) external view override returns(address) {
        return _chainNft.ownerOf(nftId.toInt());
    }

    function getNftAddress() external view override returns(address nft) {
        return address(_chainNft);
    }
}
