// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol"; 
import {IRegistry} from "../registry/IRegistry.sol";
import {IRegistryLinked} from "./IRegistryLinked.sol";

contract RegistryLinked is
    Initializable,
    IRegistryLinked
{

    IRegistry private _registry;

    /// @dev initialization for upgradable contracts
    // used in _initializeRegisterable
    function initializeRegistryLinked(
        address registryAddress
    )
        public
        virtual
        onlyInitializing()
    {
        if (registryAddress.code.length == 0) {
            revert ErrorNotRegistry(registryAddress);
        }

        _registry = IRegistry(registryAddress);

        try _registry.supportsInterface(type(IRegistry).interfaceId) returns (bool isRegistry) {
            if (!isRegistry) {
                revert ErrorNotRegistry(registryAddress);
            }
        } catch {
            revert ErrorNotRegistry(registryAddress);
        }
    }


    function getRegistry() public view returns (IRegistry) {
        return _registry;
    }


    function getRegistryAddress() public view returns (address) {
        return address(_registry);
    }
}