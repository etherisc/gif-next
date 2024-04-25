// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ACTIVE, APPLIED} from "../../../contracts/type/StateId.sol";
import {Amount} from "../../../contracts/type/Amount.sol";
import {console} from "../../../lib/forge-std/src/Test.sol";
import {Fee, FeeLib} from "../../../contracts/type/Fee.sol";
import {IBundle} from "../../../contracts/instance/module/IBundle.sol";
import {IComponents} from "../../../contracts/instance/module/IComponents.sol";
import {IDistribution} from "../../../contracts/instance/module/IDistribution.sol";
import {IPolicy} from "../../../contracts/instance/module/IPolicy.sol";
import {NftId, NftIdLib} from "../../../contracts/type/NftId.sol";
import {POLICY} from "../../../contracts/type/ObjectType.sol";
import {POOL_OWNER_ROLE, PRODUCT_OWNER_ROLE} from "../../../contracts/type/RoleId.sol";
import {ReferralId, ReferralLib} from "../../../contracts/type/Referral.sol";
import {ReferralTestBase} from "./ReferralTestBase.sol";
import {RiskId, RiskIdLib} from "../../../contracts/type/RiskId.sol";
import {Seconds, SecondsLib} from "../../../contracts/type/Seconds.sol";
import {SimpleDistribution} from "../../mock/SimpleDistribution.sol";
import {SimplePool} from "../../mock/SimplePool.sol";
import {SimpleProduct} from "../../mock/SimpleProduct.sol";
import {TimestampLib} from "../../../contracts/type/Timestamp.sol";
import {UFixed, UFixedLib} from "../../../contracts/type/UFixed.sol";

