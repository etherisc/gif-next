// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Version, VersionPart, toVersion, toVersionPart, zeroVersion} from "../types/Version.sol";

contract TestVersion {

    function createVersion(uint major, uint minor, uint patch) external pure returns(Version) {
        return toVersion(
            toVersionPart(uint8(major)),
            toVersionPart(uint8(minor)),
            toVersionPart(uint8(patch)));
    }

    function createVersionPart(uint versionPart) external pure returns(VersionPart) {
        return toVersionPart(uint8(versionPart));
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
        return zeroVersion();
    }

    function isSameVersion(Version a, Version b) external pure returns(bool) {
        return a == b;
    }

    function isLargerVersion(Version a, Version b) external pure returns(bool) {
        return a > b;
    }

}