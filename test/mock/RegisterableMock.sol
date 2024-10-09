// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {FoundryRandom} from "foundry-random/FoundryRandom.sol";

import {InitializableERC165} from "../../contracts/shared/InitializableERC165.sol";
import {IRegisterable} from "../../contracts/shared/IRegisterable.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {MockInterceptor} from "./MockInterceptor.sol";
import {NftId, NftIdLib} from "../../contracts/type/NftId.sol";
import {ObjectType} from "../../contracts/type/ObjectType.sol";
import {RegistryLinked} from "../../contracts/shared/RegistryLinked.sol";
import {Versionable} from "../../contracts/shared/Versionable.sol";


contract RegisterableMockWithAuthority is 
    IRegisterable, 
    InitializableERC165, 
    Versionable, 
    MockInterceptor, 
    AccessManaged,
    RegistryLinked {

    error ErrorRegisterableMockIsNotInterceptor(address registerable);

    IRegistry.ObjectInfo internal _info;
    address internal _initialOwner;
    bytes internal _data;

    constructor(
        address authority,
        NftId nftId,
        NftId parentNftId,
        ObjectType objectType,
        bool isInterceptor,
        address initialOwner,
        bytes memory data
    )
        AccessManaged(authority)
    {
        _info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            objectType,
            getRelease(),
            isInterceptor,
            address(this)
        );
        _initialOwner = initialOwner;
        _data = data;

        initializeMock();
    }

    function initializeMock()
        public
        initializer()
    {
        _initializeERC165();
        _registerInterface(type(IRegisterable).interfaceId);       
    }

    function isActive() external view returns (bool active) { return true; }

    function getInitialInfo() 
        public 
        view 
        virtual 
        returns (IRegistry.ObjectInfo memory) 
    {
        return _info;
    }

    function getInitialData() 
        public 
        view 
        virtual 
        returns (bytes memory) 
    {
        return _data;
    }

    function nftTransferFrom(address from, address to, uint256 tokenId, address operator) public override {
        if(!_info.isInterceptor) {
            revert ErrorRegisterableMockIsNotInterceptor(address(this));
        }
        super.nftTransferFrom(from, to, tokenId, operator);
    }

    // from INftOwnable
    function linkToRegisteredNftId() external returns (NftId) { /*do nothing*/ }
    function getOwner() external virtual view returns (address) {return _initialOwner; }

    // from INftOwnable
    function getRegistryAddress() external view returns (address) { revert("NotSupported"); }
    function getNftId() external view returns (NftId) { revert("NotSupported"); }

}


contract RegisterableMock is RegisterableMockWithAuthority {

    address internal constant AUTHORITY = address(123);

    constructor(
        NftId nftId,
        NftId parentNftId,
        ObjectType objectType,
        bool isInterceptor,
        address initialOwner,
        bytes memory data
    )
        RegisterableMockWithAuthority(
            address(AUTHORITY),
            nftId,
            parentNftId,
            objectType,
            isInterceptor,
            initialOwner,
            data
        )
    {}
}


contract RegisterableMockWithInvalidAddress is RegisterableMock {

    constructor(
        NftId nftId,
        NftId parentNftId,
        ObjectType objectType,
        bool isInterceptor,
        address objectAddress,
        address initialOwner,
        bytes memory data
    )
        RegisterableMock(
            nftId,
            parentNftId,
            objectType,
            isInterceptor,
            initialOwner,
            data) 
    {
        if(objectAddress == address(this)) {
            objectAddress = address(uint160(objectAddress) + 1);
        }

        _info.objectAddress = objectAddress;
    }
}


contract SimpleAccessManagedRegisterableMock is RegisterableMock {
    constructor(NftId parentNftId, ObjectType objectType, address authority)
        RegisterableMock(
            NftIdLib.zero(),
            parentNftId,
            objectType,
            false,
            msg.sender,
            ""
        )
    // solhint-disable-next-line no-empty-blocks
    {}
}


contract SelfOwnedRegisterableMock is RegisterableMock {

    constructor(
        NftId nftId,
        NftId parentNftId,
        ObjectType objectType,
        bool isInterceptor,
        bytes memory data
    )
        RegisterableMock(
            nftId,
            parentNftId,
            objectType,
            isInterceptor,
            address(this),
            data)
    {}
}
