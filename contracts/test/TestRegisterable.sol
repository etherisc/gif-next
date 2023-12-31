// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {NftId} from "../../contracts/types/NftId.sol";
import {ObjectType, TOKEN} from "../../contracts/types/ObjectType.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {Registerable} from "../../contracts/shared/Registerable.sol";

contract TestRegisterable is Registerable {

    constructor(address registry, NftId registryNftId, ObjectType objectType, bool isInterceptor, address initialOwner)
        //Registerable(registry, registryNftId)
    // solhint-disable-next-line no-empty-blocks
    {
        bytes memory data = "";
        _initializeRegisterable(registry, registryNftId, objectType, isInterceptor, initialOwner, data);
    }
}