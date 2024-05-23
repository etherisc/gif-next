// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IVersionable} from "../shared/IVersionable.sol";
import {ProxyManager} from "../shared/ProxyManager.sol";
import {OracleService} from "./OracleService.sol";
import {Registry} from "../registry/Registry.sol";
import {RegistryService} from "../registry/RegistryService.sol";
import {REGISTRY} from "../type/ObjectType.sol";

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