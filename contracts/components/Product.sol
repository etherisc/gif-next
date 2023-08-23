// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IProductService} from "../instance/product/IProductService.sol";
import {Component} from "./Component.sol";
import {IProduct} from "./IProduct.sol";


contract Product is
    Component,
    IProduct
{
    IProductService private _productService;
    address private _pool;

    constructor(
        address registry, 
        address instance, 
        address pool
    )
        Component(registry, instance)
    { 
        _productService = _instance.getProductService();
        _pool = pool;
    }

    function _createApplication(
        address applicationOwner,
        uint256 sumInsuredAmount,
        uint256 premiumAmount,
        uint256 lifetime,
        uint256 bundleNftId
    )
        internal
        returns(uint256 nftId)
    {
        nftId = _productService.createApplication(
            applicationOwner,
            sumInsuredAmount,
            premiumAmount,
            lifetime,
            bundleNftId
        );
    }

    function getPoolNftId() external view override returns(uint256 poolNftId) {
        return _registry.getNftId(_pool);
    }

    // from registerable
    function getType() public view override returns(uint256) {
        return _registry.PRODUCT();
    }

    // from registerable
    function getData() external view override returns(bytes memory data) {
        return bytes(abi.encode(getInstance().getNftId()));
    }
}