// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ObjectType} from "../../contracts/types/ObjectType.sol";
import {Version, VersionLib} from "../../contracts/types/Version.sol";
import {IVersionable} from "../../contracts/shared/IVersionable.sol";
import {IRegisterable} from "../../contracts/shared/IRegisterable.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {Service} from "../../contracts/shared/Service.sol";
import {RegistryService} from "../../contracts/registry/RegistryService.sol";


contract RegistryServiceHarness is RegistryService {

    function getAndVerifyContractInfo(
        IRegisterable registerable,
        ObjectType expectedType, 
        address expectedOwner)
        public
        view
        returns(
            IRegistry.ObjectInfo memory info, 
            bytes memory data
        )
    {
        (
            info, 
            data
        ) = _getAndVerifyContractInfo(
            registerable,
            expectedType,
            expectedOwner);
    }

    function verifyObjectInfo(
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