// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IVersionable} from "../upgradeability/IVersionable.sol";
import {ProxyManager} from "../upgradeability/ProxyManager.sol";
import {PoolService} from "./PoolService.sol";

contract PoolServiceManager is ProxyManager {

    PoolService private _poolService;

    /// @dev initializes proxy manager with pool service implementation 
    constructor(
        address authority, 
        address registry,
        bytes32 salt
    ) 
    {
        PoolService poolSrv = new PoolService{salt: salt}();
        bytes memory data = abi.encode(authority, registry);
        IVersionable versionable = initialize(
            registry,
            address(poolSrv), 
            data,
            salt);

        _poolService = PoolService(address(versionable));
    }

    //--- view functions ----------------------------------------------------//
    function getPoolService()
        external
        view
        returns (PoolService poolService)
    {
        return _poolService;
    }

}