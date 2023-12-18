// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IVersionable} from "../shared/IVersionable.sol";
import {ProxyManager} from "../shared/ProxyManager.sol";
import {Registry} from "./Registry.sol";
import {RegistryService} from "./RegistryService.sol";


contract RegistryServiceManager is
    ProxyManager
{

    address private _implementation;

    constructor(address registryServiceImplementationAddress)
        ProxyManager()
    {
        _implementation = registryServiceImplementationAddress;
    }

    function deployRegistryService()
        external
        onlyOwner()
        returns (RegistryService registryService)
    {
        IVersionable versionable = deploy(
            _implementation, 
            type(Registry).creationCode);

        registryService = RegistryService(address(versionable));
    }
}
