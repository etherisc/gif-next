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
        address authority, 
        address registryAddress,
        bytes32 salt
    ) 
        ProxyManager(registryAddress)
    {
        BundleService bundleSrv = new BundleService{salt: salt}();
        bytes memory data = abi.encode(registryAddress, address(this), authority);
        IVersionable versionable = deployDetermenistic(
            address(bundleSrv), 
            data,
            salt);

        _bundleService = BundleService(address(versionable));
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