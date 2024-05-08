// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IVersionable} from "./IVersionable.sol";
import {ProxyManager} from "./ProxyManager.sol";
import {ComponentService} from "./ComponentService.sol";

contract ComponentServiceManager is ProxyManager {

    ComponentService private _componentService;

    /// @dev initializes proxy manager with service implementation 
    constructor(
        address registryAddress
    )
        ProxyManager(registryAddress)
    {
        ComponentService svc = new ComponentService();
        bytes memory data = abi.encode(registryAddress, address(this));
        IVersionable versionable = deploy(
            address(svc), 
            data);

        _componentService = ComponentService(address(versionable));
    }

    //--- view functions ----------------------------------------------------//
    function getComponentService()
        external
        view
        returns (ComponentService)
    {
        return _componentService;
    }
}