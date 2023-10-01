// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IKeyValueStore} from "./IKeyValueStore.sol";
import {IComponentOwnerService} from "./service/IComponentOwnerService.sol";
import {IProductService} from "./service/IProductService.sol";
import {IPoolService} from "./service/IPoolService.sol";

interface IInstanceBase {
    function getKeyValueStore() external view returns (IKeyValueStore keyValueStore);
    function getComponentOwnerService() external view returns(IComponentOwnerService service);
    function getProductService() external view returns(IProductService service);
    function getPoolService() external view returns(IPoolService service);
}
