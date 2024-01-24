// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IVersionable} from "../../shared/IVersionable.sol";
import {ProxyManager} from "../../shared/ProxyManager.sol";
import {PoolService} from "./PoolService.sol";
import {Registry} from "../../registry/Registry.sol";
import {RegistryService} from "../../registry/RegistryService.sol";
import {VersionLib} from "../../types/Version.sol";

contract PoolServiceManager is ProxyManager {

    PoolService private _poolService;

    /// @dev initializes proxy manager with pool service implementation 
    constructor(
        address registryAddress
    )
        ProxyManager()
    {
        PoolService poolSrv = new PoolService();
        bytes memory data = abi.encode(registryAddress, address(this));
        IVersionable versionable = deploy(
            address(poolSrv), 
            data);

        _poolService = PoolService(address(versionable));

        Registry registry = Registry(registryAddress);
        address registryServiceAddress = registry.getServiceAddress("RegistryService", VersionLib.toVersion(3, 0, 0).toMajorPart());
        RegistryService registryService = RegistryService(registryServiceAddress);
        // TODO this must have a role or own nft to register service
        //registryService.registerService(_poolService);
        
        // TODO no nft to link yet
        // link ownership of instance service manager ot nft owner of instance service
        //_linkToNftOwnable(
        //    address(registryAddress),
        //    address(_poolService));

        // implies that after this constructor call only upgrade functionality is available
        _isDeployed = true;
    }

    //--- view functions ----------------------------------------------------//
    function getPoolService()
        external
        view
        returns (PoolService poolService)
    {
        return _poolService;
    }

}