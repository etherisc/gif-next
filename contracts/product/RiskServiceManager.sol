// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IUpgradeable} from "../upgradeability/IUpgradeable.sol";
import {ProxyManager} from "../upgradeability/ProxyManager.sol";
import {RiskService} from "./RiskService.sol";

contract RiskServiceManager is ProxyManager {

    RiskService private _riskService;

    /// @dev initializes proxy manager with product service implementation 
    constructor(
        address authority, 
        bytes32 salt
    ) 
    {
        RiskService svc = new RiskService{salt: salt}();
        bytes memory data = abi.encode(authority);
        IUpgradeable upgradeable = initialize(
            address(svc), 
            data,
            salt);

        _riskService = RiskService(address(upgradeable));
    }

    //--- view functions ----------------------------------------------------//
    function getRiskService()
        external
        view
        returns (RiskService riskService)
    {
        return _riskService;
    }

}