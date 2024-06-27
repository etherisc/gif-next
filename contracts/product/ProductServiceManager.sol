// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IVersionable} from "../upgradeability/IVersionable.sol";
import {ProxyManager} from "../upgradeability/ProxyManager.sol";
import {ProductService} from "./ProductService.sol";

contract ProductServiceManager is ProxyManager {

    ProductService private _productService;

    /// @dev initializes proxy manager with product service implementation 
    constructor(
        address authority, 
        address registryAddress,
        bytes32 salt
    ) 
        ProxyManager(registryAddress)
    {
        ProductService svc = new ProductService{salt: salt}();
        bytes memory data = abi.encode(registryAddress, address(this), authority);
        IVersionable versionable = deployDetermenistic(
            address(svc), 
            data,
            salt);

        _productService = ProductService(address(versionable));
    }

    //--- view functions ----------------------------------------------------//
    function getProductService()
        external
        view
        returns (ProductService productService)
    {
        return _productService;
    }

}