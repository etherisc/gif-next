// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;


// import {IOwnable, IRegistryLinked, IRegisterable} from "../../registry/IRegistry.sol";

import {IProductService} from "../product/IProductService.sol";
import {IPolicy, IPolicyModule} from "./IPolicy.sol";

abstract contract PolicyModule is
    IPolicyModule
{

    IProductService private _productService;

    modifier onlyProductService() {
        require(address(_productService) == msg.sender, "ERROR:POL-001:NOT_PRODUCT_SERVICE");
        _;
    }

    constructor(address productService) {
        _productService = IProductService(productService);
    }


    function getProductService()
        external
        view
        override
        returns(IProductService)
    {
        return _productService;
    }
}
