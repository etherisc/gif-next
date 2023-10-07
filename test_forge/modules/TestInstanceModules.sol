// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {InstanceBase} from "../../contracts/instance/base/InstanceBase.sol";
import {NftId} from "../../contracts/types/NftId.sol";
import {RoleId} from "../../contracts/types/RoleId.sol";

import {AccessModule} from "../../contracts/instance/module/access/Access.sol";
import {BundleModule} from "../../contracts/instance/module/bundle/BundleModule.sol";
import {ComponentModule} from "../../contracts/instance/module/component/ComponentModule.sol";
import {CompensationModule} from "../../contracts/instance/module/compensation/CompensationModule.sol";
import {RiskModule} from "../../contracts/instance/module/risk/RiskModule.sol";
import {PolicyModule} from "../../contracts/instance/module/policy/PolicyModule.sol";
import {PoolModule} from "../../contracts/instance/module/pool/PoolModule.sol";
import {TreasuryModule} from "../../contracts/instance/module/treasury/TreasuryModule.sol";

import {Registerable} from "../../contracts/shared/Registerable.sol";
import {IAccessModule} from "../../contracts/instance/module/access/IAccess.sol";
import {IComponentModule} from "../../contracts/instance/module/component/IComponent.sol";
import {ICompensationModule} from "../../contracts/instance/module/compensation/ICompensation.sol";
import {IRiskModule} from "../../contracts/instance/module/risk/IRisk.sol";
import {IPoolModule} from "../../contracts/instance/module/pool/IPoolModule.sol";
import {IPolicyModule} from "../../contracts/instance/module/policy/IPolicy.sol";
import {IBundleModule} from "../../contracts/instance/module/bundle/IBundle.sol";

import {IInstanceBase} from "../../contracts/instance/base/IInstanceBase.sol";
import {IKeyValueStore} from "../../contracts/instance/base/IKeyValueStore.sol";
import {IComponentOwnerService} from "../../contracts/instance/service/IComponentOwnerService.sol";
import {IProductService} from "../../contracts/instance/service/IProductService.sol";
import {IPoolService} from "../../contracts/instance/service/IPoolService.sol";


contract TestInstanceModuleAccess  is
    InstanceBase,
    AccessModule
{
    constructor(address registry, NftId registryNftId)
        InstanceBase(registry, registryNftId)
        AccessModule()
    // solhint-disable-next-line no-empty-blocks
    {

    }

    function getRegistry() public view override (Registerable) returns (IRegistry registry) { return super.getRegistry(); }

    function hasRole(RoleId role, address member) public view override (AccessModule) returns (bool) { return super.hasRole(role, member); }

    function getComponentOwnerService() external view override returns(IComponentOwnerService service) { return _componentOwnerService; }
    function getProductService() external view override returns(IProductService service) { return _productService; }
    function getPoolService() external view override returns(IPoolService service) { return _poolService; }

    function getOwner() public view override (IAccessModule, Registerable) returns (address owner) { return super.getOwner(); }
}

contract TestInstanceModuleBundle  is
    InstanceBase,
    BundleModule
{
    constructor(address registry, NftId registryNftId)
        InstanceBase(registry, registryNftId)
        BundleModule()
    // solhint-disable-next-line no-empty-blocks
    {

    }
    function getRegistry() public view override (Registerable, IBundleModule) returns (IRegistry registry) { return super.getRegistry(); }
    function getKeyValueStore() public view override (InstanceBase, IBundleModule) returns (IKeyValueStore keyValueStore) { return super.getKeyValueStore(); }

    function getComponentOwnerService() external view override returns(IComponentOwnerService) { return _componentOwnerService; }
    function getProductService() external view override (IBundleModule, IInstanceBase) returns(IProductService service) { return _productService; }
    function getPoolService() external view override (IBundleModule, IInstanceBase) returns(IPoolService service) { return _poolService; }
}

