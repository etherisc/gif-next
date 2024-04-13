// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IVersionable} from "../shared/IVersionable.sol";
import {ProxyManager} from "../shared/ProxyManager.sol";
import {ProductService} from "./ProductService.sol";
import {Registry} from "../registry/Registry.sol";
import {RegistryService} from "../registry/RegistryService.sol";
import {VersionLib} from "../type/Version.sol";

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

        // Registry registry = Registry(registryAddress);
        // address registryServiceAddress = registry.getServiceAddress("RegistryService", VersionLib.toVersion(3, 0, 0).toMajorPart());
        // RegistryService registryService = RegistryService(registryServiceAddress);
        // TODO this must have a role or own nft to register service
        //registryService.registerService(_productService);
        
        // TODO no nft to link yet
        // link ownership of instance service manager ot nft owner of instance service
        //_linkToNftOwnable(
        //    address(registryAddress),
        //    address(_productService));

        // implies that after this constructor call only upgrade functionality is available
        // _isDeployed = true;
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