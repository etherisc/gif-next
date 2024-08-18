// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ObjectType, REGISTRY} from "../../contracts/type/ObjectType.sol";

import {Version, VersionLib} from "../../contracts/type/Version.sol";
import {Service} from "../../contracts/shared/Service.sol";
import {IVersionable} from "../../contracts/upgradeability/IVersionable.sol";
import {Versionable} from "../../contracts/upgradeability/Versionable.sol";

/*
contract RegistryServiceMock is Versionable {


    function _initialize(address owner, bytes memory data)
        internal
        onlyInitializing
        virtual override
    {}

    function getVersion()
        public
        pure
        virtual override
        returns(Version)
    {
        return VersionLib.toVersion(3, 0, 1);
    }

    function getMessage() external virtual returns (string memory message) {
        return "hi from mock";
    }
}
*/
contract RegistryServiceMock is Service {


    function _initialize(address owner, bytes memory data)
        internal
        onlyInitializing
        virtual override
    // solhint-disable-next-line no-empty-blocks
    {}

    function _upgrade(bytes memory data)
        internal
        onlyInitializing
        virtual override
    // solhint-disable-next-line no-empty-blocks
    {}

    function getVersion()
        public
        pure
        virtual override 
        returns(Version)
    {
        return VersionLib.toVersion(3, 0, 1);
    }

    function getMessage() external virtual returns (string memory message) {
        return "hi from mock";
    }

    function _getDomain()
        internal
        pure
        virtual override
        returns (ObjectType)
    {
        return REGISTRY();
    }
}
