// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ObjectType} from "../../contracts/type/ObjectType.sol";
import {Version, VersionLib} from "../../contracts/type/Version.sol";
import {IVersionable} from "../../contracts/shared/IVersionable.sol";
import {IRegisterable} from "../../contracts/shared/IRegisterable.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {Service} from "../../contracts/shared/Service.sol";
import {RegistryService} from "../../contracts/registry/RegistryService.sol";


contract RegistryServiceHarness is RegistryService {

    function exposed_getAndVerifyContractInfo(
        IRegisterable registerable,
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
            expectedType,
            expectedOwner);
    }

    function exposed_verifyObjectInfo(
        IRegistry.ObjectInfo memory info,
        ObjectType objectType
    )
        public
        view
    {
        _verifyObjectInfo(info, objectType);
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