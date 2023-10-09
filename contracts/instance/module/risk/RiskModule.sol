// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRiskModule} from "./IRisk.sol";

import {IKeyValueStore} from "../../base/IKeyValueStore.sol";
import {ModuleBase} from "../../base/ModuleBase.sol";

contract RiskModule is
    ModuleBase,
    IRiskModule
{
    function initializeRiskModule(IKeyValueStore keyValueStore) internal {
        _initialize(keyValueStore);
    }

}