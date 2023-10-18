// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {NftId} from "../../contracts/types/NftId.sol";
import {InstanceBase} from "../../contracts/instance/base/InstanceBase.sol";

import {IComponentOwnerService} from "../../contracts/instance/service/IComponentOwnerService.sol";
import {IDistributionService} from "../../contracts/instance/service/IDistributionService.sol";
import {IProductService} from "../../contracts/instance/service/IProductService.sol";
import {IPoolService} from "../../contracts/instance/service/IPoolService.sol";

contract TestInstanceBase  is
    InstanceBase
{
    constructor(
        address registry,
        NftId registryNftId
    )
        InstanceBase(registry, registryNftId)
    // solhint-disable-next-line no-empty-blocks
    {
    }

    function getComponentOwnerService() external view override returns(IComponentOwnerService service) { return _componentOwnerService; }
    function getDistributionService() external view override returns(IDistributionService service) { return _distributionService; }
    function getProductService() external view override returns(IProductService service) { return _productService; }
    function getPoolService() external view override returns(IPoolService service) { return _poolService; }
}
