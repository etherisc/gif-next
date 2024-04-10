// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IRegistry} from "../registry/IRegistry.sol";

interface IRegistryLinked {

    error ErrorNotRegistry(address registryAddress);

    function getRegistry() external view returns (IRegistry);
}