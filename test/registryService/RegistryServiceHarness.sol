// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ObjectType} from "../../contracts/type/ObjectType.sol";
import {NftId} from "../../contracts/type/NftId.sol";
import {Version, VersionLib} from "../../contracts/type/Version.sol";
import {IUpgradeable} from "../../contracts/upgradeability/IUpgradeable.sol";
import {Upgradeable} from "../../contracts/upgradeability/Upgradeable.sol";
import {IRegisterable} from "../../contracts/shared/IRegisterable.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {Service} from "../../contracts/shared/Service.sol";
import {RegistryService} from "../../contracts/registry/RegistryService.sol";


contract RegistryServiceHarness is RegistryService {

    function exposed_getAndVerifyContractInfo(
        IRegisterable registerable,
        NftId expectedParent,
        ObjectType expectedType, 
        address expectedOwner)
        public
        // view
        returns(
            IRegistry.ObjectInfo memory info
        )
    {
        info = _getAndVerifyContractInfo(
            registerable,
            expectedParent,
            expectedType,
            expectedOwner);
    }

    function exposed_verifyObjectInfo(
        IRegistry.ObjectInfo memory info,
        address owner,
        ObjectType objectType
    )
        public
        view
    {
        _verifyObjectInfo(info, owner, objectType);
    }

    function getVersion()
        public
        pure
        virtual override (IVersionable, Service)
        returns(Version)
    {
        return VersionLib.toVersion(3, 3, 3);
    }

    function _upgrade(bytes memory data)
        internal
        onlyInitializing
        override
    // solhint-disable-next-line no-empty-blocks
    {}
}