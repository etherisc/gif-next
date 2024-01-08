// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy, ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {IVersionable} from "./IVersionable.sol";

contract UpgradableProxyWithAdmin is TransparentUpgradeableProxy {

    constructor(address implementation, address initialProxyAdminOwner, bytes memory data)
        TransparentUpgradeableProxy(implementation, initialProxyAdminOwner, data)
    {}

    function getProxyAdmin() external returns (ProxyAdmin) { return ProxyAdmin(_proxyAdmin()); }
}