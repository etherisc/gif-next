// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

interface IOwnable {
    function getOwner() external view returns(address owner);
}

interface IRegistryLinked {
    // function setRegistry(address registry) external;
    function getRegistry() external view returns(IRegistry registry);
}

interface IRegisterable is 
    IOwnable,
    IRegistryLinked
{

    function register() external returns(uint256 nftId);
    
    function getNftId() external view returns(uint256 nftId);
    function getParentNftId() external view returns(uint256 parentNftId);
    function getType() external view returns(uint256 objectType);
    function getData() external view returns(bytes memory data);
    function isRegisterable() external pure returns(bool);
    function getInitialOwner() external view returns(address initialOwner);

    function isRegistered() external view returns(bool);
}


interface IRegistry {

    struct RegistryInfo {
        uint256 nftId;
        uint256 parentNftId;
        uint256 objectType;
        address objectAddress;
        address initialOwner;
    }

    function TOKEN() external pure returns(uint256);
    function INSTANCE() external pure returns(uint256);
    function PRODUCT() external pure returns(uint256);
    function ORACLE() external pure returns(uint256);
    function POOL() external pure returns(uint256);
    function POLICY() external pure returns(uint256);
    function BUNDLE() external pure returns(uint256);

    function register(address objectAddress) external returns(uint256 nftId);
    function transfer(uint256 nftId, address newOwner) external;

    function getNftId(address objectAddress) external view returns(uint256 nftId);
    function getInfo(uint256 nftId) external view returns(RegistryInfo memory info);
    function getOwner(uint256 nftId) external view returns(address ownerAddress);

    function isRegistered(address objectAddress) external view returns(bool);
}
