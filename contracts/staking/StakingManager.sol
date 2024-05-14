// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IVersionable} from "../shared/IVersionable.sol";
import {ProxyManager} from "../shared/ProxyManager.sol";
import {ReleaseManager} from "../registry/ReleaseManager.sol";
import {Staking} from "./Staking.sol";
import {StakingReader} from "./StakingReader.sol";
import {StakingStore} from "./StakingStore.sol";

contract StakingManager is
    ProxyManager
{

    error ErrorStakingManagerNotReleaseManager(address sender);

    Staking private _staking;
    address private _initialImplementation;
    bytes private _initializationData;

    /// @dev initializes proxy manager with service implementation 
    constructor(
        address registryAddress,
        address stakingStoreAddress,
        address initialOwner
    )
        ProxyManager(registryAddress)
    {
        // TODO cleanup
        // ReleaseManager releaseManager = ReleaseManager(
        //     getRegistry().getReleaseManagerAddress());
        // address authority = releaseManager.authority();

        Staking stakingImplementation = new Staking();
        // stakingStoreAddress
        // StakingStore stakingStore = new StakingStore(authority, registryAddress, address(stakingReader));
        StakingStore stakingStore = StakingStore(stakingStoreAddress);
        StakingReader stakingReader = stakingStore.getStakingReader();
        address authority = stakingStore.authority();

        _initialImplementation = address(stakingImplementation);
        _initializationData = abi.encode(
            authority,
            registryAddress,
            address(stakingReader),
            address(stakingStore),
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