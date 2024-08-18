// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IVersionable} from "../upgradeability/IVersionable.sol";
import {ProxyManager} from "../upgradeability/ProxyManager.sol";
import {RiskService} from "./RiskService.sol";

contract RiskServiceManager is ProxyManager {

    RiskService private _riskService;

    /// @dev initializes proxy manager with product service implementation 
    constructor(
        address authority, 
        address registry,
        bytes32 salt
    ) 
    {
        RiskService svc = new RiskService{salt: salt}();
        bytes memory data = abi.encode(authority, registry);
        IVersionable versionable = initialize(
            registry,
            address(svc), 
            data,
            salt);

        _riskService = RiskService(address(versionable));
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