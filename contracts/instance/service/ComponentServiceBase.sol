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
        NftId registryNftId
    )
        ServiceBase(registry, registryNftId)
    {
    }

    function _verifyAndGetProductAndInstance()
        internal
        view
        returns(
            IRegistry.ObjectInfo memory productInfo, 
            IInstance instance
        )
    {
        (productInfo, instance) = _verifyAndGetInfoAndInstance();
        require(productInfo.objectType == PRODUCT(), "ERROR_NOT_PRODUCT");
    }

    function _verifyAndGetPoolAndInstance()
        internal
        view
        returns(
            IRegistry.ObjectInfo memory poolInfo, 
            IInstance instance
        )
    {
        (poolInfo, instance) = _verifyAndGetInfoAndInstance();
        require(poolInfo.objectType == POOL(), "ERROR_NOT_POOL");
    }


    function _verifyAndGetInfoAndInstance()
        internal
        view
        returns(
            IRegistry.ObjectInfo memory info, 
            IInstance instance
        )
    {
        NftId componentNftId = _registry.getNftId(msg.sender);
        require(componentNftId.gtz(), "ERROR_COMPONENT_UNKNOWN");

        info = _registry.getObjectInfo(componentNftId);

        // TODO check if this is really needed or if registry may be considered reliable
        IRegistry.ObjectInfo memory instanceInfo = _registry.getObjectInfo(info.parentNftId);
        require(instanceInfo.nftId.gtz(), "ERROR_INSTANCE_UNKNOWN");
        require(instanceInfo.objectType == INSTANCE(), "ERROR_NOT_INSTANCE");

        instance = IInstance(instanceInfo.objectAddress);
    }
}
