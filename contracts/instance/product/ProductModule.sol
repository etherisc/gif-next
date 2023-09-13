// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

// import {IProduct} from "../../components/IProduct.sol";
// import {IOwnable, IRegistryLinked, IRegisterable, IRegistry} from "../../registry/IRegistry.sol";
// import {IInstance} from "../IInstance.sol";
// import {IRegistry} from "../../registry/IRegistry.sol";
// import {IInstance} from "../../instance/IInstance.sol";
// import {IPolicy, IPolicyModule} from "../policy/IPolicy.sol";
// import {RegistryLinked} from "../../registry/Registry.sol";
import {IProductService} from "../services/IProductService.sol";
import {IProductModule} from "./IProductModule.sol";

abstract contract ProductModule is IProductModule {
    IProductService private _productService;

    constructor(address productService) {
        _productService = IProductService(productService);
    }

    function getProductService() external view returns (IProductService) {
        return _productService;
    }
}
