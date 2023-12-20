// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Version, VersionLib} from "../../contracts/types/Version.sol";
import {Versionable} from "../../contracts/shared/Versionable.sol";


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