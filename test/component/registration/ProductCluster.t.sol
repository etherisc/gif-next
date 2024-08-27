// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "forge-std/Test.sol";

import {IApplicationService} from "../../../contracts/product/IApplicationService.sol";
import {IDistributionService} from "../../../contracts/distribution/IDistributionService.sol";
import {IPricingService} from "../../../contracts/product/IPricingService.sol";
import {IPolicyService} from "../../../contracts/product/IPolicyService.sol";

import {FeeLib} from "../../../contracts/type/Fee.sol";
import {GifClusterTest} from "../../base/GifClusterTest.sol";
import {NftId} from "../../../contracts/type/NftId.sol";
import {SimplePool} from "../../../contracts/examples/unpermissioned/SimplePool.sol";
import {SimpleProduct} from "../../../contracts/examples/unpermissioned/SimpleProduct.sol";
import {SimpleDistribution} from "../../../contracts/examples/unpermissioned/SimpleDistribution.sol";
import {FeeLib} from "../../../contracts/type/Fee.sol";
import {UFixedLib} from "../../../contracts/type/UFixed.sol";
import {SecondsLib} from "../../../contracts/type/Seconds.sol";
import {Timestamp, TimestampLib} from "../../../contracts/type/Timestamp.sol";
import {IPolicyService} from "../../../contracts/product/IPolicyService.sol";
import {RiskId} from "../../../contracts/type/RiskId.sol";
import {ReferralId} from "../../../contracts/type/Referral.sol";
import {UFixedLib} from "../../../contracts/type/UFixed.sol";

contract ProductClusterTest is GifClusterTest {


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
                IPricingService.ErrorPricingServiceRiskProductMismatch.selector, 
                riskId2,
                myProductNftId2,
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

        vm.expectRevert(
            abi.encodeWithSelector(
                IDistributionService.ErrorDistributionServiceReferralDistributionMismatch.selector, 
                referralId2,
                myDistributionNftId2,
                myDistributionNftId1));

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
        riskId = prd.createRisk(riskName, "");
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


}