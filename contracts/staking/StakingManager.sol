// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IVersionable} from "../shared/IVersionable.sol";
import {ProxyManager} from "../shared/ProxyManager.sol";
import {ReleaseManager} from "../registry/ReleaseManager.sol";
import {Staking} from "./Staking.sol";
import {StakingReader} from "./StakingReader.sol";
import {StakingStore} from "./StakingStore.sol";

import {RegistryAdmin} from "../registry/RegistryAdmin.sol";

contract StakingManager is
    ProxyManager
{
    Staking private _staking;
    address private _initialImplementation;
    bytes private _initializationData;

    /// @dev initializes proxy manager with service implementation 
    constructor(
        address registry,
        address tokenRegistry,
        address stakingStore,
        address initialOwner
    )
        ProxyManager(registry)
    {
        Staking stakingImplementation = new Staking();

        _initialImplementation = address(stakingImplementation);
        _initializationData = abi.encode(
            registry,
            tokenRegistry,
            stakingStore,
            initialOwner);

        IVersionable versionable = deploy(
            _initialImplementation, 
            _initializationData);

        _staking = Staking(address(versionable));
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
