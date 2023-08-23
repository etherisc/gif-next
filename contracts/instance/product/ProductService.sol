// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;


// import {IProduct} from "../../components/IProduct.sol";
// import {IOwnable, IRegistryLinked, IRegisterable, IRegistry} from "../../registry/IRegistry.sol";
// import {IInstance} from "../IInstance.sol";
import {IRegistry} from "../../registry/IRegistry.sol";
import {IPolicyModule} from "../policy/IPolicy.sol";
import {RegistryLinked} from "../../registry/Registry.sol";
import {IProductService, IProductModule} from "./IProductService.sol";

// TODO or name this ProtectionService to have Product be something more generic (loan, savings account, ...)
contract ProductService is
    RegistryLinked,
    IProductService
{
    constructor(address registry) 
        RegistryLinked(registry)
    { }


    function createApplication(
        address applicationOwner,
        uint256 sumInsuredAmount,
        uint256 premiumAmount,
        uint256 lifetime,
        uint256 bundleNftId
    )
        external 
        override
        returns(uint256 nftId)
    {
        // same as onlyProduct
        uint256 productNftId = _registry.getNftId(msg.sender);
        require(productNftId > 0, "ERROR_PRODUCT_UNKNOWN");
        IRegistry.RegistryInfo memory productInfo = _registry.getInfo(productNftId);
        require(productInfo.objectType == _registry.PRODUCT(), "ERROR_NOT_PRODUCT");

        IRegistry.RegistryInfo memory instanceInfo = _registry.getInfo(productInfo.parentNftId);
        require(instanceInfo.nftId > 0, "ERROR_INSTANCE_UNKNOWN");
        require(instanceInfo.objectType == _registry.INSTANCE(), "ERROR_NOT_INSTANCE");

        emit LogDebug(1, instanceInfo.objectAddress, "should be instance address");

        IPolicyModule policyModule = IPolicyModule(instanceInfo.objectAddress);
        nftId = policyModule.createApplication(
            productInfo,
            applicationOwner,
            sumInsuredAmount,
            premiumAmount,
            lifetime,
            bundleNftId);
    }

    function underwrite(uint256 nftId) external override {}
    function close(uint256 nftId) external override {}
}

contract ProductModule is
    IProductModule
{
    IProductService private _productService;

    constructor(address productService) {
        _productService = IProductService(productService);
    }

    function getProductService() external view returns(IProductService) {
        return _productService;
    }

}