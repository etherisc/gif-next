// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegistry, IRegistryLinked, IRegisterable} from "./IRegistry.sol";

contract RegistryLinked is IRegistryLinked {

    IRegistry internal _registry;
    
    constructor() {
        _registry = IRegistry(address(0));
    }

    function setRegistry(address registry) public override {
        require(address(_registry) == address(0), "ERROR:RGL-001:REGISTRY_ALREADY_SET");
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
    
    constructor()
        RegistryLinked()
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
        address owner = _registry.getOwner(id);
        return owner != address(0) ? owner : _initialOwner;
    }

}

    // struct RegistryInfo {
    //     bytes32 id;
    //     uint256 objectType;
    //     address objectAddress;
    //     address initialOwner;
    // }

contract Registry is IRegistry {

    mapping(uint256 id => RegistryInfo info) private _info;
    mapping(uint256 id => address owner) private _owner;
    mapping(address object => uint256 id) private _idByAddress;
    uint256 [] private _ids;
    uint256 private _idNext;


    constructor() {
        _idNext = 0;
    }

    function TOKEN() external pure override returns(uint256) { return 30; }
    function INSTANCE() external pure override returns(uint256) { return 40; }
    function PRODUCT() external pure override returns(uint256) { return 50; }
    function ORACLE() external pure override returns(uint256) { return 60; }
    function POOL() external pure override returns(uint256) { return 70; }

    function register(address object) external override returns(uint256 id) {
        require(_idByAddress[object] == 0, "ERROR:REG-001:ALREADY_REGISTERED");

        IRegisterable registerable = IRegisterable(object);
        require(registerable.isRegisterable(), "ERROR:REG-002:NOT_REGISTERABLE");

        id = _mint(registerable.getInitialOwner());
    
        RegistryInfo memory info = RegistryInfo(
            id,
            registerable.getType(),
            object,
            registerable.getInitialOwner()
        );

        _info[id] = info;
        _idByAddress[object] = id;

        // TODO logging
    }


    function transfer(uint256 id, address newOwner) external {
        require(msg.sender == _owner[id], "ERROR:REG-010:NOT_OWNER");
        _owner[id] = newOwner;

        // TODO logging
    }


    function getObjectCount() external view returns(uint256) {
        return _ids.length;
    }


    function getNftId(address object) external view override returns(uint256 id) {
        return _idByAddress[object];
    }


    function isRegistered(address object) external view override returns(bool) {
        return _idByAddress[object] > 0;
    }


    function getInfo(uint256 id) external view override returns(RegistryInfo memory info) {
        return _info[id];
    }

    function getOwner(uint256 id) external view override returns(address) {
        return _owner[id];
    }


    function _mint(address initialOwner)
        internal
        returns(uint256 id)
    {
        _idNext++;

        id = _idNext;
        _owner[id] = initialOwner;
        _ids.push(id);
    }
}
