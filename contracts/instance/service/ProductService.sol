// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

// import {IProduct} from "../../components/IProduct.sol";
// import {IOwnable, IRegistryLinked, IRegisterable, IRegistry} from "../../registry/IRegistry.sol";
// import {IInstance} from "../IInstance.sol";
import {IRegistry} from "../../registry/IRegistry.sol";
import {IInstance} from "../../instance/IInstance.sol";
import {IPolicy, IPolicyModule} from "../policy/IPolicy.sol";
import {RegistryLinked} from "../../registry/Registry.sol";
import {IProductService} from "./IProductService.sol";
import {ITreasury, ITreasuryModule, TokenHandler} from "../../instance/treasury/ITreasury.sol";
// import {IPoolModule} from "../../instance/pool/IPoolModule.sol";
import {ObjectType, INSTANCE, PRODUCT} from "../../types/ObjectType.sol";
import {NftId, NftIdLib} from "../../types/NftId.sol";
import {Fee, feeIsZero} from "../../types/Fee.sol";

// TODO or name this ProtectionService to have Product be something more generic (loan, savings account, ...)
contract ProductService is RegistryLinked, IProductService {
    using NftIdLib for NftId;

    constructor(
        address registry
    ) RegistryLinked(registry) // solhint-disable-next-line no-empty-blocks
    {

    }

    function setFees(
        Fee memory policyFee,
        Fee memory processingFee
    )
        external
        override
    {
        (IRegistry.ObjectInfo memory productInfo, IInstance instance) = _verifyAndGetProductAndInstance();
        instance.setProductFees(productInfo.nftId, policyFee, processingFee);
    }

    function createApplication(
        address applicationOwner,
        uint256 sumInsuredAmount,
        uint256 premiumAmount,
        uint256 lifetime,
        NftId bundleNftId
    ) external override returns (NftId nftId) {
        (IRegistry.ObjectInfo memory productInfo, IInstance instance) = _verifyAndGetProductAndInstance();

        nftId = instance.createApplication(
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
        (IRegistry.ObjectInfo memory productInfo, IInstance instance) = _verifyAndGetProductAndInstance();

        instance.underwrite(policyNftId, productInfo.nftId);
        instance.activate(policyNftId);

        // TODO add logging
    }

    function collectPremium(NftId policyNftId) external override {
        (IRegistry.ObjectInfo memory productInfo, IInstance instance) = _verifyAndGetProductAndInstance();

        // // TODO unify validation into modifier and/or other suitable approaches
        // // same as only registered product
        // NftId productNftId = _registry.getNftId(msg.sender);
        // require(productNftId.gtz(), "ERROR_PRODUCT_UNKNOWN");
        // IRegistry.ObjectInfo memory productInfo = _registry.getInfo(
        //     productNftId
        // );
        // require(productInfo.objectType == PRODUCT(), "ERROR_NOT_PRODUCT");

        // IRegistry.ObjectInfo memory instanceInfo = _registry.getInfo(
        //     productInfo.parentNftId
        // );
        // require(instanceInfo.nftId.gtz(), "ERROR_INSTANCE_UNKNOWN");
        // require(instanceInfo.objectType == INSTANCE(), "ERROR_NOT_INSTANCE");

        // get involved modules
        // address instanceAddress = instanceInfo.objectAddress;
        // IPolicyModule policyModule = IPolicyModule(instanceAddress);
        uint256 premiumAmount = instance.getPremiumAmount(policyNftId);

        instance.processPremium(policyNftId, premiumAmount);

        // perform actual token transfers
        // ITreasuryModule treasuryModule = ITreasuryModule(instanceAddress);
        _processPremiumByTreasury(instance, productInfo.nftId, policyNftId, premiumAmount);

        // TODO add logging
    }

    function close(
        NftId policyNftId
    ) external override // solhint-disable-next-line no-empty-blocks
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
        NftId productNftId = _registry.getNftId(msg.sender);
        require(productNftId.gtz(), "ERROR_PRODUCT_UNKNOWN");

        productInfo = _registry.getObjectInfo(productNftId);
        require(productInfo.objectType == PRODUCT(), "ERROR_NOT_PRODUCT");

        // TODO check if this is really needed or if registry may be considered reliable
        IRegistry.ObjectInfo memory instanceInfo = _registry.getObjectInfo(productInfo.parentNftId);
        require(instanceInfo.nftId.gtz(), "ERROR_INSTANCE_UNKNOWN");
        require(instanceInfo.objectType == INSTANCE(), "ERROR_NOT_INSTANCE");

        instance = IInstance(instanceInfo.objectAddress);
    }

    function _processPremiumByTreasury(
        IInstance instance,
        NftId productNftId,
        NftId policyNftId,
        uint256 premiumAmount
    )
        internal
    {
        ITreasury.ProductSetup memory product = instance.getProductSetup(productNftId);
        TokenHandler tokenHandler = product.tokenHandler;
        address policyOwner = _registry.getOwner(policyNftId);
        address poolWallet = instance.getPoolSetup(product.poolNftId).wallet;

        if (feeIsZero(product.policyFee)) {
            tokenHandler.transfer(
                policyOwner,
                poolWallet,
                premiumAmount
            );
        } else {
            (uint256 feeAmount, uint256 netAmount) = instance.calculateFeeAmount(
                premiumAmount,
                product.policyFee
            );

            tokenHandler.transfer(policyOwner, product.wallet, feeAmount);
            tokenHandler.transfer(policyOwner, poolWallet, netAmount);
        }
    }
}
