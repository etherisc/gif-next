// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Blocknumber} from "../types/Blocknumber.sol";
import {Timestamp} from "../types/Timestamp.sol";
import {Version} from "../types/Version.sol";


/// IMPORTANT
// Upgradeable contract MUST:
// 1) inherit from Versionable
// 2) implement version() function
// 3) implement internal _initialize() function with onlyInitializing modifier 
// 4) implement internal _upgrade() function with onlyInitializing modifier (1st version MUST revert)
// 5) have onlyInitialising modifier for each function callable inside _initialize()/_upgrade() (MUST use different functions for initialization/upgrade and normal operations)
// 6) use default empty constructor -> _disableInitializer() is called from Versionable contructor
// 7) use namespace storage
// 8) since now inheritance is used for upgradability, contract MUST BE inherited ONLY by the next version 
// Upgradeable contract SHOULD:
// 9) define all non private methods as virtual (in order to be able to upgrade them latter)
//    otherwise, it is still possible to upgrade contract, but everyone who is using it will have to switch to a new fucntions
//    in some cases this ok but not in the others...
//
// IMPORTANT
// Each version MUST:
// 1) define namespace storage struct if accessing storage
//      - DO NOT use structs inside, except
//      - CAN use structs ONLY inside mappings
// 2) ALWAYS define private getter if accessing storage
//      - MUST use default implementation, CAN change ONLY return type
//      - MUST use the same "LOCATION_V1"

interface IVersionable {

    struct VersionInfo {
        Version version;
        address implementation;
        address activatedBy;
        Timestamp activatedAt;
        Blocknumber activatedIn;
    }

    event LogVersionableInitialized(Version version, address implementation, address activatedBy);

    // TODO uncomment when all implementations are ready
    /**
     * @dev IMPORTANT
     * implementation MUST be guarded by initializer modifier
     * implementation MUST call internal function Versionable._updateVersionHistory 
     * new version MUST inherit from previous version
     */
    function initializeVersionable(address implementation, address activatedBy, bytes memory activationData) external;

    /**
     * @dev
     * implementation MUST be guarded by reinitializer(version().toUint64()) modifier
     * implementation MUST call internal function Versionable._updateVersionHistory
     * new version MUST inherit from previous version
     * the first verion MUST revert 
     */
    function upgradeVersionable(address implementation, address activatedBy, bytes memory upgradeData) external;

    /**
     * @dev returns true if the specified version has been activated for the current contract
     */
    function isInitialized(Version version) external view returns(bool);

    /**
     * @dev returns version of this contract
     * each new implementation MUST implement this function
     * version number MUST increase 
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

    // TODO make sure it is needed here
    /**
     * @dev returns currently active version
     */
    function getInitializedVersion() external view returns(uint64);

}
