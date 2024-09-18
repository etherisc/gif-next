// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {BasicPoolAuthorization} from "../../../contracts/pool/BasicPoolAuthorization.sol";
import {BasicProductAuthorization} from "../../../contracts/product/BasicProductAuthorization.sol";
import {GifTest} from "../../base/GifTest.sol";
import {NftId} from "../../../contracts/type/NftId.sol";
import {SimpleProduct} from "../../../contracts/examples/unpermissioned/SimpleProduct.sol";
import {SimplePool} from "../../../contracts/examples/unpermissioned/SimplePool.sol";
import {IComponents} from "../../../contracts/instance/module/IComponents.sol";
import {IComponentService} from "../../../contracts/shared/IComponentService.sol";
import {IRegistry} from "../../../contracts/registry/IRegistry.sol";
import {IRegistryService} from "../../../contracts/registry/IRegistryService.sol";
import {INftOwnable} from "../../../contracts/shared/INftOwnable.sol";
import {PRODUCT, POOL} from "../../../contracts/type/ObjectType.sol";
import {ProductMockV4} from "../../mock/ProductMock.sol";
import {Usdc} from "../../mock/Usdc.sol";


// solhint-disable func-name-mixedcase
contract TestProductRegistration is GifTest {

    address public myProductOwner = makeAddr("myProductOwner");
    address public myDistributionOwner = makeAddr("myDistributionOwner");
    address public myPoolOwner = makeAddr("myPoolOwner");


    function test_productRegisterHappyCase() public {
        // GIVEN
        SimpleProduct myProduct = _deployProductDefault("MyProduct");

        // WHEN
        vm.startPrank(instanceOwner);
        NftId myNftId = instance.registerProduct(address(myProduct), address(token));
        vm.stopPrank();

        // THEN
        assertTrue(myNftId.gtz(), "new product nft id zero");
        assertEq(registry.ownerOf(myNftId), address(myProductOwner), "unexpected owner");
    }


    function test_productRegisterTwoProductsHappyCase() public {
        // GIVEN
        SimpleProduct myProduct1 = _deployProductDefault("MyProduct1");
        SimpleProduct myProduct2 = _deployProductDefault("MyProduct2");

        // WHEN
        vm.startPrank(instanceOwner);
        NftId myNftId1 = instance.registerProduct(address(myProduct1), address(token));
        NftId myNftId2 = instance.registerProduct(address(myProduct2), address(token));
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
        instance.registerProduct(address(myProduct), address(token));
        vm.stopPrank();

        // WHEN + THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                IRegistry.ErrorRegistryContractAlreadyRegistered.selector,
                address(myProduct)));

        vm.startPrank(instanceOwner);
        instance.registerProduct(address(myProduct), address(token));
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
        instance.registerProduct(address(myProduct), address(token));
        vm.stopPrank();
    }


    function test_productRegisterAttemptViaService() public {
        // GIVEN
        SimpleProduct myProduct = _deployProductDefault("MyProduct");

        // WHEN + THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                IComponentService.ErrorComponentServiceCallerNotInstance.selector,
                address(instanceOwner)));

        vm.startPrank(instanceOwner);
        componentService.registerProduct(address(myProduct), address(token));
        vm.stopPrank();
    }

    // TODO flawors of different release
    //       object |  parent  |  service
    //         a          a         b
    //         a          b         a
    //         a          b         b
    //         a          b         c       
    function test_productRegisterAttemptDifferentRelease() public {
        // GIVEN
        ProductMockV4 myProductV4 = new ProductMockV4(
            address(registry),
            instanceNftId, 
            _getSimpleProductInfo(),
            _getSimpleFeeInfo(),
            new BasicProductAuthorization("MyProductV4"),
            myProductOwner);

        assertEq(myProductV4.getRelease().toInt(), 4, "unexpected product release");

        // WHEN + THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                IRegistry.ErrorRegistryReleaseMismatch.selector,
                myProductV4.getRelease(),
                instance.getRelease(),
                registryService.getRelease()));

        vm.startPrank(instanceOwner);
        instance.registerProduct(address(myProductV4), address(token));
        vm.stopPrank();
    }


    // check that a "random" contract may not be registerd with instance
    function test_productRegisterAttemptRandomContract() public {
        // GIVEN

        // WHEN + THEN
        vm.expectRevert();

        vm.startPrank(instanceOwner);
        instance.registerProduct(address(token), address(token));
        vm.stopPrank();
    }


    // check that pool cannot be directly registerd with instance
    function test_productRegisterAttemptPool() public {
        // GIVEN
        SimpleProduct myProduct = _deployProductDefault("MyProduct");

        vm.startPrank(instanceOwner);
        NftId myProdNftId = instance.registerProduct(address(myProduct), address(token));
        vm.stopPrank();

        SimplePool myPool = _deployPool("MyPool", myProdNftId, myPoolOwner);

        // WHEN + THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                IRegistryService.ErrorRegistryServiceRegisterableTypeInvalid.selector,
                address(myPool),
                PRODUCT(),
                POOL()));

        vm.startPrank(instanceOwner);
        instance.registerProduct(address(myPool), address(token));
        vm.stopPrank();
    }

    function test_productRegister_tokenNotWhitelisted() public {
        // GIVEN
        SimpleProduct myProduct = _deployProductDefault("MyProduct");
        Usdc notWhitelistedToken = new Usdc();

        vm.startPrank(instanceOwner);

        // THEN
        vm.expectRevert(abi.encodeWithSelector(
            IComponentService.ErrorComponentServiceTokenInvalid.selector, 
            notWhitelistedToken));

        // WHEN
        instance.registerProduct(address(myProduct), address(notWhitelistedToken));
    }

    function test_productRegister_tokenNotWhitelistedCheckDisabled() public {
        // GIVEN - a new instance with token registry disabled
        vm.startPrank(instanceOwner);

        (instance, instanceNftId) = instanceService.createInstance(true);

        SimpleProduct myProduct = _deployProductDefault("MyProduct");
        Usdc notWhitelistedToken = new Usdc();

        // WHEN + THEN (no revert)
        instance.registerProduct(address(myProduct), address(notWhitelistedToken));
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
            _getDefaultSimplePoolInfo(),
            new BasicPoolAuthorization(name),
            owner);
    }
}


