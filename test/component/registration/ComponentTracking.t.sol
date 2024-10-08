// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {BasicDistributionAuthorization} from "../../../contracts/distribution/BasicDistributionAuthorization.sol";
import {BasicOracleAuthorization} from "../../../contracts/oracle/BasicOracleAuthorization.sol";
import {BasicPoolAuthorization} from "../../../contracts/pool/BasicPoolAuthorization.sol";
import {BasicProductAuthorization} from "../../../contracts/product/BasicProductAuthorization.sol";
import {GifTest} from "../../base/GifTest.sol";
import {NftId} from "../../../contracts/type/NftId.sol";
import {SimpleProduct} from "../../../contracts/examples/unpermissioned/SimpleProduct.sol";
import {SimpleDistribution} from "../../../contracts/examples/unpermissioned/SimpleDistribution.sol";
import {SimpleOracle} from "../../../contracts/examples/unpermissioned/SimpleOracle.sol";
import {SimplePool} from "../../../contracts/examples/unpermissioned/SimplePool.sol";
import {IComponent} from "../../../contracts/shared/IComponent.sol";
import {IComponents} from "../../../contracts/instance/module/IComponents.sol";
import {IComponentService} from "../../../contracts/shared/IComponentService.sol";


// solhint-disable func-name-mixedcase
contract ComponentTrackingTest is GifTest {


    function test_componentTrackingSimpleProductOnly() public {
        // GIVEN
        assertEq(instanceReader.products(), 0, "unexpected products count (before)");

        // WHEN
        SimpleProduct myProduct = _deployProduct("MyProduct", instanceOwner, true, 1);
        vm.startPrank(instanceOwner);
        NftId myProductNftId = instance.registerProduct(address(myProduct), address(token));
        vm.stopPrank();

        // THEN
        assertEq(instanceReader.products(), 1, "unexpected products count (after)");
        assertEq(instanceReader.getProduct(0).toInt(), myProductNftId.toInt(), "unexpected product nft id (1)");
    }


    function test_componentTrackingSimpleProductComplete() public {
        // GIVEN
        assertEq(instanceReader.products(), 0, "unexpected products count (before)");

        // WHEN
        vm.startPrank(instanceOwner);

        SimpleProduct myProduct = _deployProduct("MyProduct", instanceOwner, true, 1);
        NftId myProductNftId = instance.registerProduct(address(myProduct), address(token));

        SimpleDistribution myDistribution = _deployDistribution("MyDistribution", myProductNftId, instanceOwner);
        SimpleOracle myOracle = _deployOracle("MyOracle", myProductNftId, instanceOwner);
        SimplePool myPool = _deployPool("MyPool", myProductNftId, instanceOwner);

        myProduct.registerComponent(address(myDistribution));
        myProduct.registerComponent(address(myOracle));
        myProduct.registerComponent(address(myPool));

        vm.stopPrank();

        // THEN
        assertEq(instanceReader.products(), 1, "unexpected products count (after)");
        assertEq(instanceReader.getProduct(0).toInt(), myProductNftId.toInt(), "unexpected product nft id (1)");
    }


    function test_componentTrackingMultipleProductsOnly() public {
        // GIVEN
        assertEq(instanceReader.products(), 0, "unexpected products count (before)");

        // WHEN
        vm.startPrank(instanceOwner);
        SimpleProduct myProduct1 = _deployProduct("MyProduct1", instanceOwner, true, 1);
        NftId myProductNftId1 = instance.registerProduct(address(myProduct1), address(token));

        SimpleProduct myProduct2 = _deployProduct("MyProduct2", instanceOwner, true, 1);
        NftId myProductNftId2 = instance.registerProduct(address(myProduct2), address(token));

        SimpleProduct myProduct3 = _deployProduct("MyProduct3", instanceOwner, true, 1);
        NftId myProductNftId3 = instance.registerProduct(address(myProduct3), address(token));
        vm.stopPrank();

        // THEN
        assertEq(instanceReader.products(), 3, "unexpected products count (after)");
        assertEq(instanceReader.getProduct(0).toInt(), myProductNftId1.toInt(), "unexpected product nft id (1a)");
        assertEq(instanceReader.getProduct(1).toInt(), myProductNftId2.toInt(), "unexpected product nft id (1b)");
        assertEq(instanceReader.getProduct(2).toInt(), myProductNftId3.toInt(), "unexpected product nft id (1c)");
    }


    function test_componentTrackingMultipleProductsComplete() public {
        // GIVEN
        assertEq(instanceReader.products(), 0, "unexpected products count (before)");

        // WHEN
        vm.startPrank(instanceOwner);
        SimpleProduct myProduct1 = _deployProduct("MyProduct1", instanceOwner, false, 0);
        NftId myProductNftId1 = instance.registerProduct(address(myProduct1), address(token));
        SimplePool myPool1 = _deployPool("MyPool1", myProductNftId1, instanceOwner);
        myProduct1.registerComponent(address(myPool1));

        SimpleProduct myProduct2 = _deployProduct("MyProduct2", instanceOwner, true, 0);
        NftId myProductNftId2 = instance.registerProduct(address(myProduct2), address(token));
        SimpleDistribution myDistribution2 = _deployDistribution("MyDistribution2", myProductNftId2, instanceOwner);
        SimplePool myPool2 = _deployPool("MyPool2", myProductNftId2, instanceOwner);
        myProduct2.registerComponent(address(myDistribution2));
        myProduct2.registerComponent(address(myPool2));

        SimpleProduct myProduct3 = _deployProduct("MyProduct3", instanceOwner, false, 2);
        NftId myProductNftId3 = instance.registerProduct(address(myProduct3), address(token));
        SimpleOracle myOracle3a = _deployOracle("MyOracle3a", myProductNftId3, instanceOwner);
        SimpleOracle myOracle3b = _deployOracle("MyOracle3b", myProductNftId3, instanceOwner);
        SimplePool myPool3 = _deployPool("MyPool3", myProductNftId3, instanceOwner);
        myProduct3.registerComponent(address(myOracle3a));
        myProduct3.registerComponent(address(myOracle3b));
        myProduct3.registerComponent(address(myPool3));
        vm.stopPrank();

        // THEN
        assertEq(instanceReader.products(), 3, "unexpected products count (after)");
        assertEq(instanceReader.getProduct(0).toInt(), myProductNftId1.toInt(), "unexpected product nft id (1a)");
        assertEq(instanceReader.getProduct(1).toInt(), myProductNftId2.toInt(), "unexpected product nft id (1b)");
        assertEq(instanceReader.getProduct(2).toInt(), myProductNftId3.toInt(), "unexpected product nft id (1c)");
    }

    function test_componentTracking_noDistributionExpected() public {
        // GIVEN
        assertEq(instanceReader.products(), 0, "unexpected products count (before)");

        // WHEN
        vm.startPrank(instanceOwner);

        SimpleProduct myProduct = _deployProduct("MyProduct", instanceOwner, false, 0);
        NftId myProductNftId = instance.registerProduct(address(myProduct), address(token));

        SimpleDistribution myDistribution = _deployDistribution("MyDistribution", myProductNftId, instanceOwner);

        vm.expectRevert(abi.encodeWithSelector(
            IComponentService.ErrorProductServiceNoDistributionExpected.selector, 
            myProductNftId));
        myProduct.registerComponent(address(myDistribution));   
    }

    function test_componentTracking_distributionAlreadyRegistered() public {
        // GIVEN
        assertEq(instanceReader.products(), 0, "unexpected products count (before)");

        // WHEN
        vm.startPrank(instanceOwner);

        SimpleProduct myProduct = _deployProduct("MyProduct", instanceOwner, true, 0);
        NftId myProductNftId = instance.registerProduct(address(myProduct), address(token));

        SimpleDistribution myDistribution = _deployDistribution("MyDistribution", myProductNftId, instanceOwner);
        NftId distNftId = myProduct.registerComponent(address(myDistribution));
        SimpleDistribution myDistribution2 = _deployDistribution("MyDistribution2", myProductNftId, instanceOwner);

        vm.expectRevert(abi.encodeWithSelector(
            IComponentService.ErrorProductServiceDistributionAlreadyRegistered.selector, 
            myProductNftId,
            distNftId));
        myProduct.registerComponent(address(myDistribution2));
    }

    function test_componentTracking_noOracleExpected() public {
        // GIVEN
        assertEq(instanceReader.products(), 0, "unexpected products count (before)");

        // WHEN
        vm.startPrank(instanceOwner);

        SimpleProduct myProduct = _deployProduct("MyProduct", instanceOwner, false, 0);
        NftId myProductNftId = instance.registerProduct(address(myProduct), address(token));

        SimpleOracle myOracle = _deployOracle("MyOracle", myProductNftId, instanceOwner);

        vm.expectRevert(abi.encodeWithSelector(
            IComponentService.ErrorProductServiceNoOraclesExpected.selector, 
            myProductNftId));
        myProduct.registerComponent(address(myOracle));   
    }

    function test_componentTracking_oracleAlreadyRegistered() public {
        // GIVEN
        assertEq(instanceReader.products(), 0, "unexpected products count (before)");

        // WHEN
        vm.startPrank(instanceOwner);

        SimpleProduct myProduct = _deployProduct("MyProduct", instanceOwner, false, 1);
        NftId myProductNftId = instance.registerProduct(address(myProduct), address(token));

        SimpleOracle myOracle = _deployOracle("MyOracle", myProductNftId, instanceOwner);
        NftId oracleNftId = myProduct.registerComponent(address(myOracle));
        SimpleOracle myOracle2 = _deployOracle("MyOracle2", myProductNftId, instanceOwner);

        vm.expectRevert(abi.encodeWithSelector(
            IComponentService.ErrorProductServiceOraclesAlreadyRegistered.selector, 
            myProductNftId,
            1));
        myProduct.registerComponent(address(myOracle2));
        
    }

    function test_componentEmptyName() public {
        // GIVEN
        assertEq(instanceReader.products(), 0, "unexpected products count (before)");

        // WHEN
        vm.startPrank(instanceOwner);

        IComponents.ProductInfo memory productInfo = _getSimpleProductInfo();
        IComponents.FeeInfo memory feeInfo = _getSimpleFeeInfo();
        BasicProductAuthorization auth = new BasicProductAuthorization("empty name");

        vm.expectRevert(abi.encodeWithSelector(
            IComponent.ErrorComponentNameLengthZero.selector));
        new SimpleProduct(
            address(registry),
            instanceNftId, 
            "",
            productInfo,
            feeInfo,
            auth,
            instanceOwner);
    }


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

    function _deployDistribution(
        string memory name, 
        NftId productNftId,
        address owner
    )
        internal
        returns(SimpleDistribution)
    {
        return new SimpleDistribution(
            address(registry),
            productNftId,
            new BasicDistributionAuthorization(name),
            owner);
    }

    function _deployOracle(
        string memory name, 
        NftId productNftId,
        address owner
    )
        internal
        returns(SimpleOracle)
    {
        return new SimpleOracle(
            address(registry),
            productNftId,
            new BasicOracleAuthorization(name, COMMIT_HASH),
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