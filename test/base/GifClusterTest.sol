// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {BasicDistributionAuthorization} from "../../contracts/distribution/BasicDistributionAuthorization.sol";
import {BasicOracleAuthorization} from "../../contracts/oracle/BasicOracleAuthorization.sol";
import {BasicPoolAuthorization} from "../../contracts/pool/BasicPoolAuthorization.sol";
import {BasicProductAuthorization} from "../../contracts/product/BasicProductAuthorization.sol";
import {DistributorType} from "../../contracts/type/DistributorType.sol";
import {FeeLib} from "../../contracts/type/Fee.sol";
import {GifTest} from "./GifTest.sol";
import {IComponents} from "../../contracts/instance/module/IComponents.sol";
import {NftId} from "../../contracts/type/NftId.sol";
import {SimpleProduct} from "../../contracts/examples/unpermissioned/SimpleProduct.sol";
import {SimpleDistribution} from "../../contracts/examples/unpermissioned/SimpleDistribution.sol";
import {SimpleOracle} from "../../contracts/examples/unpermissioned/SimpleOracle.sol";
import {SimplePool} from "../../contracts/examples/unpermissioned/SimplePool.sol";
import {FeeLib} from "../../contracts/type/Fee.sol";
import {UFixedLib} from "../../contracts/type/UFixed.sol";
import {Seconds} from "../../contracts/type/Seconds.sol";
import {RiskId} from "../../contracts/type/RiskId.sol";
import {ReferralId} from "../../contracts/type/Referral.sol";
import {UFixed, UFixedLib} from "../../contracts/type/UFixed.sol";

contract GifClusterTest is GifTest {

    uint256 public INSTANCE_OWNER_FUNDING;
    uint256 public BUNDLE_FUNDING;
    Seconds public BUNDLE_LFETIME;

    uint256 public SUM_INSURED_AMOUNT;
    Seconds public POLICY_LIFETIME;

    UFixed public DISCOUNT;
    UFixed public COMMISSION;
    Seconds public REFERRAL_LFETIME;
    uint32 public MAX_REFERRALS;
    Seconds public REFERRAL_LIFETIME;

    // product cluster 1
    SimpleProduct public myProduct1;
    SimpleDistribution public myDistribution1;
    SimplePool public myPool1;
    NftId public myProductNftId1;
    NftId public myDistributionNftId1;
    NftId public myDistributorNftId1;
    NftId public myPoolNftId1;

    // product cluster 2
    SimpleProduct public myProduct2;
    SimpleDistribution public myDistribution2;
    SimpleOracle public myOracle2;
    SimplePool public myPool2;
    NftId public myProductNftId2;
    NftId public myDistributionNftId2;
    NftId public myDistributorNftId2;
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

    // product cluster specific objects
    RiskId public riskId1;
    RiskId public riskId2;

    ReferralId public referralId1;
    ReferralId public referralId2;

    NftId public bundleNftId1;
    NftId public bundleNftId2;

    NftId public applicationNftId1;
    NftId public applicationNftId2;

    NftId public policyNftId1;
    NftId public policyNftId2;

    function _setupProductClusters1and4() internal {
        _setupProductCluster1();
        _setupProductCluster4();
        _fundInstanceOwnerAndCreateApprovals();
    }


    function _setupProductClusters1and2() internal {
        _setupProductCluster1();
        _setupProductCluster2();
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
        myProductNftId1 = instance.registerProduct(address(myProduct1), address(token));
        myDistribution1 = _deployDistribution("MyDistribution1", myProductNftId1, instanceOwner);
        myPool1 = _deployPool("MyPool1", myProductNftId1, instanceOwner);
        myDistributionNftId1 = myProduct1.registerComponent(address(myDistribution1));
        myPoolNftId1 = myProduct1.registerComponent(address(myPool1));
        vm.stopPrank();

        myDistributorNftId1 = _prepareDistributor(myDistribution1);
    }


    function _setupProductCluster2() internal {
        vm.startPrank(instanceOwner);
        myProduct2 = _deployProduct("MyProduct2", instanceOwner, true, 1);
        myProductNftId2 = instance.registerProduct(address(myProduct2), address(token));
        myDistribution2 = _deployDistribution("MyDistribution2", myProductNftId2, instanceOwner);
        myOracle2 = _deployOracle("MyOracle2", myProductNftId2, instanceOwner);
        myPool2 = _deployPool("MyPool2", myProductNftId2, instanceOwner);
        myDistributionNftId2 = myProduct2.registerComponent(address(myDistribution2));
        myOracleNftId2 = myProduct2.registerComponent(address(myOracle2));
        myPoolNftId2 = myProduct2.registerComponent(address(myPool2));
        vm.stopPrank();

        myDistributorNftId2 = _prepareDistributor(myDistribution2);
    }


    function _setupProductCluster3() internal {
        vm.startPrank(instanceOwner);
        myProduct3 = _deployProduct("MyProduct3", instanceOwner, false, 2);
        myProductNftId3 = instance.registerProduct(address(myProduct3), address(token));
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
        myProductNftId4 = instance.registerProduct(address(myProduct4), address(token));
        myPool4 = _deployPool("MyPool4", myProductNftId4, instanceOwner);
        myPoolNftId4 = myProduct4.registerComponent(address(myPool4));
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
            new BasicOracleAuthorization(name),
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

    function _prepareDistributor(SimpleDistribution dist) internal returns (NftId distributorNftId) {
        vm.startPrank(instanceOwner);
        dist.setFees(
            FeeLib.toFee(UFixedLib.toUFixed(2,-1), 0), // distribution fee
            FeeLib.toFee(UFixedLib.toUFixed(5,-2), 0)); // min distribution owner fee

        DistributorType dt = dist.createDistributorType(
            "Standard",
            DISCOUNT, // min discount
            DISCOUNT, // max discount
            COMMISSION,
            MAX_REFERRALS, // max referrals
            REFERRAL_LFETIME, // max lifetime
            true, // self referrals allowed
            true, // allow renewals
            ""); // data)

        distributorNftId = dist.createDistributor(
            instanceOwner, 
            dt,
            "");
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

}