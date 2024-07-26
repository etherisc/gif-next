// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {Blocknumber, blockNumber} from "../type/Blocknumber.sol";
import {IVersionable} from "./IVersionable.sol";
import {NftId} from "../type/NftId.sol";
import {NftOwnable} from "../shared/NftOwnable.sol";
import {Timestamp, TimestampLib} from "../type/Timestamp.sol";
import {UpgradableProxyWithAdmin} from "./UpgradableProxyWithAdmin.sol";
import {Version, VersionLib} from "../type/Version.sol";

/// @dev manages proxy deployments for upgradable contracs of type IVersionable
contract ProxyManager is
    NftOwnable
{

    struct VersionInfo {
        Version version;
        address implementation;
        address activatedBy;
        Timestamp activatedAt;
        Blocknumber activatedIn;
    }

    event LogProxyManagerVersionableDeployed(address indexed proxy, address initialImplementation);
    event LogProxyManagerVersionableUpgraded(address indexed proxy, address upgradedImplementation);

    error ErrorProxyManagerAlreadyDeployed();
    error ErrorProxyManagerNotYetDeployed();

    error ErrorProxyManagerZeroVersion();
    error ErrorProxyManagerNextVersionNotIncreasing(Version nextVersion);

    UpgradableProxyWithAdmin internal _proxy;

    // state to keep version history
    mapping(Version version => VersionInfo info) _versionHistory;
    Version [] _versions;

    /// @dev convencience initializer
    function initialize(
        address registry,
        address implementation,
        bytes memory data,
        bytes32 salt
    )
        public
        initializer()
        returns (IVersionable versionable)
    {
        versionable = deployDetermenistic(
            registry,
            implementation, 
            data,
            salt);
    }

    /// @dev deploy initial contract
    function deploy(
        address registry, 
        address initialImplementation, 
        bytes memory initializationData
    )
        public
        virtual
        onlyInitializing()
        returns (IVersionable versionable)
    {
        (
            address currentProxyOwner, 
            address initialProxyAdminOwner
        ) = _preDeployChecksAndSetup(registry);

        _proxy = new UpgradableProxyWithAdmin(
            initialImplementation,
            initialProxyAdminOwner,
            getDeployData(currentProxyOwner, initializationData)
        );

        versionable = _updateVersionHistory(
            initialImplementation, 
            currentProxyOwner);

        emit LogProxyManagerVersionableDeployed(address(versionable), initialImplementation);
    }

    function deployDetermenistic(
        address registry, 
        address initialImplementation, 
        bytes memory initializationData, 
        bytes32 salt
    )
        public
        virtual
        onlyInitializing()
        returns (IVersionable versionable)
    {
        (
            address currentProxyOwner, 
            address initialProxyAdminOwner
        ) = _preDeployChecksAndSetup(registry);

        _proxy = new UpgradableProxyWithAdmin{salt: salt}(
            initialImplementation,
            initialProxyAdminOwner,
            getDeployData(currentProxyOwner, initializationData)
        );

        versionable = _updateVersionHistory(
            initialImplementation, 
            currentProxyOwner);

        emit LogProxyManagerVersionableDeployed(address(versionable), initialImplementation);
    }

    /// @dev upgrade existing contract
    function upgrade(address newImplementation, bytes memory upgradeData)
        public
        virtual
        onlyOwner()
        returns (IVersionable versionable)
    {
        if (_versions.length == 0) { 
            revert ErrorProxyManagerNotYetDeployed();
        }

        address currentProxyOwner = getOwner();
        ProxyAdmin proxyAdmin = getProxy().getProxyAdmin();
        ITransparentUpgradeableProxy proxy = ITransparentUpgradeableProxy(address(_proxy));

        proxyAdmin.upgradeAndCall(
            proxy,
            newImplementation, 
            getUpgradeData(upgradeData));

        versionable = _updateVersionHistory(
            newImplementation, 
            currentProxyOwner);

        emit LogProxyManagerVersionableUpgraded(address(versionable), newImplementation);

    }

    function linkToProxy() public returns (NftId) {
        return _linkToNftOwnable(address(_proxy));
    }

    function getDeployData(address proxyOwner, bytes memory deployData) public pure returns (bytes memory data) {
        return abi.encodeWithSelector(
            IVersionable.initializeVersionable.selector, 
            proxyOwner, 
            deployData);
    }

    function getUpgradeData(bytes memory upgradeData) public pure returns (bytes memory data) {
        return abi.encodeWithSelector(
            IVersionable.upgradeVersionable.selector, 
            upgradeData);
    }

    function getProxy() public view returns (UpgradableProxyWithAdmin) {
        return _proxy;
    }

    function getVersion() external view virtual returns(Version) {
        return IVersionable(address(_proxy)).getVersion();
    }

    function getVersionCount() external view returns(uint256) {
        return _versions.length;
    }

    function getVersion(uint256 idx) external view returns(Version) {
        return _versions[idx];
    }

    function getVersionInfo(Version _version) external view returns(VersionInfo memory) {
        return _versionHistory[_version];
    }

    function _preDeployChecksAndSetup(address registry)
        private
        returns (
            address currentProxyOwner,
            address initialProxyAdminOwner
        )
    {
        if (_versions.length > 0) {
            revert ErrorProxyManagerAlreadyDeployed();
        }

        _initializeNftOwnable(msg.sender, registry);

        currentProxyOwner = getOwner(); // used by implementation
        initialProxyAdminOwner = address(this); // used by proxy
    }

    function _updateVersionHistory(
        address implementation,
        address activatedBy
    )
        private
        returns (IVersionable versionable)
    {
        versionable = IVersionable(address(_proxy));
        Version newVersion = versionable.getVersion();

        if(newVersion == VersionLib.zeroVersion()) {
            revert ErrorProxyManagerZeroVersion();
        }

        if(_versions.length > 0) {
            if(newVersion.toInt() <= _versions[_versions.length-1].toInt()) {
                revert ErrorProxyManagerNextVersionNotIncreasing(newVersion);
            }
        }

        // update version history
        _versions.push(newVersion);
        _versionHistory[newVersion] = VersionInfo(
            newVersion,
            implementation,
            activatedBy,
            TimestampLib.blockTimestamp(),
            blockNumber()
        );
    }
}