// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Version, VersionLib} from "../../contracts/types/Version.sol";
import {Versionable} from "../../contracts/shared/Versionable.sol";

contract TestVersionable is Versionable {

    function getVersion()
        public 
        pure 
        virtual override
        returns(Version)
    {
        return VersionLib.toVersion(3,0,0);
    }
}