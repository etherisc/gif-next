// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {NftId} from "../../types/NftId.sol";
import {SERVICE} from "../../types/ObjectType.sol";
import {Version, VersionPart} from "../../types/Version.sol";

import {Registerable} from "../../shared/Registerable.sol";
import {Versionable} from "../../shared/Versionable.sol";

import {IService} from "./IService.sol";

abstract contract ServiceBase is 
    Registerable,
    Versionable,
    IService
{

    constructor(
        address registry,
        NftId registryNftId
    )
        Registerable(registry, registryNftId, SERVICE())
        Versionable()
    {
        _registerInterface(type(IService).interfaceId);
    }

    function getMajorVersion() external view override returns(VersionPart majorVersion) {
        return this.getVersion().toMajorPart();
    }
}
