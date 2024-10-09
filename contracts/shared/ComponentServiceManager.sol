// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ComponentService} from "./ComponentService.sol";
import {IUpgradeable} from "../upgradeability/IUpgradeable.sol";
import {ProxyManager} from "../upgradeability/ProxyManager.sol";

contract ComponentServiceManager is ProxyManager {

    ComponentService private _componentService;

    /// @dev initializes proxy manager with service implementation 
    constructor(
        address authority,
        bytes32 salt
    )
    {
        ComponentService svc = new ComponentService();
        bytes memory data = abi.encode(authority);
        IUpgradeable upgradeable = initialize(
            address(svc), 
            data,
            salt);

        _componentService = ComponentService(address(upgradeable));
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