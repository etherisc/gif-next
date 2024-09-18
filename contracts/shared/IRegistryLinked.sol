// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IRegistry} from "../registry/IRegistry.sol";

interface IRegistryLinked {

    error ErrorRegistryLinkedRegistryAlreadyInitialized(address target, address registry);
    error ErrorRegistryLinkedNotRegistry(address target, address notRegistry);
    error ErrorRegistryLinkedRegistryMismatch(address target, address givenRegistry, address pureRegistry);

    function getRegistry() external view returns (IRegistry);
}