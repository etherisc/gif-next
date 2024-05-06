// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IVersionable} from "../shared/IVersionable.sol";
import {NftIdSetManager} from "../shared/NftIdSetManager.sol";
import {ProxyManager} from "../shared/ProxyManager.sol";
import {Staking} from "./Staking.sol";
import {StakingReader} from "./StakingReader.sol";

contract StakingManager is
    ProxyManager
{

    Staking private _staking;

    /// @dev initializes proxy manager with service implementation 
    constructor(
        address initialAuthority,
        address registryAddress
    )
        ProxyManager(registryAddress)
    {
        Staking stk = new Staking();
        address stakingImplemenataion = address(stk);

        NftIdSetManager targetManager = new NftIdSetManager();
        StakingReader stakingReader = new StakingReader();
        address initialOwner = msg.sender;

        bytes memory data = abi.encode(
            initialAuthority, 
            registryAddress, 
            address(targetManager),
            address(stakingReader),
            initialOwner);

        IVersionable versionable = deploy(
            stakingImplemenataion, 
            data);

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