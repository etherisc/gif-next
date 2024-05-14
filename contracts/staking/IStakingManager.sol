// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

interface IStakingManager {

    /// @dev initializes staking manager with authority of registry access manager.
    function initialize(
        address authority
    )
        external;


    function getStakingAddress() external view returns (address staking);

}