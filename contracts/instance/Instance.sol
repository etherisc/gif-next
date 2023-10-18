// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {NftId} from "../types/NftId.sol";
import {RoleId} from "../types/RoleId.sol";

import {InstanceBase} from "./base/InstanceBase.sol";
import {AccessModule} from "./module/access/Access.sol";
import {ComponentModule} from "./module/component/ComponentModule.sol";
import {DistributionModule} from "./module/distribution/DistributionModule.sol";
import {PolicyModule} from "./module/policy/PolicyModule.sol";
import {PoolModule} from "./module/pool/PoolModule.sol";
import {RiskModule} from "./module/risk/RiskModule.sol";
import {BundleModule} from "./module/bundle/BundleModule.sol";
import {TreasuryModule} from "./module/treasury/TreasuryModule.sol";

import {IRegistry} from "../registry/IRegistry.sol";
import {Registerable} from "../shared/Registerable.sol";
import {IAccessModule} from "./module/access/IAccess.sol";
import {IBundleModule} from "./module/bundle/IBundle.sol";
import {IComponentModule} from "./module/component/IComponent.sol";
import {IPoolModule} from "./module/pool/IPoolModule.sol";
import {IPolicyModule} from "./module/policy/IPolicy.sol";
import {IInstanceBase} from "./base/IInstanceBase.sol";

import {IComponentOwnerService} from "./service/IComponentOwnerService.sol";
import {IDistributionService} from "./service/IDistributionService.sol";
import {IProductService} from "./service/IProductService.sol";
import {IPoolService} from "./service/IPoolService.sol";

import {IKeyValueStore} from "./base/IKeyValueStore.sol";

contract Instance is
    InstanceBase,
    AccessModule,
    BundleModule,
    ComponentModule,
    DistributionModule,
    PolicyModule,
    PoolModule,
    RiskModule,
    TreasuryModule
{
    constructor(
        address registry,
        NftId registryNftId
    )
        InstanceBase(registry, registryNftId)
        AccessModule()
        BundleModule()
        DistributionModule()
        ComponentModule()
        PolicyModule()
        PoolModule()
        TreasuryModule()
    {
        initializeBundleModule(_keyValueStore);
        initializeComponentModule(_keyValueStore);
        initializeDistributionModule(_keyValueStore);
        initializePolicyModule(_keyValueStore);
        initializePoolModule(_keyValueStore);
        initializeRiskModule(_keyValueStore);
    }

    function getRegistry() public view override (Registerable, IPolicyModule) returns (IRegistry registry) { return super.getRegistry(); }
    function getKeyValueStore() public view override (InstanceBase) returns (IKeyValueStore keyValueStore) { return super.getKeyValueStore(); }

    function getComponentOwnerService() external view override (IComponentModule, IInstanceBase) returns(IComponentOwnerService service) { return _componentOwnerService; }
    function getDistributionService() external view override (IInstanceBase) returns(IDistributionService service) { return _distributionService; }
    function getProductService() external view override (IBundleModule, IPolicyModule, IInstanceBase) returns(IProductService service) { return _productService; }
    function getPoolService() external view override (IBundleModule, IPoolModule, IInstanceBase) returns(IPoolService service) { return _poolService; }

    function getOwner() public view override (IAccessModule, Registerable) returns(address owner) { return super.getOwner(); }
}
