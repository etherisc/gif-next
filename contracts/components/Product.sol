// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IProductService} from "../instance/service/IProductService.sol";
import {IProductComponent} from "./IProductComponent.sol";
import {NftId} from "../types/NftId.sol";
import {ObjectType, PRODUCT} from "../types/ObjectType.sol";
import {Timestamp} from "../types/Timestamp.sol";
import {Fee} from "../types/Fee.sol";
import {BaseComponent} from "./BaseComponent.sol";

contract Product is BaseComponent, IProductComponent {
    IProductService private _productService;
    address private _pool;

    constructor(
        address registry,
        NftId instanceNftid,
        address token,
        address pool
    ) BaseComponent(registry, instanceNftid, token) {
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

    // from registerable
    function getType() public pure override returns (ObjectType) {
        return PRODUCT();
    }
}
