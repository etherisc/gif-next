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
    function getRegistry() external view override (IRegistryLinked, IComponentModule) returns (IRegistry registry);

    function PRODUCT_OWNER_ROLE() external view override (IAccessModule, IComponentModule) returns (bytes32 role);    
    function ORACLE_OWNER_ROLE() external view override (IAccessModule, IComponentModule) returns (bytes32 role);    
    function POOL_OWNER_ROLE() external view override (IAccessModule, IComponentModule) returns (bytes32 role);    

    function hasRole(bytes32 role, address member) external view override (IAccessModule, IComponentModule) returns (bool hasRole);    

    function senderIsComponentOwnerService() external view override (IComponentModule, IServiceLinked) returns(bool isService);
    function senderIsProductService() external view override (IBundleModule, IPoolModule, IPolicyModule, IServiceLinked) returns(bool isService);
    function senderIsPoolService() external view override (IBundleModule, IPoolModule, IServiceLinked) returns(bool isService);

    function requireSenderIsOwner() external view override (IOwnable, IAccessModule) returns(bool isService);
}
