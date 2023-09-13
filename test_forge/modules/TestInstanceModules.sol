// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {TestInstanceBase} from "./TestInstanceBase.sol";

import {LifecycleModule} from "../../contracts/instance/lifecycle/LifecycleModule.sol";
import {ComponentModule} from "../../contracts/instance/component/ComponentModule.sol";
import {ProductModule} from "../../contracts/instance/product/ProductModule.sol";
import {PoolModule} from "../../contracts/instance/pool/PoolModule.sol";
import {PolicyModule} from "../../contracts/instance/policy/PolicyModule.sol";
import {BundleModule} from "../../contracts/instance/bundle/BundleModule.sol";
import {TreasuryModule} from "../../contracts/instance//treasury/TreasuryModule.sol";

contract TestInstanceModuleBundle  is
    TestInstanceBase,
    BundleModule
{
    constructor(address registry)
        TestInstanceBase(registry)
        BundleModule()
    // solhint-disable-next-line no-empty-blocks
    {

    }
}

contract TestInstanceModuleComponent  is
    TestInstanceBase,
    ComponentModule
{
    constructor(address registry, address componentOwnerService)
        TestInstanceBase(registry)
        ComponentModule(componentOwnerService)
    // solhint-disable-next-line no-empty-blocks
    {

    }
}

contract TestInstanceModulePolicy  is
    TestInstanceBase,
    PolicyModule
{
    constructor(address registry, address productService)
        TestInstanceBase(registry)
        PolicyModule(productService)
    // solhint-disable-next-line no-empty-blocks
    {

    }
}

contract TestInstanceModuleProduct  is
    TestInstanceBase,
    ProductModule
{
    constructor(address registry, address productService)
        TestInstanceBase(registry)
        ProductModule(productService)
    // solhint-disable-next-line no-empty-blocks
    {

    }
}

contract TestInstanceModulePool  is
    TestInstanceBase,
    PoolModule
{
    constructor(address registry, address productService)
        TestInstanceBase(registry)
        PoolModule(productService)
    // solhint-disable-next-line no-empty-blocks
    {

    }
}

contract TestInstanceModuleTreasury  is
    TestInstanceBase,
    TreasuryModule
{
    constructor(address registry)
        TestInstanceBase(registry)
        TreasuryModule()
    // solhint-disable-next-line no-empty-blocks
    {

    }
}
