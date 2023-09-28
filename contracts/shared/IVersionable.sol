// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Blocknumber, blockNumber} from "../types/Blocknumber.sol";
import {Timestamp, blockTimestamp} from "../types/Timestamp.sol";
import {Version, VersionPart} from "../types/Version.sol";

interface IVersionable {

    struct VersionInfo {
        Version version;
        address implementation;
        address activatedBy;
        Timestamp activatedAt;
        Blocknumber activatedIn;
    }

    event LogVersionableActivated(Version version, address implementation, address activatedBy);

    /**
     * @dev IMPORTANT this function needs to be implemented by each new version
     * any such activate implementation needs to call internal function call _activate() 
     * any new version needs to inherit from previous version
     */
    function activate(address implementation, address activatedBy) external;

    /**
     * @dev returns true if the specified version has been activated for the current contract
     */
    function isActivated(Version version) external view returns(bool);

    /**
     * @dev returns currently active version of this contract
     */
    function getVersion() external pure returns(Version);

    /**
     * @dev returns the number of all deployed versions of this contract
     */
    function getVersionCount() external view returns(uint256 numberOfVersions);

    /**
     * @dev returns the i-th (index) version of this contract
     */
    function getVersion(uint256 index) external view returns(Version version);

    /**
     * @dev returns the i-th (index) version info of this contract
     */
    function getVersionInfo(Version version) external view returns(VersionInfo memory versionInfo);

}
