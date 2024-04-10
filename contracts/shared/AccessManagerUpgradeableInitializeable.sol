// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManagerUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";


contract AccessManagerUpgradeableInitializeable is AccessManagerUpgradeable {

    function initialize(address initialAdmin) initializer public {
        __AccessManager_init(initialAdmin);        
    }

}