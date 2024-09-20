// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManagerCloneable} from "../../contracts/authorization/AccessManagerCloneable.sol";
import {NftId} from "../../contracts/type/NftId.sol";
import {SimpleProduct} from "../../contracts/examples/unpermissioned/SimpleProduct.sol";
import {IAuthorization} from "../../contracts/authorization/IAuthorization.sol";
import {IComponents} from "../../contracts/instance/module/IComponents.sol";
import {IInstanceLinkedComponent} from "../../contracts/shared/IInstanceLinkedComponent.sol";
import {ObjectType} from "../../contracts/type/ObjectType.sol";
import {SimpleProduct} from "../../contracts/examples/unpermissioned/SimpleProduct.sol";
import {Version, VersionLib} from "../../contracts/type/Version.sol";
import {IVersionable} from "../../contracts/shared/IVersionable.sol";
import {Versionable} from "../../contracts/shared/Versionable.sol";



contract ProductMockWithoutInstanceCheck is SimpleProduct {
    constructor(
        address registry,
        NftId instanceNftId,
        string memory name,
        IComponents.ProductInfo memory productInfo,
        IComponents.FeeInfo memory feeInfo,
        IAuthorization authorization,
        address initialOwner
    )
        SimpleProduct(
            registry,
            instanceNftId,
            name,
            productInfo,
            feeInfo,
            authorization,
            initialOwner
        )
    { }

    // instance is not checked nor set
    function __InstanceLinkedComponent_init(
        address registry,
        NftId parentNftId,
        string memory name,
        ObjectType componentType,
        IAuthorization authorization,
        bool isInterceptor,
        address initialOwner
    )
        internal 
        virtual override
        onlyInitializing()
    {
        // need v4, for some reason ProductMockV4 have V3...
        AccessManagerCloneable accessManager = new AccessManagerCloneable();
        accessManager.initialize(address(this), getRelease());

        __Component_init(
            address(accessManager),
            registry, 
            parentNftId, 
            name, 
            componentType,
            isInterceptor, 
            initialOwner, 
            ""); // registry data

        // set instance linked specific parameters
        //InstanceLinkedComponentStorage storage $ = _getInstanceLinkedComponentStorage();
        //$._instance = instance;
        //$._initialAuthorization = authorization;

        // register interfaces
        _registerInterface(type(IInstanceLinkedComponent).interfaceId);
    }
}

contract ProductMockV4 is ProductMockWithoutInstanceCheck {

    constructor(
        address registry,
        NftId instanceNftId,
        IComponents.ProductInfo memory productInfo,
        IComponents.FeeInfo memory feeInfo,
        IAuthorization authorization,
        address initialOwner
    )
        ProductMockWithoutInstanceCheck(
            registry,
            instanceNftId,
            "ProductWithoutInstanceCheckV4",
            productInfo,
            feeInfo,
            authorization,
            initialOwner
        )
    { }

    // for some reason when product is instantiated  "accessManager.initialize(address(this));"
    // initializes access manager to release 3...
    function getVersion() public override(IVersionable, Versionable) pure returns (Version version) {
        return VersionLib.toVersion(4, 0, 0);
    }
}