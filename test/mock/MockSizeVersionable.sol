// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Upgradeable} from "../../contracts/upgradeability/Upgradeable.sol";
import {Version, VersionLib} from "../../contracts/type/Version.sol";
import {IVersionable} from "../../contracts/shared/IVersionable.sol";
import {Versionable} from "../../contracts/shared/Versionable.sol";

contract MockSizeUpgradeable is Upgradeable {
    function getVersion() public pure virtual override (Versionable, IVersionable) returns(Version) {
        return VersionLib.zeroVersion();
    }
}
