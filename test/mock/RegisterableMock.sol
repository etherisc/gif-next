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
import {VersionPart, VersionPartLib} from "../../contracts/type/Version.sol";


contract RegisterableMockWithAuthority is InitializableERC165, IRegisterable, MockInterceptor, AccessManaged {

    error ErrorRegisterableMockIsNotInterceptor(address registerable);

    IRegistry.ObjectInfo internal _info;

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
            isInterceptor,
            address(this),
            initialOwner,
            data
        );

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

    // from IRegisterable
    function getRelease() public virtual pure returns (VersionPart release) {
        return VersionPartLib.toVersionPart(3);
    }

    function getInitialInfo() 
        public 
        view 
        virtual 
        returns (IRegistry.ObjectInfo memory) 
    {
        return _info;
    }

    function nftTransferFrom(address from, address to, uint256 tokenId, address operator) public override {
        if(!_info.isInterceptor) {
            revert ErrorRegisterableMockIsNotInterceptor(address(this));
        }
        super.nftTransferFrom(from, to, tokenId, operator);
    }

    // from INftOwnable
    function linkToRegisteredNftId() external returns (NftId) { /*do nothing*/ }

    // from INftOwnable, DO NOT USE
    function getRegistry() external view returns (IRegistry) { revert(); }
    function getRegistryAddress() external view returns (address) { revert(); }
    function getNftId() external view returns (NftId) { revert(); }
    function getOwner() external view returns (address) { revert(); }
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
