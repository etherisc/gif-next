// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IVersionable} from "../../contracts/shared/IVersionable.sol";
import {RegistryService} from "../../contracts/registry/RegistryService.sol";
import {Version, VersionLib} from "../../contracts/types/Version.sol";
import {ServiceBase} from "../../contracts/instance/base/ServiceBase.sol";


contract RegistryServiceUpgradeMock is RegistryService {


    function _initialize(address owner, bytes memory data)
        internal
        onlyInitializing
        virtual override
    { }

    function _upgrade(bytes memory data)
        internal
        onlyInitializing
        virtual override
    { }

    function getVersion()
        public
        pure
        virtual override (IVersionable, ServiceBase)
        returns(Version)
    {
        return VersionLib.toVersion(3, 0, 1);
    }

    function getMessage() external virtual returns (string memory message) {
        return "hi from upgrade mock";
    }
}