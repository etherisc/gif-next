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
import {IInstanceLinkedComponent} from "../../../contracts/shared/IInstanceLinkedComponent.sol";
import {IRegistry} from "../../../contracts/registry/IRegistry.sol";
import {IRegistryService} from "../../../contracts/registry/IRegistryService.sol";
import {Registerable} from "../../../contracts/shared/Registerable.sol";
import {ProductMockWithoutInstanceCheck} from "../../mock/ProductMock.sol";
import {VersionPart, VersionPartLib} from "../../../contracts/type/Version.sol";
import {ContractLib} from "../../../contracts/shared/ContractLib.sol";

contract TestPoolRegistration is GifTest {

    address public myProductOwner = makeAddr("myProductOwner");
    address public myDistributionOwner = makeAddr("myDistributionOwner");
    address public myPoolOwner = makeAddr("myPoolOwner");

    SimpleProduct public myProduct1;
    SimpleProduct public myProduct2;

    NftId public myProduct1NftId; 
    NftId public myProduct2NftId; 


    function setUp() public override {
        super.setUp();

        myProduct1 = _deployProductDefault("MyProduct1");
        // TODO fix + re-enable
        // myProduct2 = _deployProductDefault("MyProduct2");

        vm.startPrank(instanceOwner);
        myProduct1NftId = instance.registerProduct(address(myProduct1), address(token));
        // TODO fix + re-enable
        // myProduct2NftId = instance.registerProduct(address(myProduct2));
        vm.stopPrank();
    }


    function test_poolRegisterHappyCase() public {
        // GIVEN
        SimplePool myPool = _deployPool("MyPool", myProduct1NftId, myPoolOwner);

        // WHEN
        vm.startPrank(myProductOwner);
        NftId myPoolNftId = myProduct1.registerComponent(address(myPool));
        vm.stopPrank();

        // THEN
        assertTrue(myPoolNftId.gtz(), "new pool nft id zero");
        assertEq(registry.ownerOf(myPoolNftId), address(myPoolOwner), "unexpected owner");
    }


    // attempt to register same pool a second time
    function test_poolRegisterAttemptRegisteringTwice() public {
        // GIVEN
        SimplePool myPool = _deployPool("MyPool", myProduct1NftId, myPoolOwner);

        vm.startPrank(myProductOwner);
        NftId myNftId = myProduct1.registerComponent(address(myPool));
        vm.stopPrank();

        // WHEN + THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                IRegistry.ErrorRegistryContractAlreadyRegistered.selector,
                address(myPool)));

        vm.startPrank(myProductOwner);
        NftId myNftId2nd = myProduct1.registerComponent(address(myPool));
        vm.stopPrank();
    }

    // attempt to register a second pool to a product that already has a pool
    function test_poolRegisterAttemptRegisteringSecond() public {
        // GIVEN
        SimplePool myPool = _deployPool("MyPool", myProduct1NftId, myPoolOwner);

        vm.startPrank(myProductOwner);
        NftId myNftId = myProduct1.registerComponent(address(myPool));
        vm.stopPrank();

        SimplePool myPool2 = _deployPool("MyPool2", myProduct1NftId, myPoolOwner);

        // WHEN + THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                IComponentService.ErrorProductServicePoolAlreadyRegistered.selector,
                myProduct1NftId,
                myNftId));

        vm.startPrank(myProductOwner);
        NftId myNftId2nd = myProduct1.registerComponent(address(myPool2));
        vm.stopPrank();
    }


    // check that non product owner fails to register a component
    function test_poolRegisterNotProductOwner() public {
        // // GIVEN
        // SimpleProduct myProduct = _deployProductDefault(".");

        // // WHEN + THEN
        // vm.expectRevert(
        //     abi.encodeWithSelector(
        //         INftOwnable.ErrorNftOwnableNotOwner.selector,
        //         myProductOwner));

        // vm.startPrank(myProductOwner);
        // NftId myNftId = instance.registerProduct(address(myProduct));
        // vm.stopPrank();
    }

    // check that non product fails to register a component
    function test_poolRegisterAttemptViaService() public {
        // GIVEN
        SimplePool myPool = _deployPool("MyPool", myProduct1NftId, myPoolOwner);

        // WHEN + THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                IComponentService.ErrorComponentServiceCallerNotProduct.selector,
                poolOwner));

        vm.startPrank(poolOwner);
        NftId myNftId = componentService.registerComponent(address(myPool));
        vm.stopPrank();
    }


    // check that pool registration fails for pool with a different release than product
    function test_poolRegisterAttemptDifferentRelease() public {
        // // GIVEN
        // SimpleProduct myProductV4 = new ProductMockV4(
        //     address(registry),
        //     instanceNftId, 
        //     new BasicProductAuthorization("MyProductV4"),
        //     myProductOwner,
        //     address(token),
        //     false, // is interceptor
        //     false, // has distribution
        //     0);

        // assertEq(myProductV4.getRelease().toInt(), 4, "unexpected product release");

        // // WHEN + THEN
        // vm.expectRevert(
        //     abi.encodeWithSelector(
        //         IComponentService.ErrorComponentServiceReleaseMismatch.selector,
        //         address(myProductV4),
        //         myProductV4.getRelease(),
        //         instance.getRelease()));

        // vm.startPrank(instanceOwner);
        // NftId myNftId = instance.registerProduct(address(myProductV4));
        // vm.stopPrank();
    }


    // check that a "random" contract may not be registerd with instance
    function test_poolRegisterAttemptRandomContract() public {
        // GIVEN

        // WHEN + THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                IRegistryService.ErrorRegistryServiceInterfaceNotSupported.selector,
                address(token),
                type(IInstanceLinkedComponent).interfaceId));

        vm.startPrank(myProductOwner);
        NftId myNftId = myProduct1.registerComponent(address(token));
        vm.stopPrank();
    }


    // check that pool cannot be directly registerd with instance
    // TODO re-enable/fix
    function test_poolRegisterAttemptPool() public {
        // GIVEN
        // SimpleProduct myProduct = _deployPool("MyPool", myProduct1NftId, myPoolOwner);

        // vm.startPrank(instanceOwner);
        // NftId myProdNftId = instance.registerProduct(address(myProduct));
        // vm.stopPrank();

        // SimplePool myPool = _deployPool("MyPool", myProdNftId, myPoolOwner);

        // // WHEN + THEN
        // vm.expectRevert(
        //     abi.encodeWithSelector(
        //         IComponentService.ErrorComponentServiceInvalidType.selector,
        //         address(myPool),
        //         PRODUCT(), 
        //         POOL()));

        // vm.startPrank(instanceOwner);
        // NftId myNftId = instance.registerProduct(address(myPool));
        // vm.stopPrank();
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
        return new SimpleProduct(
            address(registry),
            instanceNftId, 
            "SimpleProduct",
            _getSimpleProductInfo(),
            _getSimpleFeeInfo(),
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