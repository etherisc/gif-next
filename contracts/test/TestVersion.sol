// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Version, VersionPart, VersionLib} from "../types/Version.sol";

contract TestVersion {

    function createVersion(uint major, uint minor, uint patch) external pure returns(Version) {
        return VersionLib.toVersion(major, minor, patch);
    }

    function createVersionPart(uint versionPart) external pure returns(VersionPart) {
        return VersionLib.toVersionPart(uint8(versionPart));
    }

    function getVersionParts(Version version)
        external
        pure
        returns(
            VersionPart major,
            VersionPart minor,
            VersionPart patch
        )
    {
        return version.toVersionParts();
    }

    function getMajorPart(Version version) external pure returns(VersionPart major) {
        return version.toMajorPart();
    }

    function getZeroVersion() external pure returns(Version) {
        return VersionLib.zeroVersion();
    }

    function isSameVersion(Version a, Version b) external pure returns(bool) {
        return a == b;
    }

    function isLargerVersion(Version a, Version b) external pure returns(bool) {
        return a > b;
    }

}