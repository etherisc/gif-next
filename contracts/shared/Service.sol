// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {ObjectType, SERVICE} from "../types/ObjectType.sol";
import {NftId, zeroNftId} from "../types/NftId.sol";
import {Version, VersionPart, VersionLib, VersionPartLib} from "../types/Version.sol";

import {Versionable} from "./Versionable.sol";
import {IService} from "./IService.sol";
import {IVersionable} from "./IVersionable.sol";
import {Versionable} from "./Versionable.sol";
import {Registerable} from "./Registerable.sol";

import {IRegistry} from "../registry/IRegistry.sol";


/// @dev service base contract
abstract contract Service is 
    Registerable,
    Versionable,
    AccessManagedUpgradeable,
    IService
{
    function getDomain() public pure virtual override returns(ObjectType);

    // version major version MUST be consistent with major version of getVersion()
    function getMajorVersion() public view virtual override returns(VersionPart majorVersion) {
        return VersionPartLib.toVersionPart(3); 
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

    function initializeService(
        address registry, 
        // address authority, // TODO needs authority as parameter for initialization
        address initialOwner
    )
        public
        virtual
        onlyInitializing()
    {
        initializeRegisterable(
            registry, 
            IRegistry(registry).getNftId(), 
            SERVICE(), 
            false, // is interceptor
            initialOwner, 
            ""); // data

        registerInterface(type(IAccessManaged).interfaceId);
        registerInterface(type(IService).interfaceId);
    }
}