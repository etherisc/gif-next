// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Instance} from "./Instance.sol";
import {IVersionable} from "../shared/IVersionable.sol";
import {ProxyManager} from "../shared/ProxyManager.sol";
import {InstanceService} from "./InstanceService.sol";
import {Registry} from "../registry/Registry.sol";
import {RegistryService} from "../registry/RegistryService.sol";
import {REGISTRY} from "../type/ObjectType.sol";

contract InstanceServiceManager is ProxyManager {

    InstanceService private _instanceService;

    /// @dev initializes proxy manager with instance service implementation and deploys instance
    constructor(
        address authority, 
        address registryAddress,
        bytes32 salt
    ) 
        ProxyManager(registryAddress)
    {
        InstanceService instSrv = new InstanceService{salt: salt}();
        // bytes memory initCode = type(InstanceService).creationCode;
        bytes memory data = abi.encode(registryAddress, address(this), authority);
        IVersionable versionable = deployDetermenistic(
            address(instSrv), 
            data,
            salt);

        _instanceService = InstanceService(address(versionable));

        // TODO `this` must have a role or own nft to register service
        //Registry registry = Registry(registryAddress);
        //address registryServiceAddress = registry.getServiceAddress(REGISTRY(), _instanceService.getMajorVersion());
        //RegistryService registryService = RegistryService(registryServiceAddress);
        //registryService.registerService(_instanceService);
        // RegistryService registryService = _instanceService.getRegistryService();

        // TODO no nft to link yet
        // link ownership of instance service manager ot nft owner of instance service
        //_linkToNftOwnable(
        //    address(registryAddress),
        //    address(_instanceService));
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