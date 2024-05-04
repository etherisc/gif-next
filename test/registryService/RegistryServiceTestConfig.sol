// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {RoleId, REGISTRY_SERVICE_ROLE} from "../../contracts/type/RoleId.sol";
import {VersionPart} from "../../contracts/type/Version.sol";

import {ReleaseManager} from "../../contracts/registry/ReleaseManager.sol";

import {ReleaseConfig} from "../base/ReleaseConfig.sol";


contract RegistryServiceTestConfig is ReleaseConfig
{
    constructor(
        ReleaseManager releaseManager,
        bytes memory managerCreationCode,
        bytes memory implementationCreationCode,
        address owner, 
        VersionPart version, 
        bytes32 salt)
        ReleaseConfig(releaseManager, owner, version, salt)
    { 
        _pushRegistryServiceConfig(managerCreationCode, implementationCreationCode);
    }

    function _pushRegistryServiceConfig(bytes memory managerCreationCode, bytes memory implementationCreationCode) internal
    {
        address proxyManager = _computeProxyManagerAddress(managerCreationCode);
        address implementation = _computeImplementationAddress(implementationCreationCode, proxyManager);
        address proxyAddress = _computeProxyAddress(implementation, proxyManager);

        _addresses.push(proxyAddress);
        _names.push("RegistryService");
        _serviceRoles.push(new RoleId[](1));
        _serviceRoleNames.push(new string[](1));
        _functionRoles.push(new RoleId[](0));
        _functionRoleNames.push(new string[](0));
        _selectors.push(new bytes4[][](0));
        uint serviceIdx = _addresses.length - 1;

        _serviceRoles[serviceIdx][0] = REGISTRY_SERVICE_ROLE();

        _serviceRoleNames[serviceIdx][0] = "REGISTRY_SERVICE_ROLE";
    }
}