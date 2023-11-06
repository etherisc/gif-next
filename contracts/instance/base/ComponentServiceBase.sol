// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegistry} from "../../registry/IRegistry.sol";
import {IInstance} from "../../instance/IInstance.sol";
import {ObjectType, INSTANCE, PRODUCT, POOL} from "../../types/ObjectType.sol";
import {NftId, NftIdLib} from "../../types/NftId.sol";

import {ServiceBase} from "./ServiceBase.sol";

abstract contract ComponentServiceBase is ServiceBase {

    constructor(
        address registry,
        NftId registryNftId,
        address initialOwner
    )
    {
        _initializeServiceBase(registry, registryNftId, initialOwner);
    }


    function _getAndVerifyComponentInfoAndInstance(
        ObjectType objectType
    )
        internal
        view
        returns(
            IRegistry.ObjectInfo memory info, 
            IInstance instance
        )
    {
        NftId componentNftId = getRegistry().getNftId(msg.sender);
        require(componentNftId.gtz(), "ERROR_COMPONENT_UNKNOWN");

        info = getRegistry().getObjectInfo(componentNftId);
        require(info.objectType == objectType, "OBJECT_TYPE_INVALID");

        address instanceAddress = getRegistry().getObjectInfo(info.parentNftId).objectAddress;
        instance = IInstance(instanceAddress);
    }
}
