// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

import {IRegistry} from "../../registry/IRegistry.sol";
import {RegistryLinked} from "../../shared/RegistryLinked.sol";

abstract contract Cloneable is 
    AccessManagedUpgradeable,
    RegistryLinked
{
    /// @dev call to initialize MUST be made in the same transaction as cloning of the contract
    function __Cloneable_init(
        address authority
    )
        internal 
        onlyInitializing
    {
        __AccessManaged_init(authority);
    }
}
