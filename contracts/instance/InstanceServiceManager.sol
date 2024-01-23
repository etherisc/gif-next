// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Instance} from "./Instance.sol";
import {IVersionable} from "../shared/IVersionable.sol";
import {ProxyManager} from "../shared/ProxyManager.sol";
import {InstanceService} from "./InstanceService.sol";
import {Registry} from "../registry/Registry.sol";
import {RegistryService} from "../registry/RegistryService.sol";
import {VersionLib} from "../types/Version.sol";

contract InstanceServiceManager is ProxyManager {

    InstanceService private _instanceService;

    /// @dev initializes proxy manager with instance service implementation and deploys instance
    constructor(
        address registryAddress
    )
        ProxyManager()
    {
        InstanceService instSrv = new InstanceService();
        // bytes memory initCode = type(InstanceService).creationCode;
        bytes memory data = abi.encode(registryAddress, address(this));
        IVersionable versionable = deploy(
            address(instSrv), 
            data);

        _instanceService = InstanceService(address(versionable));

        Registry registry = Registry(registryAddress);
        address registryServiceAddress = registry.getServiceAddress("RegistryService", VersionLib.toVersion(3, 0, 0).toMajorPart());
        RegistryService registryService = RegistryService(registryServiceAddress);
        // TODO this must have a role or own nft to register service
        //registryService.registerService(_instanceService);
        // RegistryService registryService = _instanceService.getRegistryService();

        // TODO no nft to link yet
        // link ownership of instance service manager ot nft owner of instance service
        //_linkToNftOwnable(
        //    address(registryAddress),
        //    address(_instanceService));

        // implies that after this constructor call only upgrade functionality is available
        _isDeployed = true;
    }

    //--- view functions ----------------------------------------------------//
    function getInstanceService()
        external
        view
        returns (InstanceService instanceService)
    {
        return _instanceService;
    }

}