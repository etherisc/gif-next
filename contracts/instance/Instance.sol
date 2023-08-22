// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Registerable} from "../registry/Registry.sol";
import {IRegistry} from "../registry/IRegistry.sol";

import {IAccessModule, AccessModule} from "./access/Access.sol";
import {ComponentModule} from "./component/ComponentModule.sol";

import {IInstance} from "./IInstance.sol";

contract Instance is
    IInstance,
    Registerable,
    AccessModule,
    ComponentModule 
{

    constructor(
        address registry,
        address componentOwnerService
    )
        AccessModule()
        ComponentModule(componentOwnerService)
    { 
        setRegistry(registry);
    }

    // from registerable
    function register() external override returns(uint256 id) {
        require(address(_registry) != address(0), "ERROR:PRD-001:REGISTRY_ZERO");
        return _registry.register(address(this));
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
