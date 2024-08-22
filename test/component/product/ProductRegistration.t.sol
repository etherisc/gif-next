// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Vm, console} from "../../../lib/forge-std/src/Test.sol";

import {BasicPoolAuthorization} from "../../../contracts/pool/BasicPoolAuthorization.sol";
import {BasicProductAuthorization} from "../../../contracts/product/BasicProductAuthorization.sol";
import {GifTest} from "../../base/GifTest.sol";
import {NftId} from "../../../contracts/type/NftId.sol";
import {SimpleProduct} from "../../../contracts/examples/unpermissioned/SimpleProduct.sol";
import {SimplePool} from "../../../contracts/examples/unpermissioned/SimplePool.sol";
import {IAuthorization} from "../../../contracts/authorization/IAuthorization.sol";
import {IComponents} from "../../../contracts/instance/module/IComponents.sol";
import {IComponentService} from "../../../contracts/shared/IComponentService.sol";
import {Registerable} from "../../../contracts/shared/Registerable.sol";
import {IRelease} from "../../../contracts/registry/IRelease.sol";
import {INftOwnable} from "../../../contracts/shared/INftOwnable.sol";
import {VersionPart, VersionPartLib} from "../../../contracts/type/Version.sol";

contract TestProductRegistration is GifTest {

    address public myProductOwner = makeAddr("myProductOwner");
    address public myDistributionOwner = makeAddr("myDistributionOwner");
    address public myPoolOwner = makeAddr("myPoolOwner");


    function test_productRegisterHappyCase() public {
        // GIVEN
        SimpleProduct myProduct = _deployProductDefault("MyProduct");

        // WHEN
        vm.startPrank(instanceOwner);
        NftId myNftId = instance.registerProduct(address(myProduct));
        vm.stopPrank();

        // THEN
        assertTrue(myNftId.gtz(), "new product nft id zero");
        assertEq(registry.ownerOf(myNftId), address(myProductOwner), "unexpected owner");
    }


    // TODO fix + re-enable
    function skip_test_productRegisterTwoProductsHappyCase() public {
        // GIVEN
        SimpleProduct myProduct1 = _deployProductDefault("MyProduct1");
        SimpleProduct myProduct2 = _deployProductDefault("MyProduct2");

        // WHEN
        vm.startPrank(instanceOwner);
        NftId myNftId1 = instance.registerProduct(address(myProduct1));
        NftId myNftId2 = instance.registerProduct(address(myProduct2));
        vm.stopPrank();

        // THEN
        assertTrue(myNftId1.gtz(), "new product nft id 1 zero");
        assertTrue(myNftId2.gtz(), "new product nft id 2 zero");
        assertTrue(myNftId1 != myNftId2, "product nft ids not unique");
        assertEq(registry.ownerOf(myNftId1), address(myProductOwner), "unexpected owner for prod 1");
        assertEq(registry.ownerOf(myNftId2), address(myProductOwner), "unexpected owner for prod 2");
    }


    function test_productRegisterAttemptRegisteringTwice() public {
        // GIVEN
        SimpleProduct myProduct = _deployProductDefault("MyProduct");

        vm.startPrank(instanceOwner);
        NftId myNftId = instance.registerProduct(address(myProduct));
        vm.stopPrank();

        // WHEN + THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                IComponentService.ErrorComponentServiceComponentAlreadyRegistered.selector,
                address(myProduct)));

        vm.startPrank(instanceOwner);
        NftId myNftId2nd = instance.registerProduct(address(myProduct));
        vm.stopPrank();
    }


    // check that non instance owner fails to register a product
    function test_productRegisterNotInstanceOwner() public {
        // GIVEN
        SimpleProduct myProduct = _deployProductDefault("MyProduct");

        // WHEN + THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                INftOwnable.ErrorNftOwnableNotOwner.selector,
                myProductOwner));

        vm.startPrank(myProductOwner);
        NftId myNftId = instance.registerProduct(address(myProduct));
        vm.stopPrank();
    }

    // FIXME: when proper instance verification is added to registerProduct()
    // check that non instance fails to register a product
    /*function test_productRegisterAttemptViaService() public {
        // GIVEN
        SimpleProduct myProduct = _deployProductDefault("MyProduct");

        // WHEN + THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessManaged.AccessManagedUnauthorized.selector,
                address(instanceOwner)));

        vm.startPrank(instanceOwner);
        componentService.registerProduct(address(myProduct));
        vm.stopPrank();
    }*/


    // check that product registration fails for product with a different release than instance
    function test_productRegisterAttemptDifferentRelease() public {
        // GIVEN
        SimpleProduct myProductV4 = new SimpleProductV4(
            address(registry),
            instanceNftId, 
            address(token),
            _getSimpleProductInfo(),
            _getSimpleFeeInfo(),
            new BasicProductAuthorization("MyProductV4"),
            myProductOwner);

        assertEq(myProductV4.getRelease().toInt(), 4, "unexpected product release");

        // WHEN + THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                IComponentService.ErrorComponentServiceComponentReleaseMismatch.selector,
                address(myProductV4),
                instance.getRelease(),
                myProductV4.getRelease()));

        vm.startPrank(instanceOwner);
        NftId myNftId = instance.registerProduct(address(myProductV4));
        vm.stopPrank();
    }


    // check that a "random" contract may not be registerd with instance
    function test_productRegisterAttemptRandomContract() public {
        // GIVEN

        // WHEN + THEN
        vm.expectRevert();

        vm.startPrank(instanceOwner);
        NftId myNftId = instance.registerProduct(address(token));
        vm.stopPrank();
    }


    // check that pool cannot be directly registerd with instance
    function test_productRegisterAttemptPool() public {
        // GIVEN
        SimpleProduct myProduct = _deployProductDefault("MyProduct");

        vm.startPrank(instanceOwner);
        NftId myProdNftId = instance.registerProduct(address(myProduct));
        vm.stopPrank();

        SimplePool myPool = _deployPool("MyPool", myProdNftId, myPoolOwner);

        // WHEN + THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                IComponentService.ErrorComponentServiceComponentParentInvalid.selector,
                address(myPool),
                instanceNftId,
                myProdNftId));

        vm.startPrank(instanceOwner);
        instance.registerProduct(address(myPool));
        vm.stopPrank();
    }

    function _deployProductDefault(string memory name) internal returns(SimpleProduct) {
        return _deployProduct(name, myProductOwner, false, 0);
    }

    // deploys a new simple product.
    function _deployProduct(
        string memory name, 
        address owner,
        bool hasDistribution,
        uint8 oracleCount
    )
        internal
        returns(SimpleProduct)
    {
        IComponents.ProductInfo memory productInfo = _getSimpleProductInfo();
        productInfo.hasDistribution = hasDistribution;
        productInfo.expectedNumberOfOracles = oracleCount;
        IComponents.FeeInfo memory feeInfo = _getSimpleFeeInfo();

        return new SimpleProduct(
            address(registry),
            instanceNftId, 
            name,
            address(token),
            productInfo,
            feeInfo,
            new BasicProductAuthorization(name),
            owner);
    }

    function _deployPool(
        string memory name, 
        NftId productNftId,
        address owner
    )
        internal
        returns(SimplePool)
    {
        return new SimplePool(
            address(registry),
            productNftId,
            address(token),
            _getDefaultSimplePoolInfo(),
            new BasicPoolAuthorization(name),
            owner);
    }
}




contract SimpleProductV4 is SimpleProduct {

    constructor(
        address registry,
        NftId instanceNftId,
        address token,
        IComponents.ProductInfo memory productInfo,
        IComponents.FeeInfo memory feeInfo,
        IAuthorization authorization,
        address initialOwner
    )
        SimpleProduct(
            registry,
            instanceNftId,
            "SimpleProductV4",
            token,
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
