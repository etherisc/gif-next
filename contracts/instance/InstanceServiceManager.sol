// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IVersionable} from "../upgradeability/IVersionable.sol";
import {ProxyManager} from "../upgradeability/ProxyManager.sol";
import {InstanceService} from "./InstanceService.sol";

contract InstanceServiceManager is ProxyManager {

    InstanceService private _instanceService;

    /// @dev initializes proxy manager with instance service implementation
    constructor(
        address authority, 
        address registry,
        bytes32 salt
    ) 
    {
        InstanceService svc = new InstanceService{salt: salt}();
        bytes memory data = abi.encode(authority, registry);
        IVersionable versionable = initialize(
            registry,
            address(svc), 
            data,
            salt);

        _instanceService = InstanceService(address(versionable));
    }

    //--- view functions ----------------------------------------------------//
    function getInstanceService()
        external
        view
        returns (InstanceService instanceService)
    {
        return _instanceService;
    }

}