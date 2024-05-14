// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {ObjectType, REGISTRY, SERVICE} from "../type/ObjectType.sol";
import {NftId} from "../type/NftId.sol";
import {Version, VersionPart, VersionLib, VersionPartLib} from "../type/Version.sol";

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

    uint8 private constant GIF_MAJOR_VERSION = 3;

    // from Versionable
    function getVersion()
        public 
        pure 
        virtual override (IVersionable, Versionable)
        returns(Version)
    {
        return VersionLib.toVersion(GIF_MAJOR_VERSION,0,0);
    }

    function initializeService(
        address registry, 
        address authority, // real authority for registry service adress(0) for other services
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

        // externally provided authority
        if(authority != address(0)) {
            __AccessManaged_init(authority);
        } else {
            address registryServiceAddress = getRegistry().getServiceAddress(
                REGISTRY(), 
                VersionPartLib.toVersionPart(GIF_MAJOR_VERSION));

            // copy authority from already registered registry services
            __AccessManaged_init(IAccessManaged(registryServiceAddress).authority());
        }

        registerInterface(type(IAccessManaged).interfaceId);
        registerInterface(type(IService).interfaceId);
    }


    function _getServiceAddress(ObjectType domain) internal view returns (address) {
        return getRegistry().getServiceAddress(domain, getVersion().toMajorPart());
    }
}