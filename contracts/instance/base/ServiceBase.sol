// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {NftId, zeroNftId} from "../../types/NftId.sol";
import {ObjectType, SERVICE} from "../../types/ObjectType.sol";
import {Version, VersionPart} from "../../types/Version.sol";

import {Registerable} from "../../shared/Registerable.sol";
import {IVersionable} from "../../shared/IVersionable.sol";
import {Versionable} from "../../shared/Versionable.sol";

import {IService} from "./IService.sol";

abstract contract ServiceBase is 
    Registerable,
    Versionable,
    IService
{

    function getMajorVersion() external view override returns(VersionPart majorVersion) {
        return this.getVersion().toMajorPart();
    }

    function _initializeServiceBase(address registry, NftId registryNftId, address initialOwner)
        internal 
        //onlyInitializing //TODO uncomment when "fully" upgradeable
    {
        _initializeRegisterable(registry, registryNftId, SERVICE(), initialOwner);
        _registerInterface(type(IService).interfaceId);
    }
}
