// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegistry} from "../registry/IRegistry.sol";

interface IRegistryLinked {
    function getRegistry() external view returns (IRegistry registry);
}
