// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IProductService} from "../instance/product/IProductService.sol";
import {Component} from "./Component.sol";
import {IProductComponent} from "./IProduct.sol";
import {NftId} from "../types/NftId.sol";
import {ObjectType, PRODUCT} from "../types/ObjectType.sol";
import {Fee} from "../types/Fee.sol";
import {Component} from "./Component.sol";

contract Product is Component, IProductComponent {
    IProductService private _productService;
    address private _pool;
    Fee private _policyFee;
    Fee private _processingFee;

    constructor(
        address registry,
        address instance,
        address token,
        address pool,
        Fee memory policyFee,
        Fee memory processingFee
    )
        Component(registry, instance, token)
    {
        // TODO add validation
        _productService = _instance.getProductService();
        _pool = pool;
        _policyFee = policyFee;
        _processingFee = processingFee;
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

    function _underwrite(NftId nftId) internal {
        _productService.underwrite(nftId);
    }

    function _collectPremium(NftId nftId) internal {
        _productService.collectPremium(nftId);
    }

    function getPoolNftId() external view override returns (NftId poolNftId) {
        return _registry.getNftId(_pool);
    }

    // from product component
    function getPolicyFee() external view override returns(Fee memory policyFee) {
        return _policyFee;
    }

    function getProcessingFee() external view override returns(Fee memory processingFee) {
        return _processingFee;
    }

    // from registerable
    function getType() public pure override returns(ObjectType) {
        return PRODUCT();
    }

    // from registerable
    function getData() external view override returns (bytes memory data) {
        return bytes(abi.encode(getInstance().getNftId()));
    }
}
