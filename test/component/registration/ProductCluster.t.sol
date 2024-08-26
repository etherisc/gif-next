// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Vm, console} from "../../../lib/forge-std/src/Test.sol";

import {IApplicationService} from "../../../contracts/product/IApplicationService.sol";
import {IAuthorization} from "../../../contracts/authorization/IAuthorization.sol";
import {IComponents} from "../../../contracts/instance/module/IComponents.sol";
import {IComponentService} from "../../../contracts/shared/IComponentService.sol";
import {IDistributionService} from "../../../contracts/distribution/IDistributionService.sol";
import {IPricingService} from "../../../contracts/product/IPricingService.sol";
import {IPolicyService} from "../../../contracts/product/IPolicyService.sol";
import {IRegisterable} from "../../../contracts/shared/IRegisterable.sol";
import {IRelease} from "../../../contracts/registry/IRelease.sol";
import {IInstanceLinkedComponent} from "../../../contracts/shared/IInstanceLinkedComponent.sol";
import {ILifecycle} from "../../../contracts/shared/ILifecycle.sol";
import {INftOwnable} from "../../../contracts/shared/INftOwnable.sol";
import {IPolicy} from "../../../contracts/instance/module/IPolicy.sol";
import {IBundle} from "../../../contracts/instance/module/IBundle.sol";

import {Amount, AmountLib} from "../../../contracts/type/Amount.sol";
import {BasicDistributionAuthorization} from "../../../contracts/distribution/BasicDistributionAuthorization.sol";
import {BasicOracleAuthorization} from "../../../contracts/oracle/BasicOracleAuthorization.sol";
import {BasicPoolAuthorization} from "../../../contracts/pool/BasicPoolAuthorization.sol";
import {BasicProductAuthorization} from "../../../contracts/product/BasicProductAuthorization.sol";
import {DistributorType} from "../../../contracts/type/DistributorType.sol";
import {FeeLib} from "../../../contracts/type/Fee.sol";
import {GifTest} from "../../base/GifTest.sol";
import {NftId, NftIdLib} from "../../../contracts/type/NftId.sol";
import {SimpleProduct} from "../../../contracts/examples/unpermissioned/SimpleProduct.sol";
import {SimpleDistribution} from "../../../contracts/examples/unpermissioned/SimpleDistribution.sol";
import {SimpleOracle} from "../../../contracts/examples/unpermissioned/SimpleOracle.sol";
import {SimplePool} from "../../../contracts/examples/unpermissioned/SimplePool.sol";
import {Registerable} from "../../../contracts/shared/Registerable.sol";
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
import {ReferralId, ReferralLib} from "../../../contracts/type/Referral.sol";
import {SUBMITTED, ACTIVE, COLLATERALIZED, CONFIRMED, DECLINED, CLOSED} from "../../../contracts/type/StateId.sol";
import {StateId} from "../../../contracts/type/StateId.sol";
import {UFixed, UFixedLib} from "../../../contracts/type/UFixed.sol";

