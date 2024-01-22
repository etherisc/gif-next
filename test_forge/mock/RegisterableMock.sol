// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { FoundryRandom } from "foundry-random/FoundryRandom.sol";

import {NftId, zeroNftId} from "../../contracts/types/NftId.sol";
import {ObjectType} from "../../contracts/types/ObjectType.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {Registerable} from "../../contracts/shared/Registerable.sol";

contract RegisterableMock is Registerable {

    constructor(
        address registryAddress,
        NftId parentNftId,
        ObjectType objectType,
        bool isInterceptor,
        address initialOwner,
        bytes memory data) 
        public
    {
        _initializeRegisterable(
            registryAddress,
            parentNftId,
            objectType,
            isInterceptor,
            initialOwner,
            data);        
    }
}

contract SelfOwnedRegisterableMock is Registerable {

    constructor(
        address registryAddress,
        NftId parentNftId,
        ObjectType objectType,
        bool isInterceptor,
        bytes memory data) 
        public
    {
        _initializeRegisterable(
            registryAddress,
            parentNftId,
            objectType,
            isInterceptor,
            address(this),
            data);        
    }
}

contract RegisterableMockWithRandomInvalidAddress is Registerable {

    address public _invalidAddress;

    constructor(
        address registryAddress,
        NftId parentNftId,
        ObjectType objectType,
        bool isInterceptor,
        address initialOwner,
        bytes memory data)
    {
        FoundryRandom rng = new FoundryRandom();

        address invalidAddress = address(uint160(rng.randomNumber(type(uint160).max)));
        if(invalidAddress == address(this)) {
            invalidAddress = address(uint160(invalidAddress) + 1);
        }

        _invalidAddress = invalidAddress;

        _initializeRegisterable(
            registryAddress,
            parentNftId,
            objectType,
            isInterceptor,
            initialOwner,
            data);   
    }

    function getInitialInfo() 
        public 
        view 
        virtual override
        returns (IRegistry.ObjectInfo memory, bytes memory) 
    {
        (
            IRegistry.ObjectInfo memory info,
            bytes memory data
        ) = super.getInitialInfo();

        info.objectAddress = _invalidAddress;

        return (info, data);
    }
}