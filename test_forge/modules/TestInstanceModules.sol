// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {InstanceBase} from "../../contracts/instance/InstanceBase.sol";
import {NftId} from "../../contracts/types/NftId.sol";

import {AccessModule} from "../../contracts/instance/module/access/Access.sol";
import {BundleModule} from "../../contracts/instance/module/bundle/BundleModule.sol";
import {ComponentModule} from "../../contracts/instance/module/component/ComponentModule.sol";
import {LifecycleModule} from "../../contracts/instance/module/lifecycle/LifecycleModule.sol";
import {PolicyModule} from "../../contracts/instance/module/policy/PolicyModule.sol";
import {PoolModule} from "../../contracts/instance/module/pool/PoolModule.sol";
import {TreasuryModule} from "../../contracts/instance/module/treasury/TreasuryModule.sol";

import {TestInstanceBase} from "./TestInstanceBase.sol";
import {Registerable} from "../../contracts/shared/Registerable.sol";
import {IAccessModule} from "../../contracts/instance/module/access/IAccess.sol";
import {IComponentModule} from "../../contracts/instance/module/component/IComponent.sol";
import {IPoolModule} from "../../contracts/instance/module/pool/IPoolModule.sol";
import {IPolicyModule} from "../../contracts/instance/module/policy/IPolicy.sol";
import {IBundleModule} from "../../contracts/instance/module/bundle/IBundle.sol";
import {IServiceLinked} from "../../contracts/instance/IServiceLinked.sol";


contract TestInstanceModuleAccess  is
    InstanceBase,
    AccessModule
{
    constructor(address registry, NftId registryNftId, address componentOwnerService, address productService, address poolService)
        InstanceBase(registry, registryNftId)
        ComponentModule()
    // solhint-disable-next-line no-empty-blocks
    {

    }

    function getRegistry() public view override (Registerable) returns (IRegistry registry) { return super.getRegistry(); }

    function PRODUCT_OWNER_ROLE() public view override (AccessModule) returns (bytes32 role) { return super.PRODUCT_OWNER_ROLE(); }
    function ORACLE_OWNER_ROLE() public view override (AccessModule) returns (bytes32 role) {return super.ORACLE_OWNER_ROLE(); }
    function POOL_OWNER_ROLE() public view override (AccessModule) returns (bytes32 role) { return super.POOL_OWNER_ROLE(); }

    function hasRole(bytes32 role, address member) public view override (AccessModule) returns (bool) { return super.hasRole(role, member); }

    function senderIsComponentOwnerService() external override (IServiceLinked) returns(bool isService) { return msg.sender == address(_componentOwnerService); }
    function senderIsProductService() external override (IServiceLinked) returns(bool isService) { return msg.sender == address(_productService); }
    function senderIsPoolService() external override (IServiceLinked) returns(bool isService) { return msg.sender == address(_poolService); }

    function requireSenderIsOwner() public view override (IAccessModule, Registerable) returns (bool senderIsOwner) { return super.requireSenderIsOwner(); }
}

contract TestInstanceModuleBundle  is
    InstanceBase,
    BundleModule
{
    constructor(address registry, NftId registryNftId, address componentOwnerService, address productService, address poolService)
        InstanceBase(registry, registryNftId)
        BundleModule()
    // solhint-disable-next-line no-empty-blocks
    {

    }

    function senderIsComponentOwnerService() external override (IServiceLinked) returns(bool isService) { return msg.sender == address(_componentOwnerService); }
    function senderIsProductService() external override (IBundleModule, IServiceLinked) returns(bool isService) { return msg.sender == address(_productService); }
    function senderIsPoolService() external override (IBundleModule, IServiceLinked) returns(bool isService) { return msg.sender == address(_poolService); }
}

contract TestInstanceModuleComponent  is
    InstanceBase,
    ComponentModule
{
    constructor(address registry, NftId registryNftId, address componentOwnerService, address productService, address poolService)
        InstanceBase(registry, registryNftId)
        ComponentModule()
    // solhint-disable-next-line no-empty-blocks
    {

    }

    function getRegistry() public view override (Registerable, IComponentModule) returns (IRegistry registry) { return super.getRegistry(); }

    function PRODUCT_OWNER_ROLE() public view override returns (bytes32 role) { return bytes32(1); }
    function ORACLE_OWNER_ROLE() public view override returns (bytes32 role) {return bytes32(2); }
    function POOL_OWNER_ROLE() public view override returns (bytes32 role) { return bytes32(3);  }

    function hasRole(bytes32 role, address member) public view override returns (bool) { return true; }

    function senderIsComponentOwnerService() external override (IComponentModule, IServiceLinked) returns(bool isService) { return msg.sender == address(_componentOwnerService); }
    function senderIsProductService() external override (IServiceLinked) returns(bool isService) { return msg.sender == address(_productService); }
    function senderIsPoolService() external override (IServiceLinked) returns(bool isService) { return msg.sender == address(_poolService); }
}

contract TestInstanceModulePolicy  is
    InstanceBase,
    PolicyModule
{
    constructor(address registry, NftId registryNftId, address componentOwnerService, address productService, address poolService)
        InstanceBase(registry, registryNftId)
        PolicyModule(productService)
    // solhint-disable-next-line no-empty-blocks
    {

    }

    function senderIsComponentOwnerService() external override (IServiceLinked) returns(bool isService) { return msg.sender == address(_componentOwnerService); }
    function senderIsProductService() external override (IPolicyModule, IServiceLinked) returns(bool isService) { return msg.sender == address(_productService); }
    function senderIsPoolService() external override (IServiceLinked) returns(bool isService) { return msg.sender == address(_poolService); }
}

contract TestInstanceModulePool  is
    InstanceBase,
    PoolModule
{
    constructor(address registry, NftId registryNftId, address componentOwnerService, address productService, address poolService)
        InstanceBase(registry, registryNftId)
        PoolModule()
    // solhint-disable-next-line no-empty-blocks
    {

    }

    function senderIsComponentOwnerService() external override (IServiceLinked) returns(bool isService) { return msg.sender == address(_componentOwnerService); }
    function senderIsProductService() external override (IPoolModule, IServiceLinked) returns(bool isService) { return msg.sender == address(_productService); }
    function senderIsPoolService() external override (IPoolModule, IServiceLinked) returns(bool isService) { return msg.sender == address(_poolService); }
}

contract TestInstanceModuleTreasury  is
    InstanceBase,
    TreasuryModule
{
    constructor(address registry, NftId registryNftId, address componentOwnerService, address productService, address poolService)
        InstanceBase(registry, registryNftId)
        TreasuryModule()
    // solhint-disable-next-line no-empty-blocks
    {

    }

    function senderIsComponentOwnerService() external override (IServiceLinked) returns(bool isService) { return msg.sender == address(_componentOwnerService); }
    function senderIsProductService() external override (IServiceLinked) returns(bool isService) { return msg.sender == address(_productService); }
    function senderIsPoolService() external override (IServiceLinked) returns(bool isService) { return msg.sender == address(_poolService); }
}
