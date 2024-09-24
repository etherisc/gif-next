// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract UpgradableProxyWithAdmin is TransparentUpgradeableProxy {

    //bytes private _initializationData;
    
    constructor(address implementation, address initialProxyAdminOwner, bytes memory data)
        TransparentUpgradeableProxy(implementation, initialProxyAdminOwner, data)
    {
        // TODO 
        // This overwrites implementations storage
        // Implementation can not use storage with root at slot 0 -OR- proxy MUST be stateless
        // In case of Staking overwrites RegistryLinked._registry
        //_initializationData = data;
    }

    function getProxyAdmin() external returns (ProxyAdmin) { 
        return ProxyAdmin(_proxyAdmin()); 
    }

    //function getProxyInitializationData() external view returns (bytes memory) { 
    //    return _initializationData; 
    //}
}