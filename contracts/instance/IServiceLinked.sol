// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IComponentOwnerService} from "./service/IComponentOwnerService.sol";
import {IProductService} from "./service/IProductService.sol";
import {IPoolService} from "./service/IPoolService.sol";

interface IServiceLinked {
    function getComponentOwnerService() external view returns(IComponentOwnerService service);
    function getProductService() external view returns(IProductService service);
    function getPoolService() external view returns(IPoolService service);
}
