// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

type VersionPart is uint8;

using {
    versionPartGt as >,
    versionPartEq as ==,
    versionPartNe as !=,
    VersionPartLib.eqz,
    VersionPartLib.gtz,
    VersionPartLib.toInt,
    VersionPartLib.toString,
    VersionPartLib.isValidRelease
}
    for VersionPart global;

function versionPartGt(VersionPart a, VersionPart b) pure returns(bool isGreaterThan) { return VersionPart.unwrap(a) > VersionPart.unwrap(b); }
function versionPartEq(VersionPart a, VersionPart b) pure returns(bool isSame) { return VersionPart.unwrap(a) == VersionPart.unwrap(b); }
function versionPartNe(VersionPart a, VersionPart b) pure returns(bool isSame) { return VersionPart.unwrap(a) != VersionPart.unwrap(b); }

library VersionPartLib {

    error ErrorReleaseTooBig(VersionPart releaseMax, VersionPart release);

    function releaseMin() public pure returns (VersionPart) { return toVersionPart(3); }
    function releaseMax() public pure returns (VersionPart) { return toVersionPart(99); }

    function isValidRelease(VersionPart release) external pure returns(bool) { 
        uint256 releaseInt = VersionPart.unwrap(release);
        return 3 <= releaseInt && releaseInt <= 99; 
    } 

    function toString(VersionPart a) external pure returns (string memory) {
        if (a > releaseMax()) {
            revert ErrorReleaseTooBig(releaseMax(), a);
        }

        uint256 value = VersionPart.unwrap(a);
        if (value == 0) {
            return "0";
        }

        uint256 temp = value;
        uint256 digits = 0;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        bytes memory buffer = new bytes(digits);
        uint index = digits - 1;

        temp = value;
        while (temp != 0) {
            buffer[index] = bytes1(uint8(48 + temp % 10));
            temp /= 10;

            if (index > 0) {
                index--;
            }
        }

        return string(buffer);
    }

    function eqz(VersionPart a) external pure returns(bool) { return VersionPart.unwrap(a) == 0; }
    function gtz(VersionPart a) external pure returns(bool) { return VersionPart.unwrap(a) > 0; }
    function toInt(VersionPart a) external pure returns(uint256) { return VersionPart.unwrap(a); }
    function toVersionPart(uint256 a) public pure returns(VersionPart) { return VersionPart.wrap(uint8(a)); }
}

type Version is uint24; // contains major,minor,patch version parts

using {
    versionGt as >,
    versionEq as ==,
    VersionLib.toInt,
    VersionLib.toUint64,
    VersionLib.toMajorPart,
    VersionLib.toVersionParts
}
    for Version global;

function versionGt(Version a, Version b) pure returns(bool isGreaterThan) { return Version.unwrap(a) > Version.unwrap(b); }
function versionEq(Version a, Version b) pure returns(bool isSame) { return Version.unwrap(a) == Version.unwrap(b); }

library VersionLib {

    function toInt(Version version) external pure returns(uint) { return Version.unwrap(version); }

    function toUint64(Version version) external pure returns(uint64) { return Version.unwrap(version); }

    function toMajorPart(Version version)
        external    
        pure 
        returns(VersionPart major)
    { 
        uint24 versionInt = Version.unwrap(version);
        uint8 majorInt = uint8(versionInt >> 16);
        return VersionPart.wrap(majorInt);
    }

    function toVersionParts(Version version)
        external
        pure
        returns(
            VersionPart major,
            VersionPart minor,
            VersionPart patch
        )
    {
        uint24 versionInt = Version.unwrap(version);
        uint8 majorInt = uint8(versionInt >> 16);

        versionInt -= majorInt << 16;
        uint8 minorInt = uint8(versionInt >> 8);
        uint8 patchInt = uint8(versionInt - (minorInt << 8));

        return (
            VersionPart.wrap(majorInt),
            VersionPart.wrap(minorInt),
            VersionPart.wrap(patchInt)
        );
    }

    // function toVersionPart(uint256 versionPart) public pure returns(VersionPart) { 
    //     return VersionPart.wrap(uint8(versionPart)); 
    // }

    function toVersion(
        uint256 major,
        uint256 minor,
        uint256 patch
    )
        external
        pure
        returns(Version)
    {
        require(
            major < 256 && minor < 256 && patch < 256,
            "ERROR:VRS-010:VERSION_PART_TOO_BIG");

        return Version.wrap(
            uint24(
                (major << 16) + (minor << 8) + patch));
    }

    // TODO check for overflow?
    function toVersion(uint64 versionNumber) external pure returns(Version) {
        //assert(versionNumber <= type(Version).max);
        return Version.wrap(uint24(versionNumber));
    }

    // TODO rename to zero()
    function zeroVersion() external pure returns(Version) {
        return Version.wrap(0);
    }
}
