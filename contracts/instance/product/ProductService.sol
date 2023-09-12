// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

// import {IProduct} from "../../components/IProduct.sol";
// import {IOwnable, IRegistryLinked, IRegisterable, IRegistry} from "../../registry/IRegistry.sol";
// import {IInstance} from "../IInstance.sol";
import {IRegistry} from "../../registry/IRegistry.sol";
import {IPolicyModule} from "../policy/IPolicy.sol";
import {RegistryLinked} from "../../registry/Registry.sol";
import {IProductService, IProductModule} from "./IProductService.sol";
import {ITreasuryModule} from "../../instance/treasury/ITreasury.sol";
import {IPoolModule} from "../../instance/pool/IPoolModule.sol";
import {ObjectType, INSTANCE, PRODUCT} from "../../types/ObjectType.sol";
import {NftId, NftIdLib} from "../../types/NftId.sol";

// TODO or name this ProtectionService to have Product be something more generic (loan, savings account, ...)
contract ProductService is RegistryLinked, IProductService {
    using NftIdLib for NftId;

    constructor(address registry) RegistryLinked(registry) 
    // solhint-disable-next-line no-empty-blocks
    {}

    function createApplication(
        address applicationOwner,
        uint256 sumInsuredAmount,
        uint256 premiumAmount,
        uint256 lifetime,
        NftId bundleNftId
    ) external override returns (NftId nftId) {
        // same as only registered product
        NftId productNftId = _registry.getNftId(msg.sender);
        require(productNftId.gtz(), "ERROR_PRODUCT_UNKNOWN");
        IRegistry.RegistryInfo memory productInfo = _registry.getInfo(productNftId);
        require(productInfo.objectType == PRODUCT(), "ERROR_NOT_PRODUCT");

        IRegistry.RegistryInfo memory instanceInfo = _registry.getInfo(productInfo.parentNftId);
        require(instanceInfo.nftId.gtz(), "ERROR_INSTANCE_UNKNOWN");
        require(instanceInfo.objectType == INSTANCE(), "ERROR_NOT_INSTANCE");

        IPolicyModule policyModule = IPolicyModule(instanceInfo.objectAddress);
        nftId = policyModule.createApplication(
            productInfo,
            applicationOwner,
            sumInsuredAmount,
            premiumAmount,
            lifetime,
            bundleNftId
        );

        // add logging
    }

    function underwrite(NftId policyNftId) external override {
        // validation
        // same as only registered product
        NftId productNftId = _registry.getNftId(msg.sender);
        require(productNftId.gtz(), "ERROR_PRODUCT_UNKNOWN");
        IRegistry.RegistryInfo memory productInfo = _registry.getInfo(productNftId);
        require(productInfo.objectType == PRODUCT(), "ERROR_NOT_PRODUCT");

        IRegistry.RegistryInfo memory instanceInfo = _registry.getInfo(productInfo.parentNftId);
        require(instanceInfo.nftId.gtz(), "ERROR_INSTANCE_UNKNOWN");
        require(instanceInfo.objectType == INSTANCE(), "ERROR_NOT_INSTANCE");

        // underwrite policy
        address instanceAddress = instanceInfo.objectAddress;
        IPoolModule poolModule = IPoolModule(instanceAddress);
        poolModule.underwrite(policyNftId, productNftId);

        // activate policy
        IPolicyModule policyModule = IPolicyModule(instanceAddress);
        policyModule.activate(policyNftId);

        // add logging
    }

    function collectPremium(NftId policyNftId)
        external
        override
    {
        // validation same as other functions, eg underwrite
        // TODO unify validation into modifier and/or other suitable approaches
        // same as only registered product
        NftId productNftId = _registry.getNftId(msg.sender);
        require(productNftId.gtz(), "ERROR_PRODUCT_UNKNOWN");
        IRegistry.RegistryInfo memory productInfo = _registry.getInfo(productNftId);
        require(productInfo.objectType == PRODUCT(), "ERROR_NOT_PRODUCT");

        IRegistry.RegistryInfo memory instanceInfo = _registry.getInfo(productInfo.parentNftId);
        require(instanceInfo.nftId.gtz(), "ERROR_INSTANCE_UNKNOWN");
        require(instanceInfo.objectType == INSTANCE(), "ERROR_NOT_INSTANCE");

        // process/collect premium: book keeping for policy
        address instanceAddress = instanceInfo.objectAddress;
        IPolicyModule policyModule = IPolicyModule(instanceAddress);
        policyModule.processPremium(policyNftId);

        // process/collect premium: actual token transfer
        ITreasuryModule treasuryModule = ITreasuryModule(instanceAddress);
        treasuryModule.processPremium(policyNftId, productNftId);

        // TODO add logging
    }

    function close(NftId policyNftId) external override
    // solhint-disable-next-line no-empty-blocks
    {}

}

abstract contract ProductModule is IProductModule {
    IProductService private _productService;

    constructor(address productService) {
        _productService = IProductService(productService);
    }

    function getProductService() external view returns (IProductService) {
        return _productService;
    }
}
