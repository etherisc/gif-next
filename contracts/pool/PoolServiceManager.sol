// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IVersionable} from "../shared/IVersionable.sol";
import {ProxyManager} from "../shared/ProxyManager.sol";
import {PoolService} from "./PoolService.sol";
import {Registry} from "../registry/Registry.sol";
import {RegistryService} from "../registry/RegistryService.sol";
import {REGISTRY} from "../type/ObjectType.sol";

contract PoolServiceManager is ProxyManager {

    PoolService private _poolService;

    /// @dev initializes proxy manager with pool service implementation 
    constructor(
        address authority, 
        address registryAddress,
        bytes32 salt
    ) 
        ProxyManager(registryAddress)
    {
        PoolService poolSrv = new PoolService{salt: salt}();
        bytes memory data = abi.encode(registryAddress, address(this), authority);
        IVersionable versionable = deployDetermenistic(
            address(poolSrv), 
            data,
            salt);

        _poolService = PoolService(address(versionable));

        // TODO `this` must have a role or own nft to register service
        //Registry registry = Registry(registryAddress);
        //address registryServiceAddress = registry.getServiceAddress(REGISTRY(), _poolService.getMajorVersion());
        //RegistryService registryService = RegistryService(registryServiceAddress);
        //registryService.registerService(_poolService);
        
        // TODO no nft to link yet
        // link ownership of instance service manager ot nft owner of instance service
        //_linkToNftOwnable(
        //    address(registryAddress),
        //    address(_poolService));
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