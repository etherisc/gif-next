// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {IRegistry} from "../registry/IRegistry.sol";
import {IService} from "./IService.sol";
import {IVersionable} from "../upgradeability/IVersionable.sol";
import {ObjectType, REGISTRY, SERVICE} from "../type/ObjectType.sol";
import {Registerable} from "./Registerable.sol";
import {RoleId, RoleIdLib} from "../type/RoleId.sol";
import {Version, VersionLib, VersionPartLib} from "../type/Version.sol";
import {Versionable} from "../upgradeability/Versionable.sol";


/// @dev service base contract
abstract contract Service is 
    Registerable,
    Versionable,
    AccessManagedUpgradeable,
    IService
{

    uint8 private constant GIF_MAJOR_VERSION = 3;


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
            address registryServiceAddress = _getServiceAddress(REGISTRY());

            // copy authority from already registered registry services
            __AccessManaged_init(IAccessManaged(registryServiceAddress).authority());
        }

        registerInterface(type(IAccessManaged).interfaceId);
        registerInterface(type(IService).interfaceId);
    }

    function getDomain() external virtual pure returns(ObjectType serviceDomain) {
        return _getDomain();
    }

    function getRoleId() external virtual pure returns(RoleId serviceRoleId) {
        return RoleIdLib.roleForTypeAndVersion(_getDomain(), VersionPartLib.toVersionPart(GIF_MAJOR_VERSION));
    }

    // from Versionable
    function getVersion()
        public 
        pure 
        virtual override (IVersionable, Versionable)
        returns(Version)
    {
        return VersionLib.toVersion(GIF_MAJOR_VERSION,0,0);
    }

    function _getDomain() internal virtual pure returns (ObjectType);

    function _getServiceAddress(ObjectType domain) internal view returns (address) {
        return getRegistry().getServiceAddress(domain, VersionPartLib.toVersionPart(GIF_MAJOR_VERSION));
    }
}