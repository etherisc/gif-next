// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

// import {IProduct} from "../../components/IProduct.sol";
// import {IOwnable, IRegistryLinked, IRegisterable, IRegistry} from "../../registry/IRegistry.sol";
// import {IInstance} from "../IInstance.sol";
import {IRegistry} from "../../registry/IRegistry.sol";
import {IPolicy, IPolicyModule} from "../policy/IPolicy.sol";
import {RegistryLinked} from "../../registry/Registry.sol";
import {IProductService, IProductModule} from "./IProductService.sol";
import {ITreasury, ITreasuryModule, TokenHandler} from "../../instance/treasury/ITreasury.sol";
import {IPoolModule} from "../../instance/pool/IPoolModule.sol";
import {ObjectType, INSTANCE, PRODUCT} from "../../types/ObjectType.sol";
import {NftId, NftIdLib} from "../../types/NftId.sol";
import {feeIsZero} from "../../types/Fee.sol";

// TODO or name this ProtectionService to have Product be something more generic (loan, savings account, ...)
contract ProductService is RegistryLinked, IProductService {
    using NftIdLib for NftId;

    constructor(
        address registry
    ) RegistryLinked(registry) // solhint-disable-next-line no-empty-blocks
    {

    }

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
        IRegistry.RegistryInfo memory productInfo = _registry.getInfo(
            productNftId
        );
        require(productInfo.objectType == PRODUCT(), "ERROR_NOT_PRODUCT");

        IRegistry.RegistryInfo memory instanceInfo = _registry.getInfo(
            productInfo.parentNftId
        );
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
        IRegistry.RegistryInfo memory productInfo = _registry.getInfo(
            productNftId
        );
        require(productInfo.objectType == PRODUCT(), "ERROR_NOT_PRODUCT");

        IRegistry.RegistryInfo memory instanceInfo = _registry.getInfo(
            productInfo.parentNftId
        );
        require(instanceInfo.nftId.gtz(), "ERROR_INSTANCE_UNKNOWN");
        require(instanceInfo.objectType == INSTANCE(), "ERROR_NOT_INSTANCE");

        // underwrite policy
        address instanceAddress = instanceInfo.objectAddress;
        IPoolModule poolModule = IPoolModule(instanceAddress);
        poolModule.underwrite(policyNftId, productNftId);

        // activate policy
        IPolicyModule policyModule = IPolicyModule(instanceAddress);
        policyModule.activate(policyNftId);

        // TODO add logging
    }

    function collectPremium(NftId policyNftId) external override {
        // validation same as other functions, eg underwrite
        // TODO unify validation into modifier and/or other suitable approaches
        // same as only registered product
        NftId productNftId = _registry.getNftId(msg.sender);
        require(productNftId.gtz(), "ERROR_PRODUCT_UNKNOWN");
        IRegistry.RegistryInfo memory productInfo = _registry.getInfo(
            productNftId
        );
        require(productInfo.objectType == PRODUCT(), "ERROR_NOT_PRODUCT");

        IRegistry.RegistryInfo memory instanceInfo = _registry.getInfo(
            productInfo.parentNftId
        );
        require(instanceInfo.nftId.gtz(), "ERROR_INSTANCE_UNKNOWN");
        require(instanceInfo.objectType == INSTANCE(), "ERROR_NOT_INSTANCE");

        // get involved modules
        address instanceAddress = instanceInfo.objectAddress;
        IPolicyModule policyModule = IPolicyModule(instanceAddress);
        uint256 premiumAmount = policyModule.getPremiumAmount(policyNftId);

        policyModule.processPremium(policyNftId, premiumAmount);

        // perform actual token transfers
        ITreasuryModule treasuryModule = ITreasuryModule(instanceAddress);
        _processPremiumByTreasury(treasuryModule, productNftId, policyNftId, premiumAmount);

        // TODO add logging
    }

    function close(
        NftId policyNftId
    ) external override // solhint-disable-next-line no-empty-blocks
    {

    }

    function _processPremiumByTreasury(
        ITreasuryModule treasuryModule,
        NftId productNftId,
        NftId policyNftId,
        uint256 premiumAmount
    )
        internal
    {
        ITreasury.ProductSetup memory product = treasuryModule.getProductSetup(productNftId);
        TokenHandler tokenHandler = product.tokenHandler;
        address policyOwner = _registry.getOwner(policyNftId);
        address poolWallet = treasuryModule.getPoolSetup(product.poolNftId).wallet;

        if (feeIsZero(product.policyFee)) {
            tokenHandler.transfer(
                policyOwner,
                poolWallet,
                premiumAmount
            );
        } else {
            (uint256 feeAmount, uint256 netAmount) = treasuryModule.calculateFeeAmount(
                premiumAmount,
                product.policyFee
            );

            tokenHandler.transfer(policyOwner, product.wallet, feeAmount);
            tokenHandler.transfer(policyOwner, poolWallet, netAmount);
        }
    }
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
