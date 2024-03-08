// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {IVersionable} from "./IVersionable.sol";
import {NftOwnable} from "./NftOwnable.sol";
import {UpgradableProxyWithAdmin} from "./UpgradableProxyWithAdmin.sol";

/// @dev manages proxy deployments for upgradable contracs of type IVersionable
contract ProxyManager is
    NftOwnable
{

    event LogProxyDeployed(address indexed proxy, address initialImplementation);
    event LogProxyDeployedWithSalt(address indexed proxy, address initialImplementation);
    event LogProxyUpgraded(address indexed proxy, address upgradedImplementation);

    error ErrorAlreadyDeployed();
    error ErrorAlreadyDeployedWithSalt();
    error ErrorNotYetDeployed();

    UpgradableProxyWithAdmin internal _proxy;
    bool internal _isDeployed;

    /// @dev only used to capture proxy owner
    constructor(address registry)
    { 
        initializeProxyManager(registry);
    }

    function initializeProxyManager(address registry)
        public
        initializer()
    {
        initializeNftOwnable(msg.sender, registry);
    }

    /// @dev deploy initial contract
    function deploy(address initialImplementation, bytes memory initializationData)
        public
        virtual
        onlyOwner()
        returns (IVersionable versionable)
    {
        if (_isDeployed) { revert ErrorAlreadyDeployed(); }
        _isDeployed = true;

        address currentProxyOwner = getOwner(); // used by implementation
        address initialProxyAdminOwner = address(this); // used by proxy
        bytes memory data = getDeployData(initialImplementation, currentProxyOwner, initializationData);
        
        _proxy = new UpgradableProxyWithAdmin(
            initialImplementation,
            initialProxyAdminOwner,
            data
        );

        versionable = IVersionable(address(_proxy));

        emit LogProxyDeployed(address(_proxy), initialImplementation);
    }

    /// @dev upgrade existing contract
    function upgrade(address newImplementation, bytes memory upgradeData)
        public
        virtual
        onlyOwner()
        returns (IVersionable versionable)
    {
        if (!_isDeployed) { revert ErrorNotYetDeployed(); }

        address currentProxyOwner = getOwner();
        ProxyAdmin proxyAdmin = getProxy().getProxyAdmin();
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
        return abi.encodeWithSelector(IVersionable.initializeVersionable.selector, implementation, proxyOwner, deployData);
    }

    function getUpgradeData(address implementation, address proxyOwner, bytes memory upgradeData) public pure returns (bytes memory data) {
        return abi.encodeWithSelector(IVersionable.upgradeVersionable.selector, implementation, proxyOwner, upgradeData);
    }

    function getProxy() public returns (UpgradableProxyWithAdmin) {
        return _proxy;
    }
}