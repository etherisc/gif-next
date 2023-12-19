// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IRegistry} from "./IRegistry.sol";
import {IVersionable} from "../shared/IVersionable.sol";
import {ProxyManager} from "../shared/ProxyManager.sol";
import {RegistryService} from "./RegistryService.sol";


contract RegistryInstaller is
    ProxyManager
{
    error ErrorRegistryServiceWithZeroAddress();
    error ErrorDeployNotSupported();
    error ErrorDeployWithSaltNotSupported();

    RegistryService private _registryService;

    /// @dev initializes proxy manager with registry service implementation and deploys registry
    constructor(
        address registryServiceImplementationAddress, 
        bytes memory registryBytecodeWithInitCode // type(Registry).creationCode
    )
        ProxyManager()
    {
        if (registryServiceImplementationAddress == address(0)) { 
            revert ErrorRegistryServiceWithZeroAddress(); 
        }

        IVersionable versionable = super.deploy(
            registryServiceImplementationAddress, 
            registryBytecodeWithInitCode);

        _registryService = RegistryService(address(versionable));
        _isDeployed = true;
    }

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

    function deploy(address initialImplementation, bytes memory initializationData)
        public
        virtual override
        returns (IVersionable versionable)
    {
        revert ErrorDeployNotSupported();
    }

    function deployWithSalt(address initialImplementation, bytes memory initializationData, bytes32 salt)
        public
        virtual override
        returns (IVersionable versionable)
    {
        revert ErrorDeployWithSaltNotSupported();
    }
}
