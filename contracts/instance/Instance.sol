// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Registerable} from "../registry/Registry.sol";
import {IRegistry} from "../registry/IRegistry.sol";

import {IAccessModule, AccessModule} from "./access/Access.sol";
import {LifecycleModule} from "./lifecycle/LifecycleModule.sol";
import {ComponentModule} from "./component/ComponentModule.sol";
import {ProductModule} from "./product/ProductModule.sol";
import {PolicyModule} from "./policy/PolicyModule.sol";
import {PoolModule} from "./pool/PoolModule.sol";
import {BundleModule} from "./bundle/BundleModule.sol";
import {TreasuryModule} from "./treasury/TreasuryModule.sol";

import {IInstance} from "./IInstance.sol";
import {ObjectType, INSTANCE} from "../types/ObjectType.sol";
import {NftId, toNftId} from "../types/NftId.sol";

contract Instance is
    Registerable,
    AccessModule,
    LifecycleModule,
    ComponentModule,
    PolicyModule,
    PoolModule,
    ProductModule,
    BundleModule,
    TreasuryModule,
    IInstance
{
    constructor(
        address registry,
        address componentOwnerService,
        address productService
    )
        Registerable(registry)
        AccessModule()
        ComponentModule(componentOwnerService)
        PolicyModule(productService)
        ProductModule(productService)
        PoolModule(productService)
    // solhint-disable-next-line no-empty-blocks
    {

    }

    // from registerable
    function register() external override returns (NftId nftId) {
        require(
            address(_registry) != address(0),
            "ERROR:PRD-001:REGISTRY_ZERO"
        );
        return _registry.register(address(this));
    }

    // from registerable
    function getParentNftId() public pure override returns (NftId) {
        // TODO  add self registry and exchange 0 for_registry.getNftId();
        // define parent tree for all registerables
        // eg 0 <- chain(mainnet) <- global registry <- chain registry <- instance <- component <- policy/bundle
        return toNftId(0);
    }

    // from registerable
    function getType() external pure override returns (ObjectType objectType) {
        return INSTANCE();
    }

    // from registerable
    function getData() external pure override returns (bytes memory data) {
        return bytes(abi.encode(0));
    }
}
