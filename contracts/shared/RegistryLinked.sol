// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;


import {ContractLib} from "../shared/ContractLib.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {IRegistryLinked} from "./IRegistryLinked.sol";

contract RegistryLinked is
    IRegistryLinked
{
    function getRegistry() external pure returns (IRegistry) {
        return ContractLib.getRegistry();
    }

    function _getRegistry() internal pure returns (IRegistry) {
        return ContractLib.getRegistry();
    }
}