// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IVersionable} from "../shared/IVersionable.sol";
import {ProxyManager} from "../shared/ProxyManager.sol";
import {ApplicationService} from "./ApplicationService.sol";

contract ApplicationServiceManager is ProxyManager {

    ApplicationService private _applicationService;

    /// @dev initializes proxy manager with service implementation 
    constructor(
        address authority, 
        address registryAddress,
        bytes32 salt
    ) 
        ProxyManager(registryAddress)
    {
        ApplicationService svc = new ApplicationService{salt: salt}();
        bytes memory data = abi.encode(registryAddress, address(this), authority);
        IVersionable versionable = deployDetermenistic(
            address(svc), 
            data,
            salt);

        _applicationService = ApplicationService(address(versionable));
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