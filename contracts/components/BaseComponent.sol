// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

//import {IRegisterable} from "../shared/IRegisterable.sol";
//import {Registerable} from "../shared/Registerable.sol";
import {IRegisterable_new} from "../shared/IRegisterable_new.sol";
import {Registerable_new} from "../shared/Registerable_new.sol";

//import {IRegistry} from "../registry/IRegistry.sol";
import {IRegistry_new} from "../registry/IRegistry_new.sol";
import {IInstance} from "../instance/IInstance.sol";

import {IInstance} from "../instance/IInstance.sol";
import {IComponent, IComponentModule} from "../instance/module/component/IComponent.sol";
import {IComponentOwnerService} from "../instance/service/IComponentOwnerService.sol";
import {IBaseComponent} from "./IBaseComponent.sol";
import {Fee, FeeLib} from "../types/Fee.sol";
import {NftId} from "../types/NftId.sol";
import {ObjectType, PRODUCT} from "../types/ObjectType.sol";

abstract contract BaseComponent is
    Registerable_new,
    IBaseComponent
{
    IComponentOwnerService internal _componentOwnerService;

    address internal _deployer;
    address internal _wallet;
    IERC20Metadata internal _token;
    IInstance internal _instance; // each component have parentNftId as instance
    bool internal _isRegistered;
    Fee internal _zeroFee;

    constructor(
        address registry,
        NftId instanceNftId,
        address token,
        ObjectType componentType 
    )
        //Registerable_new(registry, instanceNftId, componentType)
    {
        _initializeRegisterable(registry, instanceNftId, componentType);

        IRegistry_new.ObjectInfo memory instanceInfo = getRegistry().getObjectInfo(instanceNftId);
        _instance = IInstance(instanceInfo.objectAddress);
        require(
            _instance.supportsInterface(type(IInstance).interfaceId),
            ""
        );

        _componentOwnerService = _instance.getComponentOwnerService();
        _wallet = address(this);
        _token = IERC20Metadata(token);
        _isRegistered = false;
        _zeroFee = FeeLib.zeroFee();
    }

    // from registerable
    /*function register() public override(IRegisterable_new, Registerable_new) returns (NftId componentId) {

        IRegistry_new _registry = getRegistry();
        require(msg.sender == getOwner(), "");
        require(
            address(_registry) != address(0),
            "ERROR:COB-001:REGISTRY_ZERO"
        );
        require(
            _registry.isRegistered(address(_instance)),
            "ERROR:COB:INSTANCE_NOT_REGISTERED"
        );

        _isRegistered = true;
        return _componentOwnerService.register(this);
    }*/

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
