// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

// import {IRegistry} from "../../registry/IRegistry.sol";
// import {ITreasury, ITreasuryModule, TokenHandler} from "../../instance/module/treasury/ITreasury.sol";
import {NftId, zeroNftId} from "../../types/NftId.sol";
import {ObjectType, SERVICE} from "../../types/ObjectType.sol";
import {Version, VersionPart, toVersion, toVersionPart} from "../../types/Version.sol";

import {Registerable} from "../../shared/Registerable.sol";
import {IVersionable} from "../../shared/IVersionable.sol";
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
        Registerable(registry, registryNftId)
        Versionable()
    {
        _registerInterface(type(IService).interfaceId);
    }

    function getMajorVersion() external view override returns(VersionPart majorVersion) {
        return this.getVersion().toMajorPart();
    }

    function getType() external pure override returns (ObjectType) {
        return SERVICE();
    }
}
