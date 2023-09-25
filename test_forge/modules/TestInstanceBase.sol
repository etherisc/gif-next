// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {NftId} from "../../contracts/types/NftId.sol";
import {InstanceBase} from "../../contracts/instance/InstanceBase.sol";

import {IComponentModule} from "../../contracts/instance/module/component/IComponent.sol";
import {IPolicyModule} from "../../contracts/instance/module/policy/IPolicy.sol";
import {IPoolModule} from "../../contracts/instance/module/pool/IPoolModule.sol";
import {IBundleModule} from "../../contracts/instance/module/bundle/IBundle.sol";

import {IComponentOwnerService} from "../../contracts/instance/service/IComponentOwnerService.sol";
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
    {
    }

    function getComponentOwnerService() external view override returns(IComponentOwnerService service) { return _componentOwnerService; }
    function getProductService() external view override returns(IProductService service) { return _productService; }
    function getPoolService() external view override returns(IPoolService service) { return _poolService; }
}
