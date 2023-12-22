// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin5/contracts/access/Ownable.sol";
import {ProxyAdmin} from "@openzeppelin5/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy, ITransparentUpgradeableProxy} from "@openzeppelin5/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {IVersionable} from "./IVersionable.sol";

contract ProxyWithProxyAdminGetter is TransparentUpgradeableProxy {

    constructor(address implementation, address initialProxyAdminOwner,bytes memory data)
        TransparentUpgradeableProxy(implementation, initialProxyAdminOwner, data)
    {}

    function getProxyAdmin() external returns (ProxyAdmin) { return ProxyAdmin(_proxyAdmin()); }
}

contract Proxy is Ownable {

    string public constant ACTIVATE_SIGNATURE = "activate(address,address)";

    ProxyWithProxyAdminGetter private _proxy;
    bool private _isDeployed;

    /// @dev only used to capture proxy owner
    constructor()
        Ownable(msg.sender)
    {
    }

    function getData(address implementation, address proxyOwner) public pure returns (bytes memory data) {
        return abi.encodeWithSignature(ACTIVATE_SIGNATURE, implementation, proxyOwner);
    }

    /// @dev deploy initial contract
    function deploy(address initialImplementation)
        external
        onlyOwner()
        returns (IVersionable versionable)
    {
        require(!_isDeployed, "ERROR:PRX-010:ALREADY_DEPLOYED");

        address currentProxyOwner = owner();
        address initialProxyAdminOwner = address(this);
        bytes memory data = getData(initialImplementation, currentProxyOwner);

        _proxy = new ProxyWithProxyAdminGetter(
            initialImplementation,
            initialProxyAdminOwner,
            data
        );

        _isDeployed = true;
        versionable = IVersionable(address(_proxy));
    }

    /// @dev upgrade existing contract
    function upgrade(address newImplementation)
        external
        onlyOwner
        returns (IVersionable versionable)
    {
        require(_isDeployed, "ERROR:PRX-020:NOT_YET_DEPLOYED");

        address currentProxyOwner = owner();
        // ProxyAdmin proxyAdmin = _proxy.getProxyAdmin();
        ProxyAdmin proxyAdmin = getProxyAdmin();
        ITransparentUpgradeableProxy proxy = ITransparentUpgradeableProxy(address(_proxy));
        bytes memory data = getData(newImplementation, currentProxyOwner);

        proxyAdmin.upgradeAndCall(
            proxy,
            newImplementation, 
            data);

        versionable = IVersionable(address(_proxy));
    }

    function getProxyAdmin() public returns (ProxyAdmin) {
        return _proxy.getProxyAdmin();
    }
}