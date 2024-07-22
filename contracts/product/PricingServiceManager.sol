// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IVersionable} from "../upgradeability/IVersionable.sol";
import {ProxyManager} from "../upgradeability/ProxyManager.sol";
import {PricingService} from "./PricingService.sol";

contract PricingServiceManager is ProxyManager {

    PricingService private _pricingService;

    /// @dev initializes proxy manager with pricing service implementation and deploys instance
    constructor(
        address authority, 
        address registryAddress,
        bytes32 salt
    )
    {
        PricingService pricingSrv = new PricingService{salt: salt}();
        bytes memory data = abi.encode(registryAddress, authority);
        IVersionable versionable = initialize(
            registryAddress,
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