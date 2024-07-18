// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IVersionable} from "../upgradeability/IVersionable.sol";
import {ProxyManager} from "../upgradeability/ProxyManager.sol";
import {DistributionService} from "./DistributionService.sol";

contract DistributionServiceManager is ProxyManager {

    DistributionService private _distributionService;

    /// @dev initializes proxy manager with distribution service implementation and deploys instance
    constructor(
        address authority, 
        address registryAddress,
        bytes32 salt
    ) 
        ProxyManager(registryAddress)
    {
        DistributionService distSrv = new DistributionService{salt: salt}();
        bytes memory data = abi.encode(registryAddress, address(this), authority);
        IVersionable versionable = deployDetermenistic(
            address(distSrv), 
            data,
            salt);

        _distributionService = DistributionService(address(versionable));
    }

    //--- view functions ----------------------------------------------------//
    function getDistributionService()
        external
        view
        returns (DistributionService distributionService)
    {
        return _distributionService;
    }

}