contract ProductClusterTest is GifTest {

    uint256 public INSTANCE_OWNER_FUNDING;
    uint256 public BUNDLE_FUNDING;
    Seconds public BUNDLE_LFETIME;

    uint256 public SUM_INSURED_AMOUNT;
    Seconds public POLICY_LIFETIME;

    UFixed public DISCOUNT;
    UFixed public COMMISSION;
    Seconds public REFERRAL_LFETIME;
    uint32 public MAX_REFERRALS;
    Seconds REFERRAL_LIFETIME;

    // product cluster 1
    SimpleProduct public myProduct1;
    SimpleDistribution public myDistribution1;
    SimplePool public myPool1;
    NftId public myProductNftId1;
    NftId public myDistributionNftId1;
    NftId public myPoolNftId1;

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


    function setUp() public override {
        super.setUp();

        INSTANCE_OWNER_FUNDING = 1000000 * 10 ** token.decimals();
        BUNDLE_FUNDING = 100000 * 10 ** token.decimals();
        BUNDLE_LFETIME = SecondsLib.toSeconds(30 * 24 * 3600); // 30 days

        SUM_INSURED_AMOUNT = 10000 * 10 ** token.decimals();
        POLICY_LIFETIME = SecondsLib.toSeconds(1 * 24 * 3600); // 1 day

        DISCOUNT = UFixedLib.toUFixed(1, -1);
        COMMISSION = UFixedLib.toUFixed(5, -2);
        MAX_REFERRALS = 100;
        REFERRAL_LFETIME = SecondsLib.toSeconds(30 * 24 * 3600); // 30 days
    }


    function test_productClusterSetup1and2() public {
        // GIVEN setup

        // WHEN
        _setupProductCluster1();
        _setupProductCluster2();
        _fundInstanceOwnerAndCreateApprovals();
        _createProductSpecificObjects1and2();

        // THEN
        assertEq(instanceReader.components(), 7, "unexpected components count (after setup)");
        assertEq(instanceReader.products(), 2, "unexpected products count (after setup)");

        assertTrue(applicationNftId1.gtz(), "applicationNftId1 not set");
        assertTrue(applicationNftId2.gtz(), "applicationNftId2 not set");
        assertTrue(policyNftId1.gtz(), "policyNftId1 not set");
        assertTrue(policyNftId2.gtz(), "policyNftId2 not set");

        // solhint-disable
        console.log("applicationNftId1:", applicationNftId1.toInt(), "- product nft id:", registry.getParentNftId(applicationNftId1).toInt());
        console.log("applicationNftId2:", applicationNftId2.toInt(), "- product nft id:", registry.getParentNftId(applicationNftId2).toInt());
        console.log("policyNftId1:", policyNftId1.toInt(), "- product nft id:", registry.getParentNftId(policyNftId1).toInt());
        console.log("policyNftId2:", policyNftId2.toInt(), "- product nft id:", registry.getParentNftId(policyNftId2).toInt());
        // solhint-enable
    }


    function test_productClusterSetup1and4() public {
        _setupProductClusters1and4();

        assertEq(instanceReader.components(), 5, "unexpected components count (after setup)");
        assertEq(instanceReader.products(), 2, "unexpected products count (after setup)");

        _printAuthz(instance.getInstanceAdmin(), "instance authz for prod clusters 1 and 4");
    }


    function test_productClusterSetup1to4() public {
        _setupProductClusters1to4();

        assertEq(instanceReader.components(), 13, "unexpected components count (after setup)");
        assertEq(instanceReader.products(), 4, "unexpected products count (after setup)");

        _createProductSpecificObjects1and2();

        assertTrue(bundleNftId1.gtz(), "bundleNftId1 not set");
        assertTrue(bundleNftId2.gtz(), "bundleNftId2 not set");
        assertTrue(policyNftId1.gtz(), "policyNftId1 not set");
        assertTrue(policyNftId2.gtz(), "policyNftId2 not set");
    }


    function test_productClusterApplicationCreateInvalidRisk() public {
        _setupProductClusters1to4();
        _createProductSpecificObjects1and2();

        vm.expectRevert(
            abi.encodeWithSelector(
                IApplicationService.ErrorApplicationServiceRiskUnknown.selector, 
                riskId2,
                myProductNftId1));

        _createApplication(myProduct1, riskId2, bundleNftId1, referralId1);
    }


    function test_productClusterApplicationCreateInvalidBundle() public {
        _setupProductClusters1to4();
        _createProductSpecificObjects1and2();

        vm.expectRevert(
            abi.encodeWithSelector(
                IPricingService.ErrorPricingServiceBundlePoolMismatch.selector, 
                bundleNftId2, 
                myPoolNftId2,
                myPoolNftId1));

        _createApplication(myProduct1, riskId1, bundleNftId2, referralId1);
    }


    function test_productClusterApplicationCreateInvalidReferral() public {
        _setupProductClusters1to4();
        _createProductSpecificObjects1and2();

        // TODO re-enable after fixing bug #623
        // vm.expectRevert(
        //     abi.encodeWithSelector(
        //         IPricingService.ErrorPricingServiceBundlePoolMismatch.selector, 
        //         riskId2,
        //         myProductNftId1));

        _createApplication(myProduct1, riskId1, bundleNftId1, referralId2);
    }


    function test_productClusterPolicyCreationByWrongProduct() public {
        _setupProductClusters1to4();
        _createProductSpecificObjects1and2();

        Timestamp activateAt = TimestampLib.blockTimestamp();

        vm.expectRevert(
            abi.encodeWithSelector(
                IPolicyService.ErrorPolicyServicePolicyProductMismatch.selector, 
                applicationNftId2, 
                myProductNftId1, // expected (caller)
                myProductNftId2)); // actual (from application)

        _createPolicy(myProduct1, applicationNftId2, activateAt);
    }


    function _createProductSpecificObjects1and2() internal {
        riskId1 = _createAndCheckRisk(myProduct1, "Risk1");
        riskId2 = _createAndCheckRisk(myProduct2, "Risk2"); // TODO fix bug #621

        referralId1 = _createReferral(myDistribution1, "SAVE!!!");
        referralId2 = _createReferral(myDistribution2, "SAVE!!!");

        bundleNftId1 = _createBundle(myPool1);
        bundleNftId2 = _createBundle(myPool2);

        applicationNftId1 = _createApplication(myProduct1, riskId1, bundleNftId1, referralId1);
        applicationNftId2 = _createApplication(myProduct2, riskId2, bundleNftId2, referralId2);

        policyNftId1 = _createApplication(myProduct1, riskId1, bundleNftId1, referralId1);
        policyNftId2 = _createApplication(myProduct2, riskId2, bundleNftId2, referralId2);
        _createPolicy(myProduct1, policyNftId1, TimestampLib.blockTimestamp());
        _createPolicy(myProduct2, policyNftId2, TimestampLib.blockTimestamp());
    }


    function _createPolicy(SimpleProduct prd, NftId applicationNftId, Timestamp activateAt) internal {
        vm.startPrank(instanceOwner);
        prd.createPolicy(applicationNftId, false, activateAt);
        vm.stopPrank();
    }


    function _createApplication(
        SimpleProduct prd,
        RiskId rskId,
        NftId bdlNftId,
        ReferralId rflId
    )
        internal
        returns (NftId applicationNftId)
    {
        vm.startPrank(instanceOwner);
        applicationNftId = prd.createApplication(
            instanceOwner,
            rskId,
            SUM_INSURED_AMOUNT,
            POLICY_LIFETIME,
            "",
            bdlNftId,
            rflId);
        vm.stopPrank();
    }


    function _createRisk(SimpleProduct prd, string memory riskName) internal returns (RiskId riskId) {
        vm.startPrank(instanceOwner);
        riskId = RiskIdLib.toRiskId(riskName);
        prd.createRisk(riskId, "");
        vm.stopPrank();
    }


    function _createReferral(SimpleDistribution dist, string memory referralCode) internal returns (ReferralId referralId) {
        vm.startPrank(instanceOwner);
        referralId = dist.createReferral(
            referralCode,
            DISCOUNT, // 10% discount
            MAX_REFERRALS, // max referrals
            TimestampLib.blockTimestamp().addSeconds(
                SecondsLib.toSeconds(5 * 24 * 3600)), // expiry in 5 days
            ""); // referral data
        vm.stopPrank();
    }


    function _createBundle(SimplePool pl) internal returns (NftId bundleNftId) {
        vm.startPrank(instanceOwner);
        (bundleNftId,) = pl.createBundle(
            FeeLib.zero(), 
            BUNDLE_FUNDING, 
            BUNDLE_LFETIME, 
            "");
        vm.stopPrank();
    }


    function _createAndCheckRisk(SimpleProduct prd, string memory riskName) internal returns (RiskId riskId) {
        uint256 risksBefore = instanceReader.risks(prd.getNftId());
        riskId = _createRisk(prd, riskName);
        assertEq(instanceReader.risks(prd.getNftId()) - risksBefore, 1, "unexpected risk count");
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
        myPoolNftId1 = myProduct1.registerComponent(address(myPool1));
        vm.stopPrank();

        _prepareDistributor(myDistribution1);
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

        _prepareDistributor(myDistribution2);
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