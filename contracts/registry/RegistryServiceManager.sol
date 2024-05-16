// SPDX-License-Identifier: Apache-2.0
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
    error ErrorRegistryAccessManagerAuthorityZero();
    error ErrorRegistryAccessManagerRegistryZero();

    bytes32 constant public ACCESS_MANAGER_CREATION_CODE_HASH = 0x0;

    RegistryService private immutable _registryService;

    /// @dev initializes proxy manager with registry service implementation and deploys registry
    constructor(
        address authority, // used by implementation 
        address registry, // used by implementation 
        bytes32 salt
    ) 
        ProxyManager(registry)
    {
        if(authority == address(0)) {
            revert ErrorRegistryAccessManagerAuthorityZero();
        }

        if(registry == address(0)) {
            revert ErrorRegistryAccessManagerRegistryZero();
        }
        
        RegistryService srv = new RegistryService{ salt: salt }();
        bytes memory data = abi.encode(registry, authority);
        IVersionable versionable = deployDetermenistic(
            address(srv), 
            data,
            salt);

        _registryService = RegistryService(address(versionable));
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
