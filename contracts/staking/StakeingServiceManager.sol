// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IVersionable} from "../shared/IVersionable.sol";
import {ProxyManager} from "../shared/ProxyManager.sol";
import {StakingService} from "./StakingService.sol";

contract StakingServiceManager is
    ProxyManager
{

    StakingService private _stakingService;

    /// @dev initializes proxy manager with service implementation 
    constructor(
        address registryAddress
    )
        ProxyManager(registryAddress)
    {
        StakingService svc = new StakingService();
        bytes memory data = abi.encode(registryAddress, address(this));
        IVersionable versionable = deploy(
            address(svc), 
            data);

        _stakingService = StakingService(address(versionable));
    }

    //--- view functions ----------------------------------------------------//
    function getStakingService()
        external
        view
        returns (StakingService)
    {
        return _stakingService;
    }
}