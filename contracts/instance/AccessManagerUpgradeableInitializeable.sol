// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManagerUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";


contract AccessManagerUpgradeableInitializeable is AccessManagerUpgradeable {

    bool private _initialized;

    function __AccessManagerUpgradeableInitializeable_init(address initialAdmin) public {
        require(!_initialized, "AccessManager: already initialized");
        
        if (initialAdmin == address(0)) {
            revert AccessManagerInvalidInitialAdmin(address(0));
        }

        // admin is active immediately and without any execution delay.
        _grantRole(ADMIN_ROLE, initialAdmin, 0, 0);
        _initialized = true;
    }

}