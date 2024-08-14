// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Vm, console} from "../../../lib/forge-std/src/Test.sol";

import {BasicDistributionAuthorization} from "../../../contracts/distribution/BasicDistributionAuthorization.sol";
import {BasicOracleAuthorization} from "../../../contracts/oracle/BasicOracleAuthorization.sol";
import {BasicPoolAuthorization} from "../../../contracts/pool/BasicPoolAuthorization.sol";
import {BasicProductAuthorization} from "../../../contracts/product/BasicProductAuthorization.sol";
import {GifTest} from "../../base/GifTest.sol";
import {Amount, AmountLib} from "../../../contracts/type/Amount.sol";
import {NftId, NftIdLib} from "../../../contracts/type/NftId.sol";
import {ClaimId} from "../../../contracts/type/ClaimId.sol";
import {SimpleProduct} from "../../../contracts/examples/unpermissioned/SimpleProduct.sol";
import {SimplePool} from "../../../contracts/examples/unpermissioned/SimplePool.sol";
import {IAuthorization} from "../../../contracts/authorization/IAuthorization.sol";
import {IComponents} from "../../../contracts/instance/module/IComponents.sol";
import {IComponentService} from "../../../contracts/shared/IComponentService.sol";
import {Registerable} from "../../../contracts/shared/Registerable.sol";
import {IRegisterable} from "../../../contracts/shared/IRegisterable.sol";
import {IInstanceLinkedComponent} from "../../../contracts/shared/IInstanceLinkedComponent.sol";
import {ILifecycle} from "../../../contracts/shared/ILifecycle.sol";
import {INftOwnable} from "../../../contracts/shared/INftOwnable.sol";
import {IPolicy} from "../../../contracts/instance/module/IPolicy.sol";
import {IBundle} from "../../../contracts/instance/module/IBundle.sol";
import {Fee, FeeLib} from "../../../contracts/type/Fee.sol";
import {UFixedLib} from "../../../contracts/type/UFixed.sol";
import {VersionPart, VersionPartLib} from "../../../contracts/type/Version.sol";
import {Seconds, SecondsLib} from "../../../contracts/type/Seconds.sol";
import {Timestamp, TimestampLib, zeroTimestamp} from "../../../contracts/type/Timestamp.sol";
import {IPolicyService} from "../../../contracts/product/IPolicyService.sol";
import {IRisk} from "../../../contracts/instance/module/IRisk.sol";
import {PayoutId, PayoutIdLib} from "../../../contracts/type/PayoutId.sol";
import {POLICY, PRODUCT, POOL} from "../../../contracts/type/ObjectType.sol";
import {RiskId, RiskIdLib, eqRiskId} from "../../../contracts/type/RiskId.sol";
import {ReferralLib} from "../../../contracts/type/Referral.sol";
import {SUBMITTED, ACTIVE, COLLATERALIZED, CONFIRMED, DECLINED, CLOSED} from "../../../contracts/type/StateId.sol";
import {StateId} from "../../../contracts/type/StateId.sol";

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
        myProduct1NftId = instance.registerProduct(address(myProduct1));
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
                IComponentService.ErrorComponentServiceAlreadyRegistered.selector,
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


    // check that non product owner fails to register a product
    function test_poolRegisterAttemptViaService() public {
        // GIVEN
        SimplePool myPool = _deployPool("MyPool", myProduct1NftId, myPoolOwner);

        // WHEN + THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                IComponentService.ErrorComponentServiceSenderNotRegistered.selector,
                poolOwner));

        vm.startPrank(poolOwner);
        NftId myNftId = componentService.registerComponent(address(myPool));
        vm.stopPrank();
    }


    // check that pool registration fails for pool with a different release than product
    function test_poolRegisterAttemptDifferentRelease() public {
        // // GIVEN
        // SimpleProduct myProductV4 = new SimpleProductV4(
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
                IComponentService.ErrorComponentServiceNotInstanceLinkedComponent.selector,
                address(token)));

        vm.startPrank(myProductOwner);
        NftId myNftId = myProduct1.registerComponent(address(token));
        vm.stopPrank();
    }


    // check that pool cannot be directly registerd with instance
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

    // TODO cleanup
    // error ErrorComponentServiceNotComponent(address component);
    // error ErrorComponentServiceReleaseMismatch(address component, VersionPart componentRelease, VersionPart parentRelease);
    // error ErrorComponentServiceSenderNotComponentParent(NftId senderNftId, NftId compnentParentNftId);
    // error ErrorComponentServiceParentNotInstance(NftId nftId, ObjectType objectType);
    // error ErrorComponentServiceParentNotProduct(NftId nftId, ObjectType objectType);


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
            address(token),
            _getSimpleProductInfo(),
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
        IAuthorization authorization,
        address initialOwner
    )
        SimpleProduct(
            registry,
            instanceNftId,
            "SimpleProductV4",
            token,
            productInfo,
            authorization,
            initialOwner
        )
    { }

    function getRelease() public override(IRegisterable, Registerable) pure returns (VersionPart release) {
        return VersionPartLib.toVersionPart(4);
    }
}