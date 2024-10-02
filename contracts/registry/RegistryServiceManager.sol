// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IUpgradeable} from "../upgradeability/IUpgradeable.sol";
import {ProxyManager} from "../upgradeability/ProxyManager.sol";
import {RegistryService} from "./RegistryService.sol";

contract RegistryServiceManager is
    ProxyManager
{
    error ErrorRegistryAccessManagerAuthorityZero();

    bytes32 constant public ACCESS_MANAGER_CREATION_CODE_HASH = 0x0;

    RegistryService private immutable _registryService;

    /// @dev initializes proxy manager with registry service implementation and deploys registry
    constructor(
        address authority, // used by implementation 
        bytes32 salt
    ) 
    {
        if(authority == address(0)) {
            revert ErrorRegistryAccessManagerAuthorityZero();
        }
        
        RegistryService srv = new RegistryService{ salt: salt }();
        bytes memory data = abi.encode(authority);
        IUpgradeable upgradeable = initialize(
            address(srv), 
            data,
            salt);

        _registryService = RegistryService(address(upgradeable));
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
