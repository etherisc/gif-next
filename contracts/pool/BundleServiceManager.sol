// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IUpgradeable} from "../upgradeability/IUpgradeable.sol";
import {ProxyManager} from "../upgradeability/ProxyManager.sol";
import {BundleService} from "./BundleService.sol";

contract BundleServiceManager is ProxyManager {

    BundleService private _bundleService;

    /// @dev initializes proxy manager with pool service implementation 
    constructor(
        address authority, 
        address registry,
        bytes32 salt
    ) 
    {
        BundleService svc = new BundleService{salt: salt}();
        bytes memory data = abi.encode(authority, registry);
        IUpgradeable upgradeable = initialize(
            registry,
            address(svc), 
            data,
            salt);

        _bundleService = BundleService(address(upgradeable));
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