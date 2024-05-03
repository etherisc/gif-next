// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManagerExtended} from "./AccessManagerExtended.sol";


contract AccessManagerExtendedInitializeable is AccessManagerExtended {

    function initialize(address initialAdmin) initializer public {
        __AccessManagerExtended_init(initialAdmin);        
    }

}