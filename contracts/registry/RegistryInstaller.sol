// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Registry} from "./Registry.sol";
import {IRegistry} from "./IRegistry.sol";
import {IVersionable} from "../shared/IVersionable.sol";
import {ProxyManager} from "../shared/ProxyManager.sol";
import {RegistryService} from "./RegistryService.sol";


contract RegistryInstaller is
    ProxyManager
{
    error ErrorRegistryServiceWithZeroAddress();

    RegistryService private _registryService;

    /// @dev initializes proxy manager with registry service implementation and deploys registry
    constructor(
        // address registryServiceImplementationAddress, 
        // bytes memory registryBytecodeWithInitCode // type(Registry).creationCode
    )
        ProxyManager()
    {
        // if (registryServiceImplementationAddress == address(0)) { 
        //     revert ErrorRegistryServiceWithZeroAddress(); 
        // }

        IVersionable versionable = deploy(
            address(new RegistryService()), 
            type(Registry).creationCode);

        _registryService = RegistryService(address(versionable));

        // implies that after this constructor call only upgrade functionality is available
        _isDeployed = true;
    }

    //--- view functions ----------------------------------------------------//
    function getRegistryService()
        external
        view
        returns (RegistryService registryService)
    {
        return _registryService;
    }

    function getRegistry()
        external
        view
        returns (IRegistry registry)
    {
        return _registryService.getRegistry();
    }
}
