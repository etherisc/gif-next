// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin5/contracts/access/Ownable.sol";
import {ProxyAdmin} from "@openzeppelin5/contracts/proxy/transparent/ProxyAdmin.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin5/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {IVersionable} from "./IVersionable.sol";
import {UpgradableProxyWithAdmin} from "./UpgradableProxyWithAdmin.sol";
import {IVersionable} from "./IVersionable.sol";

/// @dev manages proxy deployments for upgradable contracs of type IVersionable
contract ProxyManager is Ownable {

    event LogProxyDeployed(address indexed proxy, address initialImplementation);
    event LogProxyDeployedWithSalt(address indexed proxy, address initialImplementation);
    event LogProxyUpgraded(address indexed proxy, address upgradedImplementation);

    error ErrorAlreadyDeployed();
    error ErrorAlreadyDeployedWithSalt();
    error ErrorNotYetDeployed();

    UpgradableProxyWithAdmin internal _proxy;
    bool internal _isDeployed;

    /// @dev only used to capture proxy owner
    constructor()
        Ownable(msg.sender)
    { }

    /// @dev deploy initial contract
    function deploy(address initialImplementation, bytes memory initializationData)
        public
        virtual
        onlyOwner()
        returns (IVersionable versionable)
    {
        if (_isDeployed) { revert ErrorAlreadyDeployed(); }

        address currentProxyOwner = owner(); // used by implementation
        address initialProxyAdminOwner = address(this); // used by proxy
        bytes memory data = getDeployData(initialImplementation, currentProxyOwner, initializationData);
        
        _proxy = new UpgradableProxyWithAdmin(
            initialImplementation,
            initialProxyAdminOwner,
            data
        );

        _isDeployed = true;
        versionable = IVersionable(address(_proxy));

        emit LogProxyDeployed(address(_proxy), initialImplementation);
    }

    function deployWithSalt(address initialImplementation, bytes memory initializationData, bytes32 salt)
        public
        virtual
        onlyOwner()
        returns (IVersionable versionable)
    {
        if (_isDeployed) { revert ErrorAlreadyDeployedWithSalt(); }

        address currentProxyOwner = owner(); // used by implementation
        address initialProxyAdminOwner = address(this); // used by proxy
        bytes memory data = getDeployData(initialImplementation, currentProxyOwner, initializationData);

        // via create2
        _proxy = new UpgradableProxyWithAdmin{salt: salt}(
            initialImplementation,
            initialProxyAdminOwner,
            data
        );

        _isDeployed = true;
        versionable = IVersionable(address(_proxy));

        emit LogProxyDeployedWithSalt(address(_proxy), initialImplementation);
    }

    /// @dev upgrade existing contract
    function upgrade(address newImplementation, bytes memory upgradeData)
        public
        virtual
        onlyOwner()
        returns (IVersionable versionable)
    {
        if (!_isDeployed) { revert ErrorNotYetDeployed(); }

        address currentProxyOwner = owner();
        ProxyAdmin proxyAdmin = getProxyAdmin();
        ITransparentUpgradeableProxy proxy = ITransparentUpgradeableProxy(address(_proxy));
        bytes memory data = getUpgradeData(newImplementation, currentProxyOwner, upgradeData);

        proxyAdmin.upgradeAndCall(
            proxy,
            newImplementation, 
            data);

        versionable = IVersionable(address(_proxy));

        emit LogProxyUpgraded(address(_proxy), newImplementation);

    }

    function getDeployData(address implementation, address proxyOwner, bytes memory deployData) public pure returns (bytes memory data) {
        return abi.encodeWithSelector(IVersionable.initialize.selector, implementation, proxyOwner, deployData);
    }

    function getUpgradeData(address implementation, address proxyOwner, bytes memory upgradeData) public pure returns (bytes memory data) {
        return abi.encodeWithSelector(IVersionable.upgrade.selector, implementation, proxyOwner, upgradeData);
    }

    function getProxyAdmin() public returns (ProxyAdmin) {
        return _proxy.getProxyAdmin();
    }
}