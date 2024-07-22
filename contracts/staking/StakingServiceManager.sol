// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IRegistry} from "../registry/IRegistry.sol";
import {IVersionable} from "../upgradeability/IVersionable.sol";
import {ProxyManager} from "../upgradeability/ProxyManager.sol";
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
    {
        StakingService svc = new StakingService();
        bytes memory data = abi.encode(
            authority, 
            registryAddress, 
            IRegistry(registryAddress).getStakingAddress());
        IVersionable versionable = initialize(
            registryAddress,
            address(svc), 
            data,
            salt);

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