contract ReferralTest is ReferralTestBase {
    using NftIdLib for NftId;

    function test_DistributionReferralIsValidTrue() public {
        _setupTestData(true);

        // solhint-disable-next-line 
        console.log("distributor nft id", distributorNftId.toInt());

        SimpleDistribution sdistribution = SimpleDistribution(address(distribution));
        referralId = sdistribution.createReferral(
            distributorNftId,
            referralCode,
            discountPercentage,
            maxReferrals,
            expiryAt,
            referralData);

        assertTrue(distributionService.referralIsValid(distributionNftId, referralId), "referral is not valid");
    }

    function test_Distribution_referralIsValid_false() public {
        _setupTestData(true);

        // solhint-disable-next-line 
        console.log("distributor nft id", distributorNftId.toInt());

        SimpleDistribution sdistribution = SimpleDistribution(address(distribution));
        referralId = sdistribution.createReferral(
            distributorNftId,
            referralCode,
            discountPercentage,
            maxReferrals,
            expiryAt,
            referralData);

        assertFalse(distributionService.referralIsValid(distributionNftId, ReferralLib.toReferralId(distributionNftId, "UNKNOWN")), "referral is valid");
    }

    function test_ReferralCollateralizeWithReferral() public {

        _setupTestData(true);

        Amount bundleBalanceInitial = instanceReader.getBalanceAmount(bundleNftId);
        Amount bundleFeeInitial = instanceReader.getFeeAmount(bundleNftId);

        assertEq(instanceReader.getBalanceAmount(bundleNftId).toInt(), bundleBalanceInitial.toInt(), "unexpected initial bundle balance");
        assertEq(instanceReader.getFeeAmount(bundleNftId).toInt(), bundleFeeInitial.toInt(), "unexpected initial bundle balance");

        // GIVEN
        vm.startPrank(registryOwner);
        token.transfer(customer, 1000);
        vm.stopPrank();

        // create risk
        vm.startPrank(productOwner);
        RiskId riskId = RiskIdLib.toRiskId("42x4711");
        bytes memory data = "bla di blubb";
        product.createRisk(riskId, data);
        vm.stopPrank();

        vm.startPrank(customer);
        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(productNftId);
        token.approve(address(componentInfo.tokenHandler), 1000);

        referralId = distribution.createReferral(
            distributorNftId,
            referralCode,
            UFixedLib.toUFixed(5, -2),
            maxReferrals,
            expiryAt,
            referralData);

        NftId policyNftId = product.createApplication(
            customer,
            riskId,
            1000,
            SecondsLib.toSeconds(30),
            "",
            bundleNftId,
            referralId
        );

        assertTrue(policyNftId.gtz(), "policyNftId was zero");
        assertEq(chainNft.ownerOf(policyNftId.toInt()), customer, "customer not owner of policyNftId");

        assertTrue(instance.getInstanceStore().getState(policyNftId.toKey32(POLICY())) == APPLIED(), "state not APPLIED");
        
        vm.stopPrank();

        // WHEN
        vm.startPrank(productOwner);
        product.collateralize(policyNftId, true, TimestampLib.blockTimestamp()); 

        // THEN - check 13 tokens in distribution wallet (120 premium ), 887 tokens in customer wallet, 10100 tokens in pool wallet
        assertTrue(instanceReader.getPolicyState(policyNftId) == ACTIVE(), "policy state not ACTIVE");

        IBundle.BundleInfo memory bundleInfo = instanceReader.getBundleInfo(bundleNftId);
        assertEq(bundleInfo.lockedAmount.toInt(), 1000, "unexpected lockedAmount");
        assertEq(bundleInfo.capitalAmount.toInt(), bundleBalanceInitial.toInt() + 100, "unexpected capitalAmount");
        
        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertTrue(policyInfo.activatedAt.gtz(), "activatedAt not set");
        assertTrue(policyInfo.expiredAt.gtz(), "expiredAt not set");
        
        assertEq(token.balanceOf(distribution.getWallet()), 14, "distribution balance not 14");
        assertEq(token.balanceOf(address(customer)), 886, "customer balance not 886");
        assertEq(token.balanceOf(pool.getWallet()), 10100, "pool balance not 10100");

        assertEq(instanceBundleManager.activePolicies(bundleNftId), 1, "expected one active policy");
        assertTrue(instanceBundleManager.getActivePolicy(bundleNftId, 0).eq(policyNftId), "active policy nft id in bundle manager not equal to policy nft id");

        IDistribution.DistributorInfo memory distributorInfo = instanceReader.getDistributorInfo(distributorNftId);
        assertEq(distributorInfo.numPoliciesSold, 1, "numPoliciesSold not 1");
        assertEq(distributorInfo.commissionAmount.toInt(), 3, "sumCommisions not 3");

        assertEq(instanceReader.getFeeAmount(distributionNftId).toInt(), 11, "sumDistributionOwnerFees not 11");
    }

    function test_ReferralCollateralizeMultipleWithReferral() public {
        uint256 bundleAmount = 10000;

        _setupTestData(true);
        // _setupBundle(bundleAmount);

        // GIVEN - two policies to collateralize
        vm.startPrank(registryOwner);
        token.transfer(customer, 1000);
        token.transfer(customer2, 1000);
        vm.stopPrank();

        vm.startPrank(productOwner);
        RiskId riskId = RiskIdLib.toRiskId("42x4711");
        bytes memory data = "bla di blubb";
        product.createRisk(riskId, data);
        vm.stopPrank();

        vm.startPrank(customer);

        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(productNftId);
        token.approve(address(componentInfo.tokenHandler), 1000);
        // revert("checkApprove");

        referralId = distribution.createReferral(
            distributorNftId,
            referralCode,
            UFixedLib.toUFixed(5, -2),
            maxReferrals,
            expiryAt,
            referralData);

        NftId policyNftId = product.createApplication(
            customer,
            riskId,
            1000,
            SecondsLib.toSeconds(30),
            "",
            bundleNftId,
            referralId
        );
        assertTrue(policyNftId.gtz(), "policyNftId was zero");
        assertEq(chainNft.ownerOf(policyNftId.toInt()), customer, "customer not owner of policyNftId");

        NftId policyNftId2 = product.createApplication(
            customer,
            riskId,
            1000,
            SecondsLib.toSeconds(30),
            "",
            bundleNftId,
            referralId
        );
        assertTrue(policyNftId.gtz(), "policyNftId was zero");
        assertEq(chainNft.ownerOf(policyNftId.toInt()), customer, "customer not owner of policyNftId");
        
        vm.stopPrank();

        // WHEN
        vm.startPrank(productOwner);
        product.collateralize(policyNftId, true, TimestampLib.blockTimestamp()); 
        product.collateralize(policyNftId2, true, TimestampLib.blockTimestamp()); 

        // THEN - check 13 tokens in distribution wallet (120 premium ), 887 tokens in customer wallet, 10100 tokens in pool wallet
        assertTrue(instanceReader.getPolicyState(policyNftId) == ACTIVE(), "policy state not ACTIVE");
        assertTrue(instanceReader.getPolicyState(policyNftId2) == ACTIVE(), "policy state not ACTIVE");

        IBundle.BundleInfo memory bundleInfo = instanceReader.getBundleInfo(bundleNftId);
        assertEq(bundleInfo.lockedAmount.toInt(), 2000, "lockedAmount not 1000");
        assertEq(bundleInfo.capitalAmount.toInt(), 10000 + 200, "capitalAmount not 1100");
        
        assertEq(token.balanceOf(distribution.getWallet()), 28, "distribution balance not 14");
        
        assertEq(instanceBundleManager.activePolicies(bundleNftId), 2, "expected one active policy");
        
        IDistribution.DistributorInfo memory distributorInfo = instanceReader.getDistributorInfo(distributorNftId);
        assertEq(distributorInfo.numPoliciesSold, 2, "numPoliciesSold not 2");
        assertEq(distributorInfo.commissionAmount.toInt(), 6, "commissionAmount not 6");

        assertEq(instanceReader.getFeeAmount(distributionNftId).toInt(), 22, "sumDistributionOwnerFees not 22");
        vm.stopPrank();

        // --------------------------------------------------------------
        // GIVEN one more policy to collateralize with a different referral
        vm.startPrank(distributionOwner);
        NftId distributorNftId2 = distribution.createDistributor(
            customer2,
            distributorType,
            distributorData);
        vm.stopPrank();

        vm.startPrank(customer2);
        token.approve(address(componentInfo.tokenHandler), 1000);

        ReferralId referralId2 = distribution.createReferral(
            distributorNftId2,
            "SAVE2!!!",
            UFixedLib.toUFixed(5, -2),
            maxReferrals,
            expiryAt,
            referralData);

        NftId policyNftId3 = product.createApplication(
            customer2,
            riskId,
            1000,
            SecondsLib.toSeconds(30),
            "",
            bundleNftId,
            referralId2
        );

        // WHEN 
        product.collateralize(policyNftId3, true, TimestampLib.blockTimestamp()); 

        // THEN 
        assertTrue(instanceReader.getPolicyState(policyNftId3) == ACTIVE(), "policy3 state not ACTIVE");

        bundleInfo = instanceReader.getBundleInfo(bundleNftId);
        assertEq(bundleInfo.lockedAmount.toInt(), 3000, "lockedAmount not 1000");
        assertEq(bundleInfo.capitalAmount.toInt(), 10000 + 300, "capitalAmount not 1100");
        
        assertEq(token.balanceOf(distribution.getWallet()), 42, "distribution balance not 14");
        
        assertEq(instanceBundleManager.activePolicies(bundleNftId), 3, "expected one active policy");

        assertEq(instanceReader.getFeeAmount(distributionNftId).toInt(), 33, "sumDistributionOwnerFees not 33");
        vm.stopPrank();
    }


    function _setupBundle(uint256 bundleAmount) internal {

        vm.startPrank(registryOwner);
        token.transfer(investor, bundleAmount);
        vm.stopPrank();

        vm.startPrank(investor);
        IComponents.ComponentInfo memory poolInfo = instanceReader.getComponentInfo(poolNftId);
        token.approve(address(poolInfo.tokenHandler), bundleAmount);

        // SimplePool spool = SimplePool(address(pool));
        bundleNftId = pool.createBundle(
            FeeLib.zero(), 
            bundleAmount, 
            SecondsLib.toSeconds(604800), 
            ""
        );
        vm.stopPrank();
    }

}