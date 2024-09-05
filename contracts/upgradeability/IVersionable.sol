// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Version} from "../type/Version.sol";

/// IMPORTANT
// Upgradeable contract MUST:
// 1) inherit from Versionable
// 2) implement version() function
// 3) implement internal _initialize() function with onlyInitializing modifier 
// 4) implement internal _upgrade() function with onlyInitializing modifier (1st version MUST revert)
// 5) have onlyInitialising modifier for each function callable inside _initialize()/_upgrade() (MUST use different functions for initialization/upgrade and normal operations)
// 6) use default empty constructor -> _disableInitializer() is called from Versionable contructor
// 7) use namespace storage (should this be needed)
// 8) since now inheritance is used for upgradability, contract MUST BE inherited ONLY by the next version 
// Upgradeable contract SHOULD:
// 9) define all non private methods as virtual (in order to be able to upgrade them latter)
//    otherwise, it is still possible to upgrade contract, but everyone who is using it will have to switch to a new fucntions
//    in some cases this ok but not in the others...
//
// IMPORTANT
// If introducting/amending storage related to Versionable version MUST:
// 1) define namespace storage struct if accessing storage
//      - DO NOT use structs inside, except
//      - CAN use structs ONLY inside mappings
// 2) ALWAYS define private getter if accessing storage
//      - MUST use default implementation, CAN change ONLY return type

interface IVersionable {

    error ErrorVersionableInitializeNotImplemented();
    error ErrorVersionableUpgradeNotImplemented();

    /**
     * @dev IMPORTANT
     * implementation MUST be guarded by initializer modifier
     * new version MUST inherit from previous version
     */
    function initializeVersionable(address activatedBy, bytes memory activationData) external;

    /**
     * @dev
     * implementation MUST be guarded by reinitializer(version().toUint64()) modifier
     * new version MUST inherit from previous version
     * the first verion MUST revert 
     */
    function upgradeVersionable(bytes memory upgradeData) external;

    /**
     * @dev returns version of this contract
     * each new implementation MUST implement this function
     * version number MUST increase 
     */
    function getVersion() external pure returns(Version);

}
