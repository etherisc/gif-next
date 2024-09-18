// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IVersionable} from "./IVersionable.sol";
import {Version, VersionPart, VersionLib, VersionPartLib} from "../type/Version.sol";


abstract contract Versionable is
    IVersionable 
{
    // TODO use arg of type Version
    function __Versionable_init(
        VersionPart release // wants to initialize to this release version
    )
        internal
        view
        virtual
    {
        VersionPart currentRelease = getRelease();
        if (!currentRelease.isValidRelease()) {
            revert ErrorVersionableReleaseInvalid(address(this), currentRelease);
        }

        //Version initializedVersion = VersionLib.toVersion(_getInitializedVersion());
        //if(initializedVersion != getVersion()) {}

        checkRelease(release);
    }

    function getVersion() public pure virtual returns(Version)
    {
        return VersionLib.toVersion(3, 0, 0);
    }

    function getRelease() public pure returns(VersionPart)
    {
        return getVersion().toMajorPart();
    }

    function checkRelease(VersionPart release) internal view {
        VersionPart currentRelease = getRelease();
        if(currentRelease != release) {
            revert ErrorVersionableReleaseMismatch(address(this), release, currentRelease);
        }
    }
}