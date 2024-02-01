// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";

import {ContractDeployerLib} from "../shared/ContractDeployerLib.sol";

import {Registry} from "./Registry.sol";
import {IVersionable} from "../shared/IVersionable.sol";
import {ProxyManager} from "../shared/ProxyManager.sol";
import {RegistryService} from "./RegistryService.sol";
import {TokenRegistry} from "./TokenRegistry.sol";


contract RegistryServiceManager is
    ProxyManager
{
    bytes32 constant public ACCESS_MANAGER_CREATION_CODE_HASH = 0x0;

    RegistryService private immutable _registryService; 

    /// @dev initializes proxy manager with registry service implementation and deploys registry
    constructor(
        address initialAuthority, // used by implementation 
        address releaseManager) // used by registry
        ProxyManager()
    {
        // implementation's initializer func `data` argument
        bytes memory initializationData = abi.encode(
            initialAuthority,
            releaseManager,
            type(Registry).creationCode); 

        IVersionable versionable = deploy(
            address(new RegistryService()), 
            initializationData);

        _registryService = RegistryService(address(versionable));

        // link ownership of registry service manager ot nft owner of registry service
        _linkToNftOwnable(
            address(_registryService.getRegistry()),
            address(_registryService));
    }

    //--- view functions ----------------------------------------------------//

    function getRegistryService()
        external
        view
        returns (RegistryService registryService)
    {
        return _registryService;
    }
}
