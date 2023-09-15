// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

// import {IProduct} from "../../components/IProduct.sol";
// import {IOwnable, IRegistryLinked, IRegisterable, IRegistry} from "../../registry/IRegistry.sol";
// import {IInstance} from "../IInstance.sol";
import {IRegistry} from "../../registry/IRegistry.sol";
import {IInstance} from "../../instance/IInstance.sol";
// import {IPolicy, IPolicyModule} from "../policy/IPolicy.sol";
import {RegistryLinked} from "../../registry/Registry.sol";
// import {IProductService} from "./IProductService.sol";
// import {ITreasury, ITreasuryModule, TokenHandler} from "../../instance/treasury/ITreasury.sol";
// import {IPoolModule} from "../../instance/pool/IPoolModule.sol";
import {ObjectType, INSTANCE, PRODUCT, POOL} from "../../types/ObjectType.sol";
import {NftId, NftIdLib} from "../../types/NftId.sol";

contract ComponentService is RegistryLinked {
    using NftIdLib for NftId;

    constructor(
        address registry
    ) RegistryLinked(registry) // solhint-disable-next-line no-empty-blocks
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
