// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { FoundryRandom } from "foundry-random/FoundryRandom.sol";

import {ObjectType, toObjectType, PRODUCT} from "../../contracts/types/ObjectType.sol";
import {NftId, toNftId} from "../../contracts/types/NftId.sol";
import {RiskId} from "../../contracts/types/RiskId.sol";
import {Fee, FeeLib} from "../../contracts/types/Fee.sol";

import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {IRegisterable} from "../../contracts/shared/IRegisterable.sol";
import {Registerable} from "../../contracts/shared/Registerable.sol";
import {IProductComponent} from "../../contracts/components/IProductComponent.sol";
import {BaseComponent} from "../../contracts/components/BaseComponent.sol";

contract ProductMock is BaseComponent {

    constructor(
        address registry,
        NftId instanceNftId,
        bool isInterceptor,
        address initialOwner
    )
        BaseComponent(registry, instanceNftId, address(0), PRODUCT(), isInterceptor, initialOwner)
    {
        _registerInterface(type(IProductComponent).interfaceId);  
    }
}

contract SelfOwnedProductMock is BaseComponent {

    constructor(
        address registry,
        NftId instanceNftId,
        bool isInterceptor
    )
        BaseComponent(registry, instanceNftId, address(0), PRODUCT(), isInterceptor, address(this))
    {
        _registerInterface(type(IProductComponent).interfaceId);  
    }
}

contract ProductMockWithRandomInvalidType is BaseComponent {

    ObjectType public _invalidType;

    constructor(
        address registry,
        NftId instanceNftId,
        bool isInterceptor,
        address initialOwner
    )
        BaseComponent(registry, instanceNftId, address(0), PRODUCT(), isInterceptor, initialOwner)
    {
        FoundryRandom rng = new FoundryRandom();

        ObjectType invalidType = toObjectType(rng.randomNumber(type(uint96).max));
        if(invalidType == PRODUCT()) {
            invalidType = toObjectType(invalidType.toInt() + 1);
        }

        _invalidType = invalidType;

        _registerInterface(type(IProductComponent).interfaceId);  
    }

    function getInitialInfo() 
        public 
        view 
        virtual override (IRegisterable, Registerable)
        returns (IRegistry.ObjectInfo memory, bytes memory) 
    {
        (
            IRegistry.ObjectInfo memory info,
            bytes memory data
        ) = super.getInitialInfo();

        info.objectType = _invalidType;

        return (info, data);
    }
}

contract ProductMockWithRandomInvalidAddress is BaseComponent {

    address public _invalidAddress;

    constructor(
        address registry,
        NftId instanceNftId,
        bool isInterceptor,
        address initialOwner
    )
        BaseComponent(registry, instanceNftId, address(0), PRODUCT(), isInterceptor, initialOwner)
    {
        FoundryRandom rng = new FoundryRandom();

        address invalidAddress = address(uint160(rng.randomNumber(type(uint160).max)));
        if(invalidAddress == address(this)) {
            invalidAddress = address(uint160(invalidAddress) + 1);
        }

        _invalidAddress = invalidAddress;

        _registerInterface(type(IProductComponent).interfaceId);  
    }

    function getInitialInfo() 
        public 
        view 
        virtual override (IRegisterable, Registerable)
        returns (IRegistry.ObjectInfo memory, bytes memory) 
    {
        (
            IRegistry.ObjectInfo memory info,
            bytes memory data
        ) = super.getInitialInfo();

        info.objectAddress = _invalidAddress;

        return (info, data);
    }
}


