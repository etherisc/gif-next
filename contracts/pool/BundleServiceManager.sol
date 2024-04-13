// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IVersionable} from "../shared/IVersionable.sol";
import {ProxyManager} from "../shared/ProxyManager.sol";
import {BundleService} from "./BundleService.sol";
import {Registry} from "../registry/Registry.sol";
import {RegistryService} from "../registry/RegistryService.sol";
import {ObjectType, REGISTRY} from "../type/ObjectType.sol";

contract BundleServiceManager is ProxyManager {

    BundleService private _bundleService;

    /// @dev initializes proxy manager with pool service implementation 
    constructor(
        address registryAddress
    )
        ProxyManager(registryAddress)
    {
        BundleService bundleSrv = new BundleService();
        bytes memory data = abi.encode(registryAddress, address(this));
        IVersionable versionable = deploy(
            address(bundleSrv), 
            data);

        _bundleService = BundleService(address(versionable));

        // TODO `this` must have a role or own nft to register service
        //Registry registry = Registry(registryAddress);
        //address registryServiceAddress = registry.getServiceAddress(REGISTRY(), _bundleService.getMajorVersion());
        //RegistryService registryService = RegistryService(registryServiceAddress); 
        //registryService.registerService(_poolService);
        
        // TODO no nft to link yet
        // link ownership of instance service manager ot nft owner of instance service
        //_linkToNftOwnable(
        //    address(registryAddress),
        //    address(_poolService));
    }

    //--- view functions ----------------------------------------------------//
    function getBundleService()
        external
        view
        returns (BundleService)
    {
        return _bundleService;
    }

}