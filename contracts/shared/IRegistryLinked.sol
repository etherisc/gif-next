// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IRegistry} from "../registry/IRegistry.sol";

interface IRegistryLinked {

    function getRegistry() external pure returns (IRegistry);
}