// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";

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
        address registryAddress) // used by implementation 
        ProxyManager(registryAddress)
    {
        require(initialAuthority > address(0), "RegistryServiceManager: initial authority is 0");
        require(registryAddress > address(0), "RegistryServiceManager: registry is 0");
        
        // implementation's initializer func `data` argument
        RegistryService srv = new RegistryService();
        bytes memory data = abi.encode(registryAddress, initialAuthority);
        IVersionable versionable = deploy(
            address(srv), 
            data);

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
