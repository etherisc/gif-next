// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IUpgradeable} from "../upgradeability/IUpgradeable.sol";
import {ProxyManager} from "../upgradeability/ProxyManager.sol";
import {OracleService} from "./OracleService.sol";

contract OracleServiceManager is ProxyManager {

    OracleService private _oracleService;

    /// @dev initializes proxy manager with service implementation and deploys instance
    constructor(
        address authority, 
        address registry,
        bytes32 salt
    ) 
    {
        OracleService svc = new OracleService{salt: salt}();
        bytes memory data = abi.encode(authority, registry);
        IUpgradeable upgradeable = initialize(
            registry,
            address(svc), 
            data,
            salt);

        _oracleService = OracleService(address(upgradeable));
    }

    //--- view functions ----------------------------------------------------//
    function getOracleService()
        external
        view
        returns (OracleService oracleService)
    {
        return _oracleService;
    }

}