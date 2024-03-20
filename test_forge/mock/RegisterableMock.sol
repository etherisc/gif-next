// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";

import { FoundryRandom } from "foundry-random/FoundryRandom.sol";

import {NftId, zeroNftId} from "../../contracts/types/NftId.sol";
import {ObjectType} from "../../contracts/types/ObjectType.sol";
import {ERC165} from "../../contracts/shared/ERC165.sol";
import {IRegisterable} from "../../contracts/shared/IRegisterable.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";


contract RegisterableMock is ERC165, IRegisterable {

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
        bytes memory data)
        RegisterableMock(
            nftId,
            parentNftId,
            objectType,
            isInterceptor,
            address(this),
            data)
    {}
}

contract RegisterableMockWithRandomInvalidAddress is RegisterableMock {

    constructor(
        NftId nftId,
        NftId parentNftId,
        ObjectType objectType,
        bool isInterceptor,
        address initialOwner,
        bytes memory data)
        RegisterableMock(
            nftId,
            parentNftId,
            objectType,
            isInterceptor,
            initialOwner,
            data) 
    {
        FoundryRandom rng = new FoundryRandom();

        address invalidAddress = address(uint160(rng.randomNumber(type(uint160).max)));
        if(invalidAddress == address(this)) {
            invalidAddress = address(uint160(invalidAddress) + 1);
        }

        _info.objectAddress = invalidAddress;
    }
}

contract SimpleAccessManagedRegisterableMock is RegisterableMock, AccessManaged {
    constructor(NftId parentNftId, ObjectType objectType, address authority)
        AccessManaged(authority)
        RegisterableMock(
            zeroNftId(),
            parentNftId,
            objectType,
            false,
            msg.sender,
            ""
        )
    {}
}