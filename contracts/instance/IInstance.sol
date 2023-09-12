// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegisterable} from "../registry/IRegistry.sol";
import {IAccessModule} from "./access/IAccess.sol";
import {ILifecycleModule} from "./lifecycle/ILifecycle.sol";
import {IComponentModule} from "./component/IComponent.sol";
import {IProductModule} from "./product/IProductService.sol";
import {IPolicyModule} from "./policy/IPolicy.sol";
import {IPoolModule} from "./pool/IPoolModule.sol";
import {ITreasuryModule} from "./treasury/ITreasury.sol";

// solhint-disable-next-line no-empty-blocks
interface IInstance is
    IRegisterable,
    IAccessModule,
    ILifecycleModule,
    IPolicyModule,
    IPoolModule,
    IComponentModule,
    IProductModule,
    ITreasuryModule
{}
