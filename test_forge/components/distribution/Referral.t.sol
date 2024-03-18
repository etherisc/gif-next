// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ACTIVE, APPLIED} from "../../../contracts/types/StateId.sol";
import {console} from "../../../lib/forge-std/src/Test.sol";
import {Fee, FeeLib} from "../../../contracts/types/Fee.sol";
import {IBundle} from "../../../contracts/instance/module/IBundle.sol";
import {IDistribution} from "../../../contracts/instance/module/IDistribution.sol";
import {IPolicy} from "../../../contracts/instance/module/IPolicy.sol";
import {ISetup} from "../../../contracts/instance/module/ISetup.sol";
import {NftId, NftIdLib} from "../../../contracts/types/NftId.sol";
import {POLICY} from "../../../contracts/types/ObjectType.sol";
import {POOL_OWNER_ROLE, PRODUCT_OWNER_ROLE} from "../../../contracts/types/RoleId.sol";
import {ReferralLib} from "../../../contracts/types/Referral.sol";
import {ReferralTestBase} from "./ReferralTestBase.sol";
import {RiskId, RiskIdLib} from "../../../contracts/types/RiskId.sol";
import {Seconds, SecondsLib} from "../../../contracts/types/Seconds.sol";
import {SimpleDistribution} from "../../mock/SimpleDistribution.sol";
import {SimplePool} from "../../mock/SimplePool.sol";
import {SimpleProduct} from "../../mock/SimpleProduct.sol";
import {TimestampLib} from "../../../contracts/types/Timestamp.sol";
import {UFixed, UFixedLib} from "../../../contracts/types/UFixed.sol";

contract ReferralTest is ReferralTestBase {
    using NftIdLib for NftId;

    function test_Distribution_referralIsValid_true() public {
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

    function test_Referral_applyAndUnderwriteWithReferral() public {
        _setupTestData(true);
        _setupPoolAndProduct();

        // GIVEN
        vm.startPrank(registryOwner);
        token.transfer(customer, 1000);
        vm.stopPrank();

        vm.startPrank(productOwner);

        RiskId riskId = RiskIdLib.toRiskId("42x4711");
        bytes memory data = "bla di blubb";
        SimpleProduct dproduct = SimpleProduct(address(product));
        dproduct.createRisk(riskId, data);

        vm.stopPrank();

        vm.startPrank(customer);

        ISetup.ProductSetupInfo memory productSetupInfo = instanceReader.getProductSetupInfo(productNftId);
        token.approve(address(productSetupInfo.tokenHandler), 1000);
        // revert("checkApprove");

        SimpleDistribution sdistribution = SimpleDistribution(address(distribution));
        referralId = sdistribution.createReferral(
            distributorNftId,
            referralCode,
            UFixedLib.toUFixed(5, -2),
            maxReferrals,
            expiryAt,
            referralData);

        NftId policyNftId = dproduct.createApplication(
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

        assertTrue(instance.getState(policyNftId.toKey32(POLICY())) == APPLIED(), "state not APPLIED");
        
        vm.stopPrank();

        // WHEN
        vm.startPrank(productOwner);
        dproduct.underwrite(policyNftId, true, TimestampLib.blockTimestamp()); 

        // THEN - check 13 tokens in distribution wallet (120 premium ), 887 tokens in customer wallet, 10100 tokens in pool wallet
        assertTrue(instanceReader.getPolicyState(policyNftId) == ACTIVE(), "policy state not ACTIVE");

        IBundle.BundleInfo memory bundleInfo = instanceReader.getBundleInfo(bundleNftId);
        assertEq(bundleInfo.lockedAmount, 1000, "lockedAmount not 1000");
        assertEq(bundleInfo.balanceAmount, 10000 + 100, "balanceAmount not 1100");
        
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
        assertEq(distributorInfo.sumCommisions, 3, "sumCommisions not 3");

        ISetup.DistributionSetupInfo memory distributionSetupInfo = instanceReader.getDistributionSetupInfo(distributionNftId);
        assertEq(distributionSetupInfo.sumDistributionOwnerFees, 11, "sumDistributionOwnerFees not 11");
    }

    function _setupPoolAndProduct() internal {
        vm.startPrank(instanceOwner);
        instanceAccessManager.grantRole(POOL_OWNER_ROLE(), poolOwner);
        instanceAccessManager.grantRole(PRODUCT_OWNER_ROLE(), productOwner);
        vm.stopPrank();

        vm.startPrank(poolOwner);
        pool = new SimplePool(
            address(registry),
            instanceNftId,
            address(token),
            false,
            false,
            UFixedLib.toUFixed(1),
            UFixedLib.toUFixed(1),
            poolOwner
        );
        poolNftId = poolService.register(address(pool));
        vm.stopPrank();
    
        vm.startPrank(productOwner);
        product = new SimpleProduct(
            address(registry),
            instanceNftId,
            address(token),
            false,
            address(pool), 
            address(distribution),
            FeeLib.zeroFee(),
            FeeLib.zeroFee(),
            productOwner
        );
        
        productNftId = productService.register(address(product));
        vm.stopPrank();

        vm.startPrank(registryOwner);
        token.transfer(investor, 10000);
        vm.stopPrank();

        vm.startPrank(investor);
        ISetup.PoolSetupInfo memory poolSetupInfo = instanceReader.getPoolSetupInfo(poolNftId);
        token.approve(address(poolSetupInfo.tokenHandler), 10000);

        SimplePool spool = SimplePool(address(pool));
        bundleNftId = spool.createBundle(
            FeeLib.zeroFee(), 
            10000, 
            SecondsLib.toSeconds(604800), 
            ""
        );
        vm.stopPrank();
    }

}