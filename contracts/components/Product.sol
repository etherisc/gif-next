// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IProductService} from "../instance/product/IProductService.sol";
import {Component} from "./Component.sol";
import {IProductComponent} from "./IProduct.sol";
import {NftId} from "../types/NftId.sol";
import {ObjectType, PRODUCT} from "../types/ObjectType.sol";
import {Component} from "./Component.sol";


contract Product is
    Component,
    IProductComponent
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
        NftId bundleNftId
    )
        internal
        returns(NftId nftId)
    {
        nftId = _productService.createApplication(
            applicationOwner,
            sumInsuredAmount,
            premiumAmount,
            lifetime,
            bundleNftId
        );
    }

    function _underwrite(NftId nftId)
        internal
    {
        _productService.underwrite(nftId);
    }

    function getPoolNftId() external view override returns(NftId poolNftId) {
        return _registry.getNftId(_pool);
    }

    // from registerable
    function getType() public pure override returns(ObjectType) {
        return PRODUCT();
    }

    // from registerable
    function getData() external view override returns(bytes memory data) {
        return bytes(abi.encode(getInstance().getNftId()));
    }
}