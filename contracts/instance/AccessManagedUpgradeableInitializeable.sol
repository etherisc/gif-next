// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";


contract AccessManagedUpgradeableInitializeable is AccessManagedUpgradeable {

    bool private _initialized;

    function __AccessManagedUpgradeableInitializeable_init(address initialAuthority) public {
        require(!_initialized, "AccessManaged: already initialized");
        _setAuthority(initialAuthority);
        _initialized = true;
    }

}