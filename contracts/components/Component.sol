// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegistry, IRegisterable, IRegistryLinked} from "../registry/IRegistry.sol";
import {Registerable} from "../registry/Registry.sol";
import {IInstance} from "../instance/IInstance.sol";

import {IInstanceLinked, IComponent, IComponentContract, IComponentModule, IComponentOwnerService} from "../instance/component/IComponent.sol";
import {NftId} from "../types/NftId.sol";

contract InstanceLinked is IInstanceLinked {
    IInstance internal _instance;

    constructor(address instance) {
        _instance = IInstance(instance);
    }

    // function setInstance(address instance) public override {
    //     require(address(_instance) == address(0), "ERROR:RGL-001:INSTANCE_ALREADY_SET");
    //     _instance = IInstance(instance);
    // }

    function getInstance() public view override returns (IInstance instance) {
        return _instance;
    }
}

abstract contract Component is
    Registerable,
    InstanceLinked,
    IComponentContract
{
    address private _deployer;

    constructor(
        address registry,
        address instance
    ) Registerable(registry) InstanceLinked(instance) {}

    // from registerable
    function register() public override returns (NftId componentId) {
        require(msg.sender == getInitialOwner(), "");
        require(
            address(_registry) != address(0),
            "ERROR:PRD-001:REGISTRY_ZERO"
        );
        require(
            _registry.isRegistered(address(_instance)),
            "ERROR:PRD-002:INSTANCE_NOT_REGISTERED"
        );

        IComponentOwnerService cos = _instance.getComponentOwnerService();
        componentId = cos.register(this);
    }

    // from registerable
    function getParentNftId() public view override returns (NftId) {
        return getInstance().getNftId();
    }
}
