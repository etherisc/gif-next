// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IVersionable} from "../../shared/IVersionable.sol";
import {ProxyManager} from "../../shared/ProxyManager.sol";
import {DistributionService} from "./DistributionService.sol";
import {Registry} from "../../registry/Registry.sol";
import {RegistryService} from "../../registry/RegistryService.sol";
import {VersionLib} from "../../types/Version.sol";

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

        Registry registry = Registry(registryAddress);
        address registryServiceAddress = registry.getServiceAddress("RegistryService", VersionLib.toVersion(3, 0, 0).toMajorPart());
        RegistryService registryService = RegistryService(registryServiceAddress);
        
        registryService.registerService(_distributionService);
        
        // link ownership of instance service manager ot nft owner of instance service
        _linkToNftOwnable(
            address(registryAddress),
            address(_distributionService));

        // implies that after this constructor call only upgrade functionality is available
        _isDeployed = true;
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