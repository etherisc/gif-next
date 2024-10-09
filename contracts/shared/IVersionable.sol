// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Version, VersionPart} from "../type/Version.sol";

interface IVersionable {

    error ErrorVersionableReleaseInvalid(address target, VersionPart invalidRelease);
    error ErrorVersionableReleaseMismatch(address target, VersionPart expected, VersionPart actual);

    /**
     * @dev returns version of this contract
     * implementation MUST define version in this function
     * version number MUST increase 
     */
    function getVersion() external pure returns(Version);

    function getRelease() external pure returns(VersionPart);
}
