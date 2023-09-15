// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IComponentOwnerService} from "./service/IComponentOwnerService.sol";
import {IProductService} from "./service/IProductService.sol";
import {IPoolService} from "./service/IPoolService.sol";

import {IServiceLinked} from "./IServiceLinked.sol";

contract ServiceLinked is IServiceLinked {
    IComponentOwnerService private _componentOwnerService;
    IProductService private _productService;
    IPoolService private _poolService;

    constructor(
        address componentOwnerService,
        address productService,
        address poolService
    )
    {
        _componentOwnerService = IComponentOwnerService(componentOwnerService);
        _productService = IProductService(productService);
        _poolService = IPoolService(poolService);
    }

    function getCompnentOwnerService() external view override returns(IComponentOwnerService service) { return _componentOwnerService; }
    function getProductService() external view override returns(IProductService service) { return _productService; }
    function getPoolService() external view override returns(IPoolService service) { return _poolService; }

    function senderIsProductService() external view override returns(bool isService) { return msg.sender == address(_productService); }
    function senderIsPoolService() external view override returns(bool isService) { return msg.sender == address(_poolService); }
}
