// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {RoleId} from "../../contracts/type/RoleId.sol";
import {VersionPart} from "../../contracts/type/Version.sol";

import {IVersionable} from "../../contracts/shared/IVersionable.sol";
import {UpgradableProxyWithAdmin} from "../../contracts/shared/UpgradableProxyWithAdmin.sol";
import {ReleaseManager} from "../../contracts/registry/ReleaseManager.sol";

contract ReleaseConfig
{
    VersionPart public immutable _version;
    address public immutable _releaseManager;
    address public immutable _releaseAccessManager;
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

    constructor(ReleaseManager releaseManager, address owner, VersionPart version, bytes32 salt)
    { 
        _releaseManager = address(releaseManager);
        _registry = releaseManager.getRegistry();
        _owner = owner;
        _version = version;
        _salt = keccak256(
            bytes.concat(
                bytes32(_version.toInt()),
                salt));
        _releaseAccessManager = Clones.predictDeterministicAddress(
            address(releaseManager._releaseAccessManagerCodeAddress()), // implementation
            _salt,
            address(releaseManager)); // deployer
    }

    function length() external view returns(uint) {
        return _addresses.length;
    }

    function getServiceConfig(uint serviceIdx) 
        external 
        view 
        returns(
            address serviceAddress,
            string memory,
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

    function _computeProxyManagerAddress(bytes memory creationCode) internal view returns(address) {
        bytes memory initCode = abi.encodePacked(
            creationCode, 
            abi.encode(_releaseAccessManager, _registry, _salt));
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
            _releaseAccessManager);

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