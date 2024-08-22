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
import {SimpleDistribution} from "../../../contracts/examples/unpermissioned/SimpleDistribution.sol";
import {SimpleOracle} from "../../../contracts/examples/unpermissioned/SimpleOracle.sol";
import {SimplePool} from "../../../contracts/examples/unpermissioned/SimplePool.sol";
import {IAuthorization} from "../../../contracts/authorization/IAuthorization.sol";
import {IComponents} from "../../../contracts/instance/module/IComponents.sol";
import {IComponentService} from "../../../contracts/shared/IComponentService.sol";
import {Registerable} from "../../../contracts/shared/Registerable.sol";
import {IRegisterable} from "../../../contracts/shared/IRegisterable.sol";
import {IRelease} from "../../../contracts/registry/IRelease.sol";
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

contract ProductClusterTest is GifTest {

        uint256 public INSTANCE_OWNER_FUNDING;

        // product cluster 1
        SimpleProduct public myProduct1;
        SimpleDistribution public myDistribution1;
        SimplePool public myPool1;
        NftId public myProductNftId1;
        NftId public myDistributionNftId1;
        NftId public myPool1NftId1;

        // product cluster 2
        SimpleProduct public myProduct2;
        SimpleDistribution public myDistribution2;
        SimpleOracle myOracle2;
        SimplePool public myPool2;
        NftId public myProductNftId2;
        NftId public myDistributionNftId2;
        NftId public myOracleNftId2;
        NftId public myPoolNftId2;

        // product cluster 3
        SimpleProduct public myProduct3;
        SimpleOracle public myOracle3a;
        SimpleOracle public myOracle3b;
        SimplePool public myPool3;
        NftId public myProductNftId3;
        NftId public myOracleNftId3a;
        NftId public myOracleNftId3b;
        NftId public myPoolNftId3;

        // product cluster 4
        SimpleProduct public myProduct4;
        SimplePool public myPool4;
        NftId public myProductNftId4;
        NftId public myPoolNftId4;


    function setUp() public override {
        super.setUp();

        INSTANCE_OWNER_FUNDING = 1000000 * 10 ** token.decimals();
    }


    function test_clusterSetup1and4() public {
        _setupProductClusters1and4();

        assertEq(instanceReader.components(), 5, "unexpected components count (after setup)");
        assertEq(instanceReader.products(), 2, "unexpected products count (after setup)");

        _printAuthz(instance.getInstanceAdmin(), "instance authz for prod clusters 1 and 4");
    }


    function test_clusterSetup1to4() public {
        _setupProductClusters1to4();

        assertEq(instanceReader.components(), 13, "unexpected components count (after setup)");
        assertEq(instanceReader.products(), 4, "unexpected products count (after setup)");
    }


    function _setupProductClusters1and4() internal {
        _setupProductCluster1();
        _setupProductCluster4();
        _fundInstanceOwnerAndCreateApprovals();
    }


    function _setupProductClusters1to4() internal {
        _setupProductCluster1();
        _setupProductCluster2();
        _setupProductCluster3();
        _setupProductCluster4();
        _fundInstanceOwnerAndCreateApprovals();
    }

    function _setupProductCluster1() internal {
        vm.startPrank(instanceOwner);
        myProduct1 = _deployProduct("MyProduct1", instanceOwner, true, 0);
        myProductNftId1 = instance.registerProduct(address(myProduct1));
        myDistribution1 = _deployDistribution("MyDistribution1", myProductNftId1, instanceOwner);
        myPool1 = _deployPool("MyPool1", myProductNftId1, instanceOwner);
        myDistributionNftId1 = myProduct1.registerComponent(address(myDistribution1));
        myPool1NftId1 = myProduct1.registerComponent(address(myPool1));
        vm.stopPrank();
    }


    function _setupProductCluster2() internal {
        vm.startPrank(instanceOwner);
        myProduct2 = _deployProduct("MyProduct2", instanceOwner, true, 1);
        myProductNftId2 = instance.registerProduct(address(myProduct2));
        myDistribution2 = _deployDistribution("MyDistribution2", myProductNftId2, instanceOwner);
        myOracle2 = _deployOracle("MyOracle2", myProductNftId2, instanceOwner);
        myPool2 = _deployPool("MyPool2", myProductNftId2, instanceOwner);
        myDistributionNftId2 = myProduct2.registerComponent(address(myDistribution2));
        myOracleNftId2 = myProduct2.registerComponent(address(myOracle2));
        myPoolNftId2 = myProduct2.registerComponent(address(myPool2));
        vm.stopPrank();
    }


    function _setupProductCluster3() internal {
        vm.startPrank(instanceOwner);
        myProduct3 = _deployProduct("MyProduct3", instanceOwner, false, 2);
        myProductNftId3 = instance.registerProduct(address(myProduct3));
        myOracle3a = _deployOracle("MyOracle3a", myProductNftId3, instanceOwner);
        myOracle3b = _deployOracle("MyOracle3b", myProductNftId3, instanceOwner);
        myPool3 = _deployPool("MyPool3", myProductNftId3, instanceOwner);
        myOracleNftId3a = myProduct3.registerComponent(address(myOracle3a));
        myOracleNftId3b = myProduct3.registerComponent(address(myOracle3b));
        myPoolNftId3 = myProduct3.registerComponent(address(myPool3));
        vm.stopPrank();
    }


    function _setupProductCluster4() internal {
        vm.startPrank(instanceOwner);
        myProduct4 = _deployProduct("MyProduct4", instanceOwner, false, 0);
        myProductNftId4 = instance.registerProduct(address(myProduct4));
        myPool4 = _deployPool("MyPool4", myProductNftId4, instanceOwner);
        myPoolNftId4 = myProduct4.registerComponent(address(myPool4));
        vm.stopPrank();
    }

    function _fundInstanceOwnerAndCreateApprovals() internal {

        vm.startPrank(registryOwner);
        token.transfer(instanceOwner, INSTANCE_OWNER_FUNDING);
        vm.stopPrank();

        vm.startPrank(instanceOwner);

        if (myProductNftId1.gtz()) {
            token.approve(address(myProduct1.getTokenHandler()), INSTANCE_OWNER_FUNDING);
            token.approve(address(myDistribution1.getTokenHandler()), INSTANCE_OWNER_FUNDING);
            token.approve(address(myPool1.getTokenHandler()), INSTANCE_OWNER_FUNDING);
        }

        if (myProductNftId2.gtz()) {
            token.approve(address(myProduct2.getTokenHandler()), INSTANCE_OWNER_FUNDING);
            token.approve(address(myDistribution2.getTokenHandler()), INSTANCE_OWNER_FUNDING);
            token.approve(address(myOracle2.getTokenHandler()), INSTANCE_OWNER_FUNDING);
            token.approve(address(myPool2.getTokenHandler()), INSTANCE_OWNER_FUNDING);
        }

        if (myProductNftId3.gtz()) {
            token.approve(address(myProduct3.getTokenHandler()), INSTANCE_OWNER_FUNDING);
            token.approve(address(myOracle3a.getTokenHandler()), INSTANCE_OWNER_FUNDING);
            token.approve(address(myOracle3b.getTokenHandler()), INSTANCE_OWNER_FUNDING);
            token.approve(address(myPool3.getTokenHandler()), INSTANCE_OWNER_FUNDING);
        }

        if (myProductNftId4.gtz()) {
            token.approve(address(myProduct4.getTokenHandler()), INSTANCE_OWNER_FUNDING);
            token.approve(address(myPool4.getTokenHandler()), INSTANCE_OWNER_FUNDING);
        }

        vm.stopPrank();
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
            address(token),
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
            owner,
            address(token));
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
            new BasicOracleAuthorization(name),
            owner,
            address(token));
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