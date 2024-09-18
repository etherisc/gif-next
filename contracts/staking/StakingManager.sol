// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IUpgradeable} from "../upgradeability/IUpgradeable.sol";
import {ProxyManager} from "../upgradeability/ProxyManager.sol";
import {Staking} from "./Staking.sol";


contract StakingManager is
    ProxyManager
{
    Staking private _staking;
    address private _initialImplementation;
    bytes private _initializationData;

    /// @dev initializes proxy manager with service implementation 
    constructor(
        address registry,
        address targetHandler,
        address stakingStore,
        address tokenRegistry,
        address initialOwner,
        bytes32 salt
    )
    {
        Staking stakingImplementation = new Staking();

        _initialImplementation = address(stakingImplementation);
        _initializationData = abi.encode(
            registry,
            targetHandler,
            stakingStore,
            tokenRegistry);
        
        IUpgradeable upgradeable = initialize(
            registry,
            _initialImplementation,
            _initializationData,
            salt);

        _staking = Staking(address(upgradeable));
    }

    //--- view functions ----------------------------------------------------//

    function getStaking()
        external
        view
        returns (Staking)
    {
        return _staking;
    }
}
