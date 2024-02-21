// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {VersionPartLib} from "../types/Version.sol";

import {RegistryAccessManager} from "./RegistryAccessManager.sol";
import {ReleaseManager} from "./ReleaseManager.sol";
import {TokenRegistry} from "./TokenRegistry.sol";

import {Registry} from "./Registry.sol";
import {ChainNft} from "./ChainNft.sol";

/// @title deploys registry contracts
contract RegistryDeployer
{
    uint256 public constant GIF_MIN_RELEASE = 3;

    RegistryAccessManager private _registryAccessManager;
    ReleaseManager private _releaseManager;
    TokenRegistry private _tokenRegistry;
    Registry private _registry;
    
    event LogConsole(string message);

    // TODO 1) provide registry service manager as parameter
    // TODO 2) configure registry service manager and complete deployment
    constructor(address registryOwner) {
        emit LogConsole("debug 1.1");

        _registryAccessManager = new RegistryAccessManager(
            registryOwner, // admin
            registryOwner); // manager

        emit LogConsole("debug 1.2");

        _releaseManager = new ReleaseManager(
            _registryAccessManager,
            VersionPartLib.toVersionPart(GIF_MIN_RELEASE));

        emit LogConsole("debug 1.3");

        _registry = Registry(_releaseManager.getRegistry());

        emit LogConsole("debug 1.4");

        _tokenRegistry = new TokenRegistry();
        _tokenRegistry.setInitialOwner(msg.sender);

        _registryAccessManager.initialize(
            address(_releaseManager), 
            address(_tokenRegistry));

        emit LogConsole("debug 1.5");
    }

    function getRegistryAccessManager() external view returns (RegistryAccessManager) {
        return _registryAccessManager;
    }

    function getReleaseManager() external view returns (ReleaseManager) {
        return _releaseManager;
    }

    function getRegistry() external view returns (Registry) {
        return _registry;
    }

    function getTokenRegistry() external view returns (TokenRegistry) {
        return _tokenRegistry;
    }
}