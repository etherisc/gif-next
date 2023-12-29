// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Instance} from "./Instance.sol";
import {IVersionable} from "../shared/IVersionable.sol";
import {ProxyManager} from "../shared/ProxyManager.sol";
import {InstanceService} from "./InstanceService.sol";

contract InstanceServiceManager is ProxyManager {

    InstanceService private _instanceService;

    /// @dev initializes proxy manager with instance service implementation and deploys instance
    constructor(
        address registryAddress
    )
        ProxyManager()
    {
        IVersionable versionable = deploy(
            address(new InstanceService(registryAddress)), 
            type(Instance).creationCode);

        _instanceService = InstanceService(address(versionable));

        // link ownership of instance service manager ot nft owner of instance service
        _linkToNftOwnable(
            address(_instanceService.getInstance()),
            address(_instanceService));

        // implies that after this constructor call only upgrade functionality is available
        _isDeployed = true;
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