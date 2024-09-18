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
    // registry address MUST NOT be upgraded
    IRegistry private _registry;

    /// @dev initialization for upgradable contracts
    // used in RegistryAdmin / InstanceAdmin / ReleaseAdmin.completeSetup()
    function __RegistryLinked_init(
        address registry
    )
        internal
        virtual
        //onlyInitializing()
    {
        //if(address(_registry) != address(0) ) {
        //    revert ErrorRegistryLinkedRegistryAlreadyInitialized(address(this), address(_registry));
        //}

        if(address(_registry) != address(0) ) {
            if(_registry != IRegistry(registry)) {
                revert ErrorRegistryLinkedRegistryAlreadyInitialized(address(this), address(_registry));
            }
            return;
        }

        if (!ContractLib.isRegistry(registry)) {
            revert ErrorRegistryLinkedNotRegistry(address(this), registry);
        }

        _registry = IRegistry(registry);
    }


    function getRegistry() public view returns (IRegistry) {
        return _registry;
    }
}