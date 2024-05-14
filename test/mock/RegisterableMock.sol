// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";

import { FoundryRandom } from "foundry-random/FoundryRandom.sol";

import {NftId, NftIdLib} from "../../contracts/type/NftId.sol";
import {ObjectType} from "../../contracts/type/ObjectType.sol";
import {ERC165} from "../../contracts/shared/ERC165.sol";
import {IRegisterable} from "../../contracts/shared/IRegisterable.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {ITransferInterceptor} from "../../contracts/registry/ITransferInterceptor.sol";


contract RegisterableMock is ERC165, IRegisterable, ITransferInterceptor {

    IRegistry.ObjectInfo internal _info;

    constructor(
        NftId nftId,
        NftId parentNftId,
        ObjectType objectType,
        bool isInterceptor,
        address initialOwner,
        bytes memory data)
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
        initializeERC165();
        registerInterface(type(IRegisterable).interfaceId);       
    }

    // from IRegisterable
    function getInitialInfo() 
        public 
        view 
        virtual 
        returns (IRegistry.ObjectInfo memory) 
    {
        return _info;
    }

    // from ITransferInterceptor
    function nftMint(address to, uint256 tokenId) external {
        // do nothing
    }
    function nftTransferFrom(address from, address to, uint256 tokenId) external {
        // do nothing
    }

    // from INftOwnable
    function linkToRegisteredNftId() external { /*do nothing*/ }

    // from INftOwnable, DO NOT USE
    function getRegistry() external view returns (IRegistry) { revert(); }
    function getRegistryAddress() external view returns (address) { revert(); }
    function getNftId() external view returns (NftId) { revert(); }
    function getOwner() external view returns (address) { revert(); }
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

contract SimpleAccessManagedRegisterableMock is RegisterableMock, AccessManaged {
    constructor(NftId parentNftId, ObjectType objectType, address authority)
        AccessManaged(authority)
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