contract TestInstanceModuleComponent  is
    InstanceBase,
    ComponentModule
{
    constructor(address registry, NftId registryNftId)
        InstanceBase(registry, registryNftId)
        ComponentModule()
    // solhint-disable-next-line no-empty-blocks
    {

    }

    function getRegistry() public view override (Registerable, IComponentModule) returns (IRegistry registry) { return super.getRegistry(); }

    function hasRole(RoleId, address) public pure override returns (bool) { return true; }

    function getComponentOwnerService() external view override (IComponentModule, IInstanceBase) returns(IComponentOwnerService) { return _componentOwnerService; }
    function getProductService() external view override (IInstanceBase) returns(IProductService service) { return _productService; }
    function getPoolService() external view override (IInstanceBase) returns(IPoolService service) { return _poolService; }

    function getKeyValueStore() public view virtual override (InstanceBase, IComponentModule) returns (IKeyValueStore keyValueStore) { return super.getKeyValueStore(); }    
}

contract TestInstanceModulePolicy  is
    InstanceBase,
    PolicyModule
{
    constructor(address registry, NftId registryNftId)
        InstanceBase(registry, registryNftId)
        PolicyModule()
    // solhint-disable-next-line no-empty-blocks
    {

    }

    function getRegistry() public view override (Registerable, IPolicyModule) returns (IRegistry registry) { return super.getRegistry(); }

    function getComponentOwnerService() external view override (IInstanceBase) returns(IComponentOwnerService) { return _componentOwnerService; }
    function getProductService() external view override (IPolicyModule, IInstanceBase) returns(IProductService service) { return _productService; }
    function getPoolService() external view override (IInstanceBase) returns(IPoolService service) { return _poolService; }
}

contract TestInstanceModulePool  is
    InstanceBase,
    PoolModule
{
    constructor(address registry, NftId registryNftId)
        InstanceBase(registry, registryNftId)
        PoolModule()
    // solhint-disable-next-line no-empty-blocks
    {

    }

    function getComponentOwnerService() external view override (IInstanceBase) returns(IComponentOwnerService) { return _componentOwnerService; }
    function getProductService() external view override (IInstanceBase) returns(IProductService service) { return _productService; }
    function getPoolService() external view override (IPoolModule, IInstanceBase) returns(IPoolService service) { return _poolService; }
}

contract TestInstanceModuleTreasury  is
    InstanceBase,
    TreasuryModule
{
    constructor(address registry, NftId registryNftId)
        InstanceBase(registry, registryNftId)
        TreasuryModule()
    // solhint-disable-next-line no-empty-blocks
    {

    }

    function getComponentOwnerService() external view override (IInstanceBase) returns(IComponentOwnerService) { return _componentOwnerService; }
    function getProductService() external view override (IInstanceBase) returns(IProductService service) { return _productService; }
    function getPoolService() external view override (IInstanceBase) returns(IPoolService service) { return _poolService; }
}

contract TestInstanceModuleCompensation is
    InstanceBase,
    CompensationModule
{
    constructor(address registry, NftId registryNftId)
        InstanceBase(registry, registryNftId)
        CompensationModule()
    // solhint-disable-next-line no-empty-blocks
    {

    }

    function getComponentOwnerService() external view override (IInstanceBase) returns(IComponentOwnerService) { return _componentOwnerService; }
    function getProductService() external view override (IInstanceBase) returns(IProductService service) { return _productService; }
    function getPoolService() external view override (IInstanceBase) returns(IPoolService service) { return _poolService; }
}

contract TestInstanceModuleRisk is
    InstanceBase,
    RiskModule
{
    constructor(address registry, NftId registryNftId)
        InstanceBase(registry, registryNftId)
        RiskModule()
    // solhint-disable-next-line no-empty-blocks
    {

    }

    function getComponentOwnerService() external view override (IInstanceBase) returns(IComponentOwnerService) { return _componentOwnerService; }
    function getProductService() external view override (IInstanceBase) returns(IProductService service) { return _productService; }
    function getPoolService() external view override (IInstanceBase) returns(IPoolService service) { return _poolService; }
}
