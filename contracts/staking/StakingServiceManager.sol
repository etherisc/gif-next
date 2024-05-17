// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IRegistry} from "../registry/IRegistry.sol";
import {IVersionable} from "../shared/IVersionable.sol";
import {ProxyManager} from "../shared/ProxyManager.sol";
import {StakingService} from "./StakingService.sol";

contract StakingServiceManager is
    ProxyManager
{

    StakingService private _stakingService;

    /// @dev initializes proxy manager with service implementation 
    constructor(
        address authority,
        address registryAddress,
        bytes32 salt
    )
        ProxyManager(registryAddress)
    {
        StakingService svc = new StakingService();
        bytes memory data = abi.encode(
            authority, 
            registryAddress, 
            IRegistry(registryAddress).getStakingAddress());
        IVersionable versionable = deployDetermenistic(
            address(svc), 
            data,
            salt);

        _stakingService = StakingService(address(versionable));
        _stakingService.registerProtocolTarget();
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