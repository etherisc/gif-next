// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegisterable} from "../registry/IRegistry.sol";
import {IAccessModule} from "./module/access/IAccess.sol";
import {ILifecycleModule} from "./lifecycle/ILifecycle.sol";
import {IComponentModule} from "./component/IComponent.sol";
import {IProductModule} from "./product/IProductModule.sol";
import {IPolicyModule} from "./policy/IPolicy.sol";
import {IPoolModule} from "./module/pool/IPoolModule.sol";
import {IBundleModule} from "./module/bundle/IBundle.sol";
import {ITreasuryModule} from "./treasury/ITreasury.sol";

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
