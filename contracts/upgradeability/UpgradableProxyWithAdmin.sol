// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract UpgradableProxyWithAdmin is TransparentUpgradeableProxy {

    bytes internal _initializationData;
    
    constructor(address implementation, address initialProxyAdminOwner, bytes memory data)
        TransparentUpgradeableProxy(implementation, initialProxyAdminOwner, data)
    {
        _initializationData = data;
    }

    function getProxyAdmin() external returns (ProxyAdmin) { return ProxyAdmin(_proxyAdmin()); }

    function getInitializationData() external view returns (bytes memory) { return _initializationData; }
}