// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Versionable} from "../../contracts/shared/Versionable.sol";
import {Version, VersionLib} from "../../contracts/type/Version.sol";

contract MockSizeVersionable is Versionable {
    function getVersion() public pure virtual override returns(Version) {
        return VersionLib.zero();
    }
}
