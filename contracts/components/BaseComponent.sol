// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin5/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Registerable} from "../shared/Registerable.sol";

import {IRegistry} from "../registry/IRegistry.sol";
import {IInstance} from "../instance/IInstance.sol";

import {IInstance} from "../instance/IInstance.sol";
import {IComponent, IComponentModule} from "../instance/module/component/IComponent.sol";
import {IComponentOwnerService} from "../instance/service/IComponentOwnerService.sol";
import {IBaseComponent} from "./IBaseComponent.sol";
import {Fee, FeeLib} from "../types/Fee.sol";
import {NftId} from "../types/NftId.sol";
import {ObjectType, PRODUCT} from "../types/ObjectType.sol";

abstract contract BaseComponent is
    Registerable,
    IBaseComponent
{
    IComponentOwnerService internal _componentOwnerService;

    address internal _deployer;
    address internal _wallet;
    IERC20Metadata internal _token;
    IInstance internal _instance;

    constructor(
        address registry,
        NftId instanceNftId,
        address token,
        ObjectType componentType,
        address initialOwner
    )
    {
        _initializeRegisterable(registry, instanceNftId, componentType, initialOwner);

        IRegistry.ObjectInfo memory instanceInfo = getRegistry().getObjectInfo(instanceNftId);
        _instance = IInstance(instanceInfo.objectAddress);
        require(
            _instance.supportsInterface(type(IInstance).interfaceId),
            ""
        );

        _componentOwnerService = _instance.getComponentOwnerService();
        _wallet = address(this);
        _token = IERC20Metadata(token);
    }

    // from component contract
    function lock() external onlyOwner override {
        _componentOwnerService.lock(this);
    }

    function unlock() external onlyOwner override {
        _componentOwnerService.unlock(this);
    }

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

    function getInstance() external view override returns (IInstance instance) {
        return _instance;
    }
}
