// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IVersionable} from "../../shared/IVersionable.sol";
import {ProxyManager} from "../../shared/ProxyManager.sol";
import {DistributionService} from "./DistributionService.sol";
import {Registry} from "../../registry/Registry.sol";
import {RegistryService} from "../../registry/RegistryService.sol";
import {REGISTRY} from "../../types/ObjectType.sol";

contract DistributionServiceManager is ProxyManager {

    DistributionService private _distributionService;

    /// @dev initializes proxy manager with distribution service implementation and deploys instance
    constructor(
        address registryAddress
    )
        ProxyManager()
    {
        DistributionService distSrv = new DistributionService();
        bytes memory data = abi.encode(registryAddress, address(this));
        IVersionable versionable = deploy(
            address(distSrv), 
            data);

        _distributionService = DistributionService(address(versionable));
        
        // TODO `thi` must have a role or own nft to register service
        //Registry registry = Registry(registryAddress);
        //address registryServiceAddress = registry.getServiceAddress(REGISTRY(), _distributionService.getMajorVersion());
        //RegistryService registryService = RegistryService(registryServiceAddress);
        //registryService.registerService(_distributionService);
        
        // TODO no nft to link yet
        // link ownership of instance service manager ot nft owner of instance service
        //_linkToNftOwnable(
        //    address(registryAddress),
        //    address(_distributionService));
    }

    //--- view functions ----------------------------------------------------//
    function getDistributionService()
        external
        view
        returns (DistributionService distributionService)
    {
        return _distributionService;
    }

}