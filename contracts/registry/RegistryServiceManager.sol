// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AccessManager} from "@openzeppelin5/contracts/access/manager/AccessManager.sol";

import {ContractDeployerLib} from "../shared/ContractDeployerLib.sol";

import {Registry} from "./Registry.sol";
import {IVersionable} from "../shared/IVersionable.sol";
import {ProxyManager} from "../shared/ProxyManager.sol";
import {RegistryService} from "./RegistryService.sol";


contract RegistryServiceManager is
    ProxyManager
{
    bytes32 constant public ACCESS_MANAGER_CREATION_CODE_HASH = 0x0;

    RegistryService private _registryService; 

    AccessManager _accessManager;

    /// @dev initializes proxy manager with registry service implementation and deploys registry
    constructor(
    )
        ProxyManager()
    {
        bytes memory encodedConstructorArguments = abi.encode(msg.sender);

        bytes memory accessManagerCreationCode = ContractDeployerLib.getCreationCode(
            type(AccessManager).creationCode,
            encodedConstructorArguments);

        address accessManagerAddress = ContractDeployerLib.deploy(
            accessManagerCreationCode,
            ACCESS_MANAGER_CREATION_CODE_HASH);

        _accessManager = AccessManager(accessManagerAddress);


        IVersionable versionable = deploy(
            address(new RegistryService()), 
            type(Registry).creationCode);

        _registryService = RegistryService(address(versionable));

        // link ownership of registry service manager ot nft owner of registry service
        _linkToNftOwnable(
            address(_registryService.getRegistry()),
            address(_registryService));

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

    function getAccessManager()
        external
        view
        returns (RegistryService registryService)
    {
        return _accessManager;
    }
}
