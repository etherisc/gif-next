// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IDistributionModule} from "./IDistribution.sol";
import {IKeyValueStore} from "../../base/IKeyValueStore.sol";
import {ModuleBase} from "../../base/ModuleBase.sol";

contract DistributionModule is
    ModuleBase,
    IDistributionModule
{

    function initializeDistributionModule(IKeyValueStore keyValueStore) internal {
        _initialize(keyValueStore);
    }

}