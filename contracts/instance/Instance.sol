// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {NftId} from "../types/NftId.sol";

import {InstanceBase} from "./InstanceBase.sol";
import {AccessModule} from "./module/access/Access.sol";
import {LifecycleModule} from "./module/lifecycle/LifecycleModule.sol";
import {ComponentModule} from "./module/component/ComponentModule.sol";
import {PolicyModule} from "./module/policy/PolicyModule.sol";
import {PoolModule} from "./module/pool/PoolModule.sol";
import {BundleModule} from "./module/bundle/BundleModule.sol";
import {TreasuryModule} from "./module/treasury/TreasuryModule.sol";

import {IRegistry} from "../registry/IRegistry.sol";
import {Registerable} from "../shared/Registerable.sol";
import {IAccessModule} from "./module/access/IAccess.sol";
import {IBundleModule} from "./module/bundle/IBundle.sol";
import {IComponentModule} from "./module/component/IComponent.sol";
import {IPoolModule} from "./module/pool/IPoolModule.sol";
import {IPolicyModule} from "./module/policy/IPolicy.sol";
import {IServiceLinked} from "./IServiceLinked.sol";

import {IComponentOwnerService} from "./service/IComponentOwnerService.sol";
import {IProductService} from "./service/IProductService.sol";
import {IPoolService} from "./service/IPoolService.sol";

contract Instance is
    InstanceBase,
    AccessModule,
    BundleModule,
    ComponentModule,
    LifecycleModule,
    PolicyModule,
    PoolModule,
    TreasuryModule
{
    constructor(
        address registry,
        NftId registryNftId
    )
        InstanceBase(registry, registryNftId)
        AccessModule()
        BundleModule()
        ComponentModule()
        PolicyModule()
        PoolModule()
        TreasuryModule()
    {
    }

    function getRegistry() public view override (Registerable, IBundleModule, IComponentModule, IPolicyModule) returns (IRegistry registry) { return super.getRegistry(); }

    function PRODUCT_OWNER_ROLE() public view override (AccessModule, IComponentModule) returns (bytes32 role) { return super.PRODUCT_OWNER_ROLE(); }
    function ORACLE_OWNER_ROLE() public view override (AccessModule, IComponentModule) returns (bytes32 role) {return super.ORACLE_OWNER_ROLE(); }
    function POOL_OWNER_ROLE() public view override (AccessModule, IComponentModule) returns (bytes32 role) { return super.POOL_OWNER_ROLE(); }

    function hasRole(bytes32 role, address member) public view override (AccessModule, IComponentModule) returns (bool) { return super.hasRole(role, member); }

    function getComponentOwnerService() external view override (IComponentModule, IServiceLinked) returns(IComponentOwnerService service) { return _componentOwnerService; }
    function getProductService() external view override (IBundleModule, IPolicyModule, IPoolModule, IServiceLinked) returns(IProductService service) { return _productService; }
    function getPoolService() external view override (IBundleModule, IPoolModule, IServiceLinked) returns(IPoolService service) { return _poolService; }

    function getOwner() public view override (IAccessModule, Registerable) returns(address owner) { return super.getOwner(); }
}
