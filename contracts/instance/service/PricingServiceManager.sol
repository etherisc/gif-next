// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IVersionable} from "../../shared/IVersionable.sol";
import {ProxyManager} from "../../shared/ProxyManager.sol";
import {PricingService} from "./PricingService.sol";
import {Registry} from "../../registry/Registry.sol";
import {RegistryService} from "../../registry/RegistryService.sol";
import {REGISTRY} from "../../types/ObjectType.sol";

contract PricingServiceManager is ProxyManager {

    PricingService private _pricingService;

    /// @dev initializes proxy manager with distribution service implementation and deploys instance
    constructor(
        address registryAddress
    )
        ProxyManager(registryAddress)
    {
        PricingService pricingSrv = new PricingService();
        bytes memory data = abi.encode(registryAddress, address(this));
        IVersionable versionable = deploy(
            address(pricingSrv), 
            data);

        _pricingService = PricingService(address(versionable));
        
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
    function getPricingService()
        external
        view
        returns (PricingService getPricingService)
    {
        return _pricingService;
    }

}