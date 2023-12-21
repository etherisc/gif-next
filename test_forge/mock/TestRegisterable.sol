// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {NftId} from "../../contracts/types/NftId.sol";
import {ObjectType} from "../../contracts/types/ObjectType.sol";
import {Registerable} from "../../contracts/shared/Registerable.sol";

contract TestRegisterable is Registerable {

    constructor(
        address registry, 
        NftId registryNftId, 
        ObjectType objectType, 
        bool isInterceptor, 
        address initialOwner)
    {
        bytes memory data = "";
        _initializeRegisterable(
            registry, 
            registryNftId, 
            objectType, 
            isInterceptor, 
            initialOwner, 
            data);
    }
}