// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {VersionPart} from "../type/Version.sol";

import {AccessManagerExtendedWithDisable} from "./AccessManagerExtendedWithDisable.sol";

contract AccessManagerExtendedWithDisableInitializeable is AccessManagerExtendedWithDisable {

    function initialize(address initialAdmin, VersionPart version) initializer public {
        __AccessManagerExtendedWithDisable_init(initialAdmin, version);        
    }

}