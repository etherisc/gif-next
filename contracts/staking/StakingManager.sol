// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IVersionable} from "../shared/IVersionable.sol";
import {ProxyManager} from "../shared/ProxyManager.sol";
import {Staking} from "./Staking.sol";

contract StakingManager is
    ProxyManager
{

    Staking private _staking;

    /// @dev initializes proxy manager with service implementation 
    constructor(
        address registryAddress,
        address initialAuthority
    )
        ProxyManager(registryAddress)
    {
        Staking stk = new Staking();
        address initialOwner = msg.sender;

        bytes memory data = abi.encode(
            registryAddress, 
            initialAuthority, 
            initialOwner);

        IVersionable versionable = deploy(
            address(stk), 
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