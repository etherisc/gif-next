// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {Blocknumber, BlocknumberLib} from "../type/Blocknumber.sol";
import {IUpgradeable} from "./IUpgradeable.sol";
import {NftId} from "../type/NftId.sol";
import {NftOwnable} from "../shared/NftOwnable.sol";
import {Timestamp, TimestampLib} from "../type/Timestamp.sol";
import {UpgradableProxyWithAdmin} from "./UpgradableProxyWithAdmin.sol";
import {Version, VersionPart, VersionLib} from "../type/Version.sol";

/// @dev manages proxy deployments for upgradable contracs of type IUpgradeable
contract ProxyManager is
    NftOwnable
{

    struct VersionInfo {
        // slot 0
        address implementation;
        Timestamp activatedAt;
        Blocknumber activatedIn;
        Version version;
        // slot 1
        address activatedBy;
    }

    event LogProxyManagerProxyDeployed(address indexed proxy, address initialImplementation);
    event LogProxyManagerProxyUpgraded(address indexed proxy, address upgradedImplementation);

    error ErrorProxyManagerAlreadyDeployed();
    error ErrorProxyManagerNotYetDeployed();

    error ErrorProxyManagerZeroVersion();
    error ErrorProxyManagerNextVersionNotIncreasing(Version nextVersion);
    error ErrorProxyManagerNextVersionReleaseInvalid(Version nextVersion);

    UpgradableProxyWithAdmin internal _proxy;

    // state to keep version history
    mapping(Version version => VersionInfo info) internal _versionHistory;
    Version [] internal _versions;

    /// @dev convencience initializer
    function initialize(
        address registry,
        address implementation,
        bytes memory data,
        bytes32 salt
    )
        public
        initializer()
        returns (IUpgradeable upgradeable)
    {
        address initialOwner = msg.sender;

        __NftOwnable_init(registry, initialOwner);

        upgradeable = deployDetermenistic(
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
        returns (IUpgradeable upgradeable)
    {
        if (_versions.length > 0) {
            revert ErrorProxyManagerAlreadyDeployed();
        }

        address currentProxyOwner = getOwner(); // used by implementation
        address initialProxyAdminOwner = address(this); // used by proxy

        _proxy = new UpgradableProxyWithAdmin(
            initialImplementation,
            initialProxyAdminOwner,
            getDeployData(currentProxyOwner, initializationData)
        );

        upgradeable = _updateVersionHistory(
            initialImplementation, 
            currentProxyOwner);

        emit LogProxyManagerProxyDeployed(address(upgradeable), initialImplementation);
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
        returns (IUpgradeable upgradeable)
    {
        if (_versions.length > 0) {
            revert ErrorProxyManagerAlreadyDeployed();
        }

        address currentProxyOwner = getOwner(); // used by implementation
        address initialProxyAdminOwner = address(this); // used by proxy

        _proxy = new UpgradableProxyWithAdmin{salt: salt}(
            initialImplementation,
            initialProxyAdminOwner,
            getDeployData(currentProxyOwner, initializationData)
        );

        upgradeable = _updateVersionHistory(
            initialImplementation, 
            currentProxyOwner);

        emit LogProxyManagerProxyDeployed(address(upgradeable), initialImplementation);
    }

    /// @dev upgrade existing contract.
    /// convenience method using empty data
    function upgrade(address newImplementation) 
        public
        virtual
        onlyOwner()
        returns (IUpgradeable upgradeable)
    {
        bytes memory emptyUpgradeData;
        return upgrade(newImplementation, emptyUpgradeData);
    }

    /// @dev upgrade existing contract
    function upgrade(address newImplementation, bytes memory upgradeData)
        public
        virtual
        onlyOwner()
        returns (IUpgradeable upgradeable)
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

        upgradeable = _updateVersionHistory(
            newImplementation, 
            currentProxyOwner);

        emit LogProxyManagerProxyUpgraded(address(upgradeable), newImplementation);

    }

    function linkToProxy() public returns (NftId) {
        return _linkToNftOwnable(address(_proxy));
    }

    function getDeployData(address proxyOwner, bytes memory deployData) public pure returns (bytes memory data) {
        return abi.encodeWithSelector(
            IUpgradeable.initialize.selector, 
            proxyOwner, 
            deployData);
    }

    function getUpgradeData(bytes memory upgradeData) public pure returns (bytes memory data) {
        return abi.encodeWithSelector(
            IUpgradeable.upgrade.selector, 
            upgradeData);
    }

    function getProxy() public view returns (UpgradableProxyWithAdmin) {
        return _proxy;
    }

    function getVersion() external view virtual returns(Version) {
        //return _versionHistory[_versions[_versions.length]];
        return IUpgradeable(address(_proxy)).getVersion();
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

    function _updateVersionHistory(
        address implementation,
        address activatedBy
    )
        private
        returns (IUpgradeable upgradeable)
    {
        upgradeable = IUpgradeable(address(_proxy));
        Version newVersion = upgradeable.getVersion();

        if(newVersion == VersionLib.zeroVersion()) {
            revert ErrorProxyManagerZeroVersion();
        }

        if(_versions.length > 0) {
            Version version = _versions[_versions.length-1];
            if(newVersion.toInt() <= version.toInt()) {
                revert ErrorProxyManagerNextVersionNotIncreasing(newVersion);
            }

            if(newVersion.toMajorPart() != version.toMajorPart()) {
                revert ErrorProxyManagerNextVersionReleaseInvalid(newVersion);
            }
        }

        // update version history
        _versions.push(newVersion);
        _versionHistory[newVersion] = VersionInfo({
            version: newVersion,
            implementation: implementation,
            activatedBy: activatedBy,
            activatedAt: TimestampLib.current(),
            activatedIn: BlocknumberLib.current()
        });
    }
}