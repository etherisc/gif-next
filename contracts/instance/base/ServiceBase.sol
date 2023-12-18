// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {NftId, zeroNftId} from "../../types/NftId.sol";
import {ObjectType, SERVICE} from "../../types/ObjectType.sol";
import {Version, VersionPart, VersionLib} from "../../types/Version.sol";

import {Registerable} from "../../shared/Registerable.sol";
import {IVersionable} from "../../shared/IVersionable.sol";
import {Versionable} from "../../shared/Versionable.sol";

import {IService} from "./IService.sol";

abstract contract ServiceBase is 
    Registerable,
    Versionable,
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

    function _initializeServiceBase(address registry, NftId registryNftId, address initialOwner)
        internal 
        //onlyInitializing //TODO uncomment when "fully" upgradeable
    {// service must provide its name and version upon registration
        bytes memory data = abi.encode(getName(), getMajorVersion());
        _initializeRegisterable(registry, registryNftId, SERVICE(), false, initialOwner, data);
        _registerInterface(type(IService).interfaceId);
    }
}
