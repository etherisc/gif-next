// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {IRegistry} from "../registry/IRegistry.sol";
import {IService} from "./IService.sol";
import {IVersionable} from "../shared/IVersionable.sol";
import {ObjectType, SERVICE} from "../type/ObjectType.sol";
import {Registerable} from "./Registerable.sol";
import {RoleId, RoleIdLib} from "../type/RoleId.sol";
import {Version, VersionLib, VersionPartLib} from "../type/Version.sol";
import {Versionable} from "../shared/Versionable.sol";
import {Upgradeable} from "../upgradeability/Upgradeable.sol";


/// @dev service base contract
abstract contract Service is 
    Registerable, 
    Upgradeable,
    ReentrancyGuardUpgradeable,
    IService
{

    function __Service_init(
        address authority, // real authority for registry service adress(0) for other services
        address registry, 
        address initialOwner
    )
        internal
        virtual
        onlyInitializing()
    {
        __ReentrancyGuard_init();

        __Registerable_init(
            authority,
            registry, 
            IRegistry(registry).getNftId(), 
            SERVICE(), 
            false, // is interceptor
            initialOwner, 
            ""); // data

        _registerInterface(type(IService).interfaceId);
    }

    function getDomain() external virtual pure returns(ObjectType serviceDomain) {
        return _getDomain();
    }

    function getVersion() public pure virtual override (IVersionable, Versionable) returns(Version) {
        return VersionLib.toVersion(3, 0, 0);
    }


    function getRoleId() external virtual view returns(RoleId serviceRoleId) {
        return RoleIdLib.toServiceRoleId(_getDomain(), getRelease());
    }

    //--- internal functions --------------------------------------------------------//
    function _getDomain() internal virtual pure returns (ObjectType);


    function _getServiceAddress(ObjectType domain) internal view returns (address) {
        return getRegistry().getServiceAddress(domain, getRelease());
    }
}