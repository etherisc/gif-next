// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IVersionable} from "../shared/IVersionable.sol";

/// IMPORTANT
// Upgradeable contract MUST:
// 1) inherit Upgradeable
// 2) implement getVersion() function
// 3) implement internal _initialize() function with onlyInitializing modifier 
// 4) implement internal _upgrade() function with onlyInitializing modifier (1st version MUST revert)
// 5) have onlyInitialising modifier for each function callable inside _initialize()/_upgrade() 
// 6) use different functions for initialization, upgrade and normal operations
// 7) use default empty constructor -> _disableInitializer() is called from Upgradeable contructor
// 8) use namespace storage (should storage be needed)
// Upgradeable contract SHOULD:
// 9) define all non private methods as virtual (in order to be able to upgrade them latter)
//    otherwise, it is still possible to upgrade contract, but everyone who is using it will have to switch to a new functions
//    in some cases this ok but not in the others...
//
// IMPORTANT
// If introducting/amending storage related to Versionable version MUST:
// 1) define namespace storage struct if accessing storage
//      - DO NOT use structs inside, except
//      - CAN use structs ONLY inside mappings
// 2) ALWAYS define private getter if accessing storage
//      - MUST use default implementation, CAN change ONLY return type

interface IUpgradeable is IVersionable {

    error ErrorVersionableInitializeNotImplemented();
    error ErrorVersionableUpgradeNotImplemented();

    /**
     * @dev IMPORTANT
     * top level initializer for each upgradeable
     * implementation MUST be guarded by initializer modifier
     * new version MUST inherit from previous version
     */
    function initialize(address activatedBy, bytes memory activationData) external;

    /**
     * @dev
     * top level reinitializer for each upgradeable
     * implementation MUST be guarded by reinitializer(version().toUint64()) modifier
     * new version MUST inherit from previous version
     * the first verion MUST revert 
     */
    function upgrade(bytes memory upgradeData) external;
}
