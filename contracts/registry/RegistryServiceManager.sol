// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IVersionable} from "../../contracts/shared/IVersionable.sol";

import {ProxyDeployer} from "../shared/Proxy.sol";
import {Registry} from "./Registry.sol";
import {RegistryService} from "./RegistryService.sol";


contract RegistryServiceManager is
    ProxyDeployer
{

    ProxyDeployer private _proxyDeployer;
    address private _implementation;

    constructor(address registryServiceImplementationAddress)
        ProxyDeployer()
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
