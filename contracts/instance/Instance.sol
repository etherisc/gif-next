// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Registerable} from "../registry/Registry.sol";
import {IRegistry} from "../registry/IRegistry.sol";

import {IAccessModule, AccessModule} from "./access/Access.sol";
import {ComponentModule} from "./component/ComponentModule.sol";
import {ProductModule} from "./product/ProductService.sol";
import {PolicyModule} from "./policy/PolicyModule.sol";
import {PoolModule} from "./pool/PoolModule.sol";

import {IInstance} from "./IInstance.sol";
import {NftId, toNftId} from "../types/NftId.sol";

contract Instance is
    Registerable,
    AccessModule,
    ComponentModule, 
    PolicyModule, 
    PoolModule,
    ProductModule, 
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
    { }

    // from registerable
    function register() external override returns(NftId nftId) {
        require(address(_registry) != address(0), "ERROR:PRD-001:REGISTRY_ZERO");
        return _registry.register(address(this));
    }

    // from registerable
    function getParentNftId() public view override returns(NftId) {
        // TODO  add self registry and exchange 0 for_registry.getNftId();
        // define parent tree for all registerables
        // eg 0 <- chain(mainnet) <- global registry <- chain registry <- instance <- component <- policy/bundle 
        return toNftId(0);
    }

    // from registerable
    function getType() external view override returns(uint256 objectType) {
        return _registry.INSTANCE();
    }

    // from registerable
    function getData() external view override returns(bytes memory data) {
        return bytes(abi.encode(0));
    }


}
