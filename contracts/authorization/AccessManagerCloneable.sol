// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AccessManagerUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";

contract AccessManagerCloneable is
    AccessManagerUpgradeable
{

    function initialize(address initialAdmin)
        external
        initializer()
    {
        __AccessManager_init(initialAdmin);
    }
}