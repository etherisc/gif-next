// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IVersionable} from "../upgradeability/IVersionable.sol";
import {ProxyManager} from "../upgradeability/ProxyManager.sol";
import {OracleService} from "./OracleService.sol";

contract OracleServiceManager is ProxyManager {

    OracleService private _oracleService;

    /// @dev initializes proxy manager with service implementation and deploys instance
    constructor(
        address authority, 
        address registryAddress,
        bytes32 salt
    ) 
        ProxyManager(registryAddress)
    {
        OracleService orclSrv = new OracleService{salt: salt}();
        bytes memory data = abi.encode(registryAddress, address(this), authority);
        IVersionable versionable = deployDetermenistic(
            address(orclSrv), 
            data,
            salt);

        _oracleService = OracleService(address(versionable));
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