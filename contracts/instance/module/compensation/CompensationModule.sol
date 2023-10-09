// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {ICompensationModule} from "./ICompensation.sol";
import {IKeyValueStore} from "../../base/IKeyValueStore.sol";
import {ModuleBase} from "../../base/ModuleBase.sol";

contract CompensationModule is
    ModuleBase,
    ICompensationModule
{

    function initializeCompensationModule(IKeyValueStore keyValueStore) internal {
        _initialize(keyValueStore);
    }

}