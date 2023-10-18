// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Key32} from "../../types/Key32.sol";
import {StateId} from "../../types/StateId.sol";

import {IKeyValueStore} from "./IKeyValueStore.sol";
import {IComponentOwnerService} from "../service/IComponentOwnerService.sol";
import {IDistributionService} from "../service/IDistributionService.sol";
import {IProductService} from "../service/IProductService.sol";
import {IPoolService} from "../service/IPoolService.sol";

interface IInstanceBase {
    function getKeyValueStore() external view returns (IKeyValueStore keyValueStore);
    function updateState(Key32 key, StateId state) external;

    function getComponentOwnerService() external view returns(IComponentOwnerService service);
    function getDistributionService() external view returns(IDistributionService);
    function getProductService() external view returns(IProductService service);
    function getPoolService() external view returns(IPoolService service);
}
