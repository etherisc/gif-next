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

        versionable = IVersionable(address(_proxy));
        _updateVersionHistory(versionable.getVersion(), initialImplementation, currentProxyOwner);

        emit LogProxyManagerVersionableDeployed(address(_proxy), initialImplementation);
    }

    function deployDetermenistic(address initialImplementation, bytes memory initializationData, bytes32 salt)
        public
        virtual
        onlyOwner()
        returns (IVersionable versionable)
    {
        if (_versions.length > 0) {
            revert ErrorProxyManagerAlreadyDeployed();
        }

        address currentProxyOwner = getOwner();
        address initialProxyAdminOwner = address(this);

        _proxy = new UpgradableProxyWithAdmin{salt: salt}(
            initialImplementation,
            initialProxyAdminOwner,
            getDeployData(currentProxyOwner, initializationData)
        );

        versionable = IVersionable(address(_proxy));
        _updateVersionHistory(versionable.getVersion(), initialImplementation, currentProxyOwner);

        emit LogProxyManagerVersionableDeployed(address(_proxy), initialImplementation);
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

        versionable = IVersionable(address(_proxy));
        _updateVersionHistory(versionable.getVersion(), newImplementation, currentProxyOwner);

        emit LogProxyManagerVersionableUpgraded(address(_proxy), newImplementation);

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

    function _updateVersionHistory(
        Version newVersion,
        address implementation,
        address activatedBy
    )
        private
    {
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