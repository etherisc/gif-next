// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IProductService} from "../instance/service/IProductService.sol";
import {IProductComponent} from "./IProductComponent.sol";
import {NftId, zeroNftId} from "../types/NftId.sol";
import {ObjectType, PRODUCT} from "../types/ObjectType.sol";
import {Timestamp} from "../types/Timestamp.sol";
import {Fee, FeeLib} from "../types/Fee.sol";
import {BaseComponent} from "./BaseComponent.sol";
import {IComponent} from "../instance/module/component/IComponent.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {ITreasury} from "../instance/module/treasury/ITreasury.sol";

contract Product is BaseComponent, IProductComponent {

    IProductService private _productService;
    address private _pool;

    constructor(
        address registry,
        NftId instanceNftId,
        address token,
        address pool
    ) BaseComponent(registry, instanceNftId, token, PRODUCT()) {
        // TODO add validation
        _productService = _instance.getProductService();
        _pool = pool;
    }

    function _createApplication(
        address applicationOwner,
        uint256 sumInsuredAmount,
        uint256 premiumAmount,
        uint256 lifetime,
        NftId bundleNftId
    ) internal returns (NftId nftId) {
        nftId = _productService.createApplication(
            applicationOwner,
            sumInsuredAmount,
            premiumAmount,
            lifetime,
            bundleNftId
        );
    }

    function _underwrite(
        NftId policyNftId,
        bool requirePremiumPayment,
        Timestamp activateAt
    )
        internal
    {
        _productService.underwrite(
            policyNftId, 
            requirePremiumPayment, 
            activateAt);
    }

    function _collectPremium(
        NftId policyNftId,
        Timestamp activateAt
    )
        internal
    {
        _productService.collectPremium(
            policyNftId, 
            activateAt);
    }

    function _activate(
        NftId policyNftId,
        Timestamp activateAt
    )
        internal
    {
        _productService.activate(
            policyNftId, 
            activateAt);
    }

    function getPoolNftId() external view override returns (NftId poolNftId) {
        return _registry.getNftId(_pool);
    }

    // from product component
    function setFees(
        Fee memory policyFee,
        Fee memory processingFee
    )
        external
        onlyOwner
        override
    {
        _productService.setFees(policyFee, processingFee);
    }


    function getPolicyFee()
        external
        view
        override
        returns (Fee memory policyFee)
    {
        return _instance.getProductSetup(getNftId()).policyFee;
    }

    function getProcessingFee()
        external
        view
        override
        returns (Fee memory processingFee)
    {
        return _instance.getProductSetup(getNftId()).processingFee;
    }
    function getProductInfo() 
        external
        view 
        returns (IRegistry.ObjectInfo memory info, ITreasury.ProductSetup memory productSetup)
    {// TODO nftId from 2 different sources
        info = _registry.getObjectInfo(address(this));
        productSetup = _instance.getProductSetup(info.nftId);
    }
    function getInitialProductInfo() 
        external
        view 
        returns (IRegistry.ObjectInfo memory, ITreasury.ProductSetup memory)
    {
        return (getInitialInfo(), 
                ITreasury.ProductSetup(
                    zeroNftId(), // product
                    zeroNftId(), // distributor
                    _registry.getNftId(_pool),
                    _token,
                    _wallet,
                    FeeLib.zeroFee(), // policyFee
                    FeeLib.zeroFee()  // processingFee
                )
        );
    }
}
