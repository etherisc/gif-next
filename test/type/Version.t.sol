// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {Test} from "../../lib/forge-std/src/Test.sol";
import {Version, VersionLib, VersionPart, VersionPartLib} from "../../contracts/type/Version.sol";

contract VersionTest is Test {

    uint8 public constant MAJOR = 3;
    uint8 public constant MINOR = 78;
    uint8 public constant PATCH = 204;

    Version public version;
    VersionPart public majorVersion;
    VersionPart public minorVersion;
    VersionPart public patchVersion;

    function setUp() public {
        version = VersionLib.toVersion(MAJOR, MINOR, PATCH);
        majorVersion = VersionPartLib.toVersionPart(MAJOR);
        minorVersion = VersionPartLib.toVersionPart(MINOR);
        patchVersion = VersionPartLib.toVersionPart(PATCH);
    }

    function test_versionSetUp() public {
        assertEq(majorVersion.toInt(), MAJOR, "unexpected major version part");
        assertEq(minorVersion.toInt(), MINOR, "unexpected minor version part");
        assertEq(patchVersion.toInt(), PATCH, "unexpected patch version part");

        (VersionPart p1, VersionPart p2, VersionPart p3) = version.toVersionParts();

        assertEq(p1.toInt(), majorVersion.toInt(), "unexpected major version");
        assertEq(p2.toInt(), minorVersion.toInt(), "unexpected minor version");
        assertEq(p3.toInt(), patchVersion.toInt(), "unexpected patch version");
    }

    function test_versionToMajorPart() public {
        assertEq(version.toMajorPart().toInt(), MAJOR, "unexpected major version part");
    }

    function test_versionPartEq() public {
        (VersionPart p1, VersionPart p2, VersionPart p3) = version.toVersionParts();

        assertTrue(p1.toInt() == majorVersion.toInt(), "unexpected major version part eq");
        assertTrue(p2.toInt() == minorVersion.toInt(), "unexpected minor version part eq");
        assertTrue(p3.toInt() == patchVersion.toInt(), "unexpected patch version part eq");

        assertFalse(p1.toInt() == majorVersion.toInt() + 1, "unexpected major version part ne");
        assertFalse(p2.toInt() == minorVersion.toInt() + 1, "unexpected minor version part ne");
        assertFalse(p3.toInt() == patchVersion.toInt() + 1, "unexpected patch version part ne");

        assertTrue(p1.toInt() != majorVersion.toInt() + 1, "unexpected major version part ne");
        assertTrue(p2.toInt() != minorVersion.toInt() + 1, "unexpected minor version part ne");
        assertTrue(p3.toInt() != patchVersion.toInt() + 1, "unexpected patch version part ne");

        assertFalse(p1.toInt() != majorVersion.toInt(), "unexpected major version part eq");
        assertFalse(p2.toInt() != minorVersion.toInt(), "unexpected minor version part eq");
        assertFalse(p3.toInt() != patchVersion.toInt(), "unexpected patch version part eq");
    }
}
