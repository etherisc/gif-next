// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IUpgradeable} from "../upgradeability/IUpgradeable.sol";
import {ProxyManager} from "../upgradeability/ProxyManager.sol";
import {DistributionService} from "./DistributionService.sol";

contract DistributionServiceManager is ProxyManager {

    DistributionService private _distributionService;

    /// @dev initializes proxy manager with distribution service implementation and deploys instance
    constructor(
        address authority, 
        bytes32 salt
    ) 
    {
        DistributionService svc = new DistributionService{salt: salt}();
        bytes memory data = abi.encode(authority);
        IUpgradeable upgradeable = initialize(
            address(svc), 
            data,
            salt);

        _distributionService = DistributionService(address(upgradeable));
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