// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

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
    address private _wallet;
    IERC20Metadata private _token;

    constructor(
        address registry,
        address instance,
        address token
    ) Registerable(registry) InstanceLinked(instance) {
        _wallet = address(this);
        _token = IERC20Metadata(token);
    }

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

    // from component contract
    function getWallet()
        external
        view
        override
        returns (address walletAddress)
    {
        return _wallet;
    }

    function getToken() external view override returns (IERC20Metadata token) {
        return _token;
    }
}
