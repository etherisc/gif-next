// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegisterable} from "../registry/IRegistry.sol";
import {IAccessModule} from "./module/access/IAccess.sol";
import {ILifecycleModule} from "./module/lifecycle/ILifecycle.sol";
import {IComponentModule} from "./module/component/IComponent.sol";
import {IProductModule} from "./module/product/IProductModule.sol";
import {IPolicyModule} from "./module/policy/IPolicy.sol";
import {IPoolModule} from "./module/pool/IPoolModule.sol";
import {IBundleModule} from "./module/bundle/IBundle.sol";
import {ITreasuryModule} from "./module/treasury/ITreasury.sol";

import {IServiceLinked} from "./IServiceLinked.sol";

// solhint-disable-next-line no-empty-blocks
interface IInstance is
    IRegisterable,
    IAccessModule,
    ILifecycleModule,
    IPolicyModule,
    IPoolModule,
    IBundleModule,
    IComponentModule,
    IProductModule,
    ITreasuryModule
{

}
