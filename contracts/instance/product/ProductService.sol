// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;


// import {IProduct} from "../../components/IProduct.sol";
// import {IOwnable, IRegistryLinked, IRegisterable, IRegistry} from "../../registry/IRegistry.sol";
// import {IInstance} from "../IInstance.sol";
import {IRegistry} from "../../registry/IRegistry.sol";
import {IPolicyModule} from "../policy/IPolicy.sol";
import {RegistryLinked} from "../../registry/Registry.sol";
import {IProductService} from "./IProductService.sol";

// TODO or name this ProtectionService to have Product be something more generic (loan, savings account, ...)
contract ProductService is
    RegistryLinked,
    IProductService
{

    constructor(address registry) 
        RegistryLinked(registry)
    { }


    function createApplicationForBundle(
        uint256 bundleNftId,
        uint256 sumInsuredAmount,
        uint256 premiumAmount,
        uint256 lifetime
    )
        external 
        override
        returns(uint256 nftId)
    {
        // assumptions: caller is product
        // TODO tons of validations via registry, move this to registry?
        // many of those should be always true
        // - object types for pool and instance)
        // - non 0 parent ids for many object types
        uint256 productNftId = _registry.getNftId(msg.sender);
        require(productNftId > 0, "ERROR_PRODUCT_UNKNOWN");
        IRegistry.RegistryInfo memory productInfo = _registry.getInfo(productNftId);
        require(productInfo.objectType == _registry.PRODUCT(), "ERROR_NOT_PRODUCT");
        IRegistry.RegistryInfo memory bundleInfo = _registry.getInfo(bundleNftId);
        require(bundleInfo.nftId > 0, "ERROR_BUNDLE_UNKNOWN");
        require(bundleInfo.objectType == _registry.BUNDLE(), "ERROR_NOT_BUNDLE");
        IRegistry.RegistryInfo memory poolInfo = _registry.getInfo(bundleInfo.parentNftId);
        require(poolInfo.nftId > 0, "ERROR_POOL_UNKNOWN");
        require(bundleInfo.objectType == _registry.POOL(), "ERROR_NOT_POOL");
        require(poolInfo.parentNftId == productInfo.parentNftId, "ERROR_PRODUCT_POOL_MISMATCH");
        IRegistry.RegistryInfo memory instanceInfo = _registry.getInfo(productInfo.parentNftId);
        require(instanceInfo.nftId > 0, "ERROR_INSTANCE_UNKNOWN");
        require(instanceInfo.objectType == _registry.INSTANCE(), "ERROR_NOT_INSTANCE");

        IPolicyModule policyModule = IPolicyModule(instanceInfo.objectAddress);
    }

    function underwrite(uint256 nftId) external override {}
    function close(uint256 nftId) external override {}
}

