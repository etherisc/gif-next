// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {console} from "../../lib/forge-std/src/Test.sol";

import {RoleId, REGISTRY_SERVICE_ROLE} from "../../contracts/type/RoleId.sol";
import {ObjectType, REGISTRY, SERVICE} from "../../contracts/type/ObjectType.sol";
import {StateId, ACTIVE, PAUSED} from "../../contracts/type/StateId.sol";
import {NftId, NftIdLib, zeroNftId} from "../../contracts/type/NftId.sol";
import {Fee, FeeLib} from "../../contracts/type/Fee.sol";
import {Version, VersionPart, VersionLib} from "../../contracts/type/Version.sol";

import {IVersionable} from "../../contracts/shared/IVersionable.sol";
import {Versionable} from "../../contracts/shared/Versionable.sol";
import {IRegisterable} from "../../contracts/shared/IRegisterable.sol";
import {Registerable} from "../../contracts/shared/Registerable.sol";
import {Service} from "../../contracts/shared/Service.sol";
import {IService} from "../../contracts/shared/IService.sol";
import {UpgradableProxyWithAdmin} from "../../contracts/shared/UpgradableProxyWithAdmin.sol";
import {AccessManagerUpgradeableInitializeable} from "../../contracts/shared/AccessManagerUpgradeableInitializeable.sol";

import {IInstance} from "../../contracts/instance/IInstance.sol";

import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {IRegistryService} from "../../contracts/registry/IRegistryService.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {ReleaseManager} from "../../contracts/registry/ReleaseManager.sol";

import {RegistryServiceManagerMockWithHarness} from "../mock/RegistryServiceManagerMock.sol";
import {RegistryServiceHarness} from "./RegistryServiceHarness.sol";

// IMPORTANT: only for easier testing, hh script should precalculate addresses and give to release manager
// extended version with access control setup
// deployment size > 800kb
contract RegistryServiceTestConfig
{
    VersionPart public immutable _version;
    address public immutable _releaseManager;
    address public immutable _accessManager;// release access manager
    address public immutable _registry;
    address public immutable _owner;
    bytes32 public immutable _salt;
    address[] internal _addresses;
    string[] internal _names;
    RoleId[][] internal _serviceRoles;
    string[][] internal _serviceRoleNames;
    RoleId[][] internal _functionRoles;
    string[][] internal _functionRoleNames;
    bytes4[][][] internal _selectors;

    constructor(
        ReleaseManager releaseManager,
        bytes memory managerCreationCode,
        bytes memory implementationCreationCode,
        address owner, 
        VersionPart version, 
        bytes32 salt)
    { 
        _releaseManager = address(releaseManager);
        _registry = releaseManager.getRegistry();
        _owner = owner;
        _version = version;
        _salt = keccak256(
            bytes.concat(
                bytes32(_version.toInt()),
                salt));
        _accessManager = Clones.predictDeterministicAddress(
            address(releaseManager.getReleaseAdmin(version)), // implementation
            _salt,
            address(releaseManager)); // deployer

        _pushRegistryServiceConfig(managerCreationCode, implementationCreationCode);
    }

    function length() external view returns(uint) {
        return _addresses.length;
    }

    function getServiceConfig(uint serviceIdx) 
        external 
        view 
        returns(
            address serviceAddress,
            string memory serviceName,
            RoleId[] memory, 
            string[] memory,
            RoleId[] memory, 
            string[] memory,
            bytes4[][] memory
        )
    {
        return(
            _addresses[serviceIdx],
            _names[serviceIdx],
            _serviceRoles[serviceIdx],
            _serviceRoleNames[serviceIdx], 
            _functionRoles[serviceIdx], 
            _functionRoleNames[serviceIdx],
            _selectors[serviceIdx]
        );
    }

    function getConfig() 
        external 
        view returns(
            address[] memory,
            string[] memory,
            RoleId[][] memory,
            string[][] memory,
            RoleId[][] memory, 
            string[][] memory,
            bytes4[][][] memory
        )
    {
        return (
            _addresses,
            _names, 
            _serviceRoles, 
            _serviceRoleNames,
            _functionRoles, 
            _functionRoleNames,
            _selectors
        );
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

    function _computeProxyManagerAddress(bytes memory creationCode) internal view returns(address) {
        bytes memory initCode = abi.encodePacked(
            creationCode, 
            abi.encode(_accessManager, _registry, _salt));
        return Create2.computeAddress(_salt, keccak256(initCode), _owner);
    }

    function _computeImplementationAddress(bytes memory creationCode, address proxyManager) internal view returns(address) {
        bytes memory initCode = abi.encodePacked(creationCode);
        return Create2.computeAddress(_salt, keccak256(initCode), proxyManager);
    }

    function _computeProxyAddress(address implementation, address proxyManager) internal view returns(address) {
        bytes memory data = abi.encode(
            _registry, 
            proxyManager, 
            _accessManager);

        data = abi.encodeWithSelector(
            IVersionable.initializeVersionable.selector,
            _owner,
            data);

        bytes memory initCode = abi.encodePacked(
            type(UpgradableProxyWithAdmin).creationCode,
            abi.encode(
                implementation,
                proxyManager, // is proxy admin owner
                data));

        return Create2.computeAddress(_salt, keccak256(initCode), proxyManager);
    }
}