// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {IVersionable} from "../shared/IVersionable.sol";
import {IRegisterable} from "../shared/IRegisterable.sol";
import {IOwnable} from "../shared/IOwnable.sol";

import {IAccessModule} from "./module/access/IAccess.sol";
import {ILifecycleModule} from "./module/lifecycle/ILifecycle.sol";
import {IComponentModule} from "./module/component/IComponent.sol";
import {IPolicyModule} from "./module/policy/IPolicy.sol";
import {IPoolModule} from "./module/pool/IPoolModule.sol";
import {IBundleModule} from "./module/bundle/IBundle.sol";
import {ITreasuryModule} from "./module/treasury/ITreasury.sol";

import {IRegistry, IRegistryLinked} from "../registry/IRegistryLinked.sol";
import {IServiceLinked} from "./IServiceLinked.sol";

import {IComponentOwnerService} from "./service/IComponentOwnerService.sol";
import {IProductService} from "./service/IProductService.sol";
import {IPoolService} from "./service/IPoolService.sol";


// solhint-disable-next-line no-empty-blocks
interface IInstance is
    IERC165,
    IVersionable,
    IRegisterable,
    IAccessModule,
    ILifecycleModule,
    IPolicyModule,
    IPoolModule,
    IBundleModule,
    IComponentModule,
    ITreasuryModule,
    IServiceLinked
{
    function getRegistry() external view override (IBundleModule, IComponentModule, IPolicyModule, IRegisterable) returns (IRegistry registry);

    function PRODUCT_OWNER_ROLE() external view override (IAccessModule, IComponentModule) returns (bytes32 role);    
    function ORACLE_OWNER_ROLE() external view override (IAccessModule, IComponentModule) returns (bytes32 role);    
    function POOL_OWNER_ROLE() external view override (IAccessModule, IComponentModule) returns (bytes32 role);    

    function hasRole(bytes32 role, address member) external view override (IAccessModule, IComponentModule) returns (bool hasRole);    

    function getComponentOwnerService() external view override (IServiceLinked, IComponentModule) returns(IComponentOwnerService);
    function getProductService() external view override (IServiceLinked, IBundleModule, IPolicyModule, IPoolModule) returns(IProductService);
    function getPoolService() external view override (IServiceLinked, IBundleModule, IPoolModule) returns(IPoolService);

    function getOwner() external view override (IOwnable, IAccessModule) returns(address owner);
}
