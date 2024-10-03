// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IComponent} from "../shared/IComponent.sol";
import {IAuthorization} from "../authorization/IAuthorization.sol";

/// @dev component base class
/// component examples are product, distribution, pool and oracle
interface IAuthorizedComponent is 
    IComponent
{
    /// @dev returns the initial component authorization specification.
    function getAuthorization() external view returns (IAuthorization authorization);

}