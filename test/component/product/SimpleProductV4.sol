// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {NftId} from "../../../contracts/type/NftId.sol";
import {SimpleProduct} from "../../../contracts/examples/unpermissioned/SimpleProduct.sol";
import {IAuthorization} from "../../../contracts/authorization/IAuthorization.sol";
import {IComponents} from "../../../contracts/instance/module/IComponents.sol";
import {Registerable} from "../../../contracts/shared/Registerable.sol";
import {IRelease} from "../../../contracts/registry/IRelease.sol";
import {VersionPart, VersionPartLib} from "../../../contracts/type/Version.sol";


contract SimpleProductV4 is SimpleProduct {

    constructor(
        address registry,
        NftId instanceNftId,
        IComponents.ProductInfo memory productInfo,
        IComponents.FeeInfo memory feeInfo,
        IAuthorization authorization,
        address initialOwner
    )
        SimpleProduct(
            registry,
            instanceNftId,
            "SimpleProductV4",
            productInfo,
            feeInfo,
            authorization,
            initialOwner
        )
    { }

    function getRelease() public override(IRelease, Registerable) pure returns (VersionPart release) {
        return VersionPartLib.toVersionPart(4);
    }
}