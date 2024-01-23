// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegistry} from "../registry/IRegistry.sol";
import {IService} from "./IService.sol";
import {IVersionable} from "./IVersionable.sol";
import {NftId, zeroNftId} from "../types/NftId.sol";
import {RegisterableUpgradable} from "./RegisterableUpgradable.sol";
import {SERVICE} from "../types/ObjectType.sol";
import {Version, VersionPart, VersionLib} from "../types/Version.sol";
import {Versionable} from "./Versionable.sol";

/// @dev service base contract
abstract contract Service is 
    RegisterableUpgradable,
    IService
{
    function getName() public pure virtual override returns(string memory name);

    function getMajorVersion() public view virtual override returns(VersionPart majorVersion) {
        return getVersion().toMajorPart(); 
    }

    // from Versionable
    function getVersion()
        public 
        pure 
        virtual override (IVersionable, Versionable)
        returns(Version)
    {
        return VersionLib.toVersion(3,0,0);
    }

    function _initializeService(
        address registry, 
        address initialOwner
    )
        internal
        virtual
        //onlyInitializing //TODO uncomment when "fully" upgradeable
    {
        // service must provide its name and version upon registration
        bytes memory data = abi.encode(getName(), getMajorVersion());
        NftId registryNftId = _getRegistryNftId(registry); 
        bool isInterceptor = false;

        _initializeRegisterable(registry, registryNftId, SERVICE(), isInterceptor, initialOwner, data);
        _registerInterface(type(IService).interfaceId);
    }

    // this is just a conveniene function, actual validation will be done upon registration
    function _getRegistryNftId(address registryAddress) internal view returns (NftId) {
        return IRegistry(registryAddress).getNftId(registryAddress);
    }
}