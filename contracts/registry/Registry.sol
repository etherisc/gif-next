// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IChainNft} from "./IChainNft.sol";
import {IRegistry, IRegistryLinked, IRegisterable} from "./IRegistry.sol";

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
        return _registry.getNftId(address(this)) > 0;
    }

    function getNftId() public view override returns(uint256 id) {
        return _registry.getNftId(address(this));
    }

    function getOwner() public view override returns(address owner) {
        uint256 id = _registry.getNftId(address(this));
        owner = _registry.getOwner(id);
        return owner != address(0) ? owner : _initialOwner;
    }

}

contract Registry is IRegistry {

    string public constant EMPTY_URI = "";

    mapping(uint256 id => RegistryInfo info) private _info;
    mapping(uint256 id => address owner) private _owner;
    mapping(address object => uint256 id) private _idByAddress;

    IChainNft private _chainNft;

    function initialize(address chainNft) external {
        require(address(_chainNft) == address(0), "ERROR:REG-001:ALREADY_INITIALIZED");
        _chainNft = IChainNft(chainNft);
    }

    function TOKEN() public pure override returns(uint256) { return 30; }
    function INSTANCE() public pure override returns(uint256) { return 40; }
    function PRODUCT() public pure override returns(uint256) { return 50; }
    function ORACLE() public pure override returns(uint256) { return 60; }
    function POOL() public pure override returns(uint256) { return 70; }
    function POLICY() public pure override returns(uint256) { return 80; }
    function BUNDLE() public pure override returns(uint256) { return 90; }

    function register(address objectAddress) external override returns(uint256 nftId) {
        require(_idByAddress[objectAddress] == 0, "ERROR:REG-001:ALREADY_REGISTERED");

        IRegisterable registerable = IRegisterable(objectAddress);
        require(registerable.isRegisterable(), "ERROR:REG-002:NOT_REGISTERABLE");

        // check parent exists (for objects not instances)
        if(registerable.getType() != INSTANCE()) {
            RegistryInfo memory parentInfo = _info[registerable.getParentNftId()];
            require(parentInfo.nftId > 0, "ERROR:REG-003:PARENT_NOT_FOUND");
            // check validity of parent relation, valid relations are
            // policy -> product, bundle -> pool, product -> instance, pool -> instance
        }

        nftId = _chainNft.mint(
            registerable.getInitialOwner(), 
            EMPTY_URI);
    
        RegistryInfo memory info = RegistryInfo(
            nftId,
            registerable.getParentNftId(),
            registerable.getType(),
            objectAddress,
            registerable.getInitialOwner()
        );

        _info[nftId] = info;
        _idByAddress[objectAddress] = nftId;

        // add logging
    }


    function registerObjectForInstance(
        uint256 parentNftId,
        uint256 objectType,
        address initialOwner
    )
        external 
        override
        // TODO add onlyRegisteredInstance
        returns(uint256 nftId)
    {
        // TODO add more validation
        require(
            objectType == POLICY() || objectType == BUNDLE(),
            "ERROR:REG-005:TYPE_INVALID");

        nftId = _chainNft.mint(
            initialOwner,
            EMPTY_URI);

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


    function getNftId(address object) external view override returns(uint256 id) {
        return _idByAddress[object];
    }


    function isRegistered(address object) external view override returns(bool) {
        return _idByAddress[object] > 0;
    }


    function getInfo(uint256 nftId) external view override returns(RegistryInfo memory info) {
        return _info[nftId];
    }

    function getOwner(uint256 nftId) external view override returns(address) {
        return _chainNft.ownerOf(nftId);
    }

    function getNftAddress() external view override returns(address nft) {
        return address(_chainNft);
    }
}
