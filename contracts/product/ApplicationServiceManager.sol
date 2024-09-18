// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IUpgradeable} from "../upgradeability/IUpgradeable.sol";
import {ProxyManager} from "../upgradeability/ProxyManager.sol";
import {ApplicationService} from "./ApplicationService.sol";

contract ApplicationServiceManager is ProxyManager {

    ApplicationService private _applicationService;

    /// @dev initializes proxy manager with service implementation 
    constructor(
        address authority, 
        address registry,
        bytes32 salt
    ) 
    {
        ApplicationService svc = new ApplicationService{salt: salt}();
        bytes memory data = abi.encode(authority, registry);
        IUpgradeable upgradeable = initialize(
            registry,
            address(svc), 
            data,
            salt);

        _applicationService = ApplicationService(address(upgradeable));
    }

    //--- view functions ----------------------------------------------------//
    function getApplicationService()
        external
        view
        returns (ApplicationService)
    {
        return _applicationService;
    }
}