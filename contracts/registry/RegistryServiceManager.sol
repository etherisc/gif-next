// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";

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
    //registryServiceManager = new RegistryServiceManager{salt: config.CONFIG_SALT()}(releaseAccessManager, registryAddress, config.CONFIG_SALT());
    constructor(
        address authority, // used by implementation 
        address registry, // used by implementation 
        bytes32 salt
    ) 
        ProxyManager(registry)
    {
        require(authority > address(0), "RegistryServiceManager: initial authority is 0");
        require(registry > address(0), "RegistryServiceManager: registry is 0");
        
        // implementation's initializer func `data` argument
        //RegistryService srv = new RegistryService{salt: salt}();
        RegistryService srv = new RegistryService{ salt: salt }();
        bytes memory data = abi.encode(registry, address(this), authority);
        IVersionable versionable = deployDetermenistic(
            address(srv), 
            data,
            salt);

        _registryService = RegistryService(address(versionable));

//        _linkToNftOwnable(address(_registryService));
    }

    // // from IRegisterable

    // // IMPORTANT: registry here and in constructor MUST be the same
    function linkOwnershipToServiceNft()
        public
        onlyOwner
    {
        _linkToNftOwnable(address(_registryService));
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
