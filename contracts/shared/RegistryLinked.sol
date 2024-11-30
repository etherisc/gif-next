// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol"; 

import {ContractLib} from "../shared/ContractLib.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {IRegistryLinked} from "./IRegistryLinked.sol";

contract RegistryLinked is
    Initializable,
    IRegistryLinked
{
    // priorize simplicity and size over using standard upgradeability structs
    // may interfere with proxy storage when used for upgradeable contracts
    IRegistry private _registry; 

    /// @dev initialization for upgradable contracts
    // used in _initializeRegisterable
    function __RegistryLinked_init(
        address registry
    )
        internal
        virtual
        onlyInitializing()
    {
        if (!ContractLib.isRegistry(registry)) {
            revert ErrorNotRegistry(registry);
        }

        _registry = IRegistry(registry);
    }


    function getRegistry() public view returns (IRegistry) {
        return _registry;
    }
}