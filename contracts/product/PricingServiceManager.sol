// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IVersionable} from "../shared/IVersionable.sol";
import {ProxyManager} from "../shared/ProxyManager.sol";
import {PricingService} from "./PricingService.sol";
import {Registry} from "../registry/Registry.sol";
import {RegistryService} from "../registry/RegistryService.sol";
import {REGISTRY} from "../type/ObjectType.sol";

contract PricingServiceManager is ProxyManager {

    PricingService private _pricingService;

    /// @dev initializes proxy manager with pricing service implementation and deploys instance
    constructor(
        address authority, 
        address registryAddress,
        bytes32 salt
    )
        ProxyManager(registryAddress)
    {
        PricingService pricingSrv = new PricingService{salt: salt}();
        bytes memory data = abi.encode(registryAddress, address(this), authority);
        IVersionable versionable = deployDetermenistic(
            address(pricingSrv), 
            data,
            salt);

        _pricingService = PricingService(address(versionable));
    }

    //--- view functions ----------------------------------------------------//
    function getPricingService()
        external
        view
        returns (PricingService)
    {
        return _pricingService;
    }

}