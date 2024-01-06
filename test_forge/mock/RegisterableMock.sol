// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

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

contract RegisterableMockWithFakeAddress is Registerable {

    address public _fakeAddress;

    constructor(
        address registryAddress,
        NftId parentNftId,
        ObjectType objectType,
        bool isInterceptor,
        address initialOwner,
        bytes memory data,
        address fakeAddress)
    {
        _fakeAddress = fakeAddress;

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

        info.objectAddress = _fakeAddress;

        return (info, data);
    }
}