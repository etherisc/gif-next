// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {GifTest} from "../../base/GifTest.sol";
import {NftId} from "../../../contracts/type/NftId.sol";
import {IComponents} from "../../../contracts/instance/module/IComponents.sol";
import {Amount, AmountLib} from "../../../contracts/type/Amount.sol";
import {Fee, FeeLib} from "../../../contracts/type/Fee.sol";
import {UFixedLib} from "../../../contracts/type/UFixed.sol";
import {Seconds, SecondsLib} from "../../../contracts/type/Seconds.sol";
import {Timestamp, TimestampLib} from "../../../contracts/type/Timestamp.sol";
import {RiskId} from "../../../contracts/type/RiskId.sol";
import {ReferralId, ReferralLib} from "../../../contracts/type/Referral.sol";
import {APPLIED} from "../../../contracts/type/StateId.sol";
import {POLICY} from "../../../contracts/type/ObjectType.sol";
import {PolicyServiceLib} from "../../../contracts/product/PolicyServiceLib.sol";
import {ClaimId} from "../../../contracts/type/ClaimId.sol";
import {PayoutId} from "../../../contracts/type/PayoutId.sol";

// solhint-disable func-name-mixedcase
contract PolicyServiceLibTest is GifTest {

    function setUp() public override {
        super.setUp();

        _prepareProduct();
        _configureProduct(DEFAULT_BUNDLE_CAPITALIZATION);
    }

    function test_policyServiceLibPolicyIsActive() public {
        // GIVEN
        vm.startPrank(productOwner);

        // create test specific risk
        bytes memory data = "bla di blubb";
        RiskId riskId = product.createRisk("42x4711", data);

        // crete application
        uint256 sumInsuredAmount = 1000;
        Seconds lifetime = SecondsLib.toSeconds(30);
        bytes memory applicationData = "";
        ReferralId referralId = ReferralLib.zero();
        NftId policyNftId = product.createApplication(
            customer,
            riskId,
            sumInsuredAmount,
            lifetime,
            applicationData,
            bundleNftId,
            referralId
        );

        assertTrue(policyNftId.gtz(), "policyNftId was zero");
        assertEq(chainNft.ownerOf(policyNftId.toInt()), customer, "customer not owner of policyNftId");
        assertTrue(instance.getProductStore().getState(policyNftId.toKey32(POLICY())) == APPLIED(), "state not APPLIED");

        vm.stopPrank();

        // WHEN - collateralize application
        bool requirePremiumPayment = false;
        product.createPolicy(policyNftId, requirePremiumPayment, TimestampLib.zero()); 

        // THEN - activatedAt is 0
        assertFalse(PolicyServiceLib.policyIsActive(instanceReader, policyNftId));

        vm.warp(block.timestamp + 1);

        uint256 currentTime = block.timestamp;
        Timestamp activateAt = TimestampLib.current().addSeconds(SecondsLib.toSeconds(10));
        Timestamp expiryAt = activateAt.addSeconds(lifetime);

        product.activate(policyNftId, activateAt);
        
        // THEN - activatedAt is 11, expiredAt is 41
        assertEq(activateAt.toInt(), currentTime + 10, "unexpected activateAt");
        assertEq(expiryAt.toInt(), currentTime + 40, "unexpected expiryAt");
        assertFalse(PolicyServiceLib.policyIsActive(instanceReader, policyNftId));

        vm.warp(activateAt.toInt());

        assertTrue(PolicyServiceLib.policyIsActive(instanceReader, policyNftId));

        vm.warp(expiryAt.toInt() - 1);
        assertTrue(PolicyServiceLib.policyIsActive(instanceReader, policyNftId));

        vm.warp(expiryAt.toInt());
        assertFalse(PolicyServiceLib.policyIsActive(instanceReader, policyNftId));

        vm.warp(expiryAt.toInt() + 1);
        assertFalse(PolicyServiceLib.policyIsActive(instanceReader, policyNftId));
    }


    function test_policyServiceLibPolicyIsCloseableNoPayout() public {
        // GIVEN
        vm.startPrank(productOwner);

        // create test specific risk
        bytes memory data = "bla di blubb";
        RiskId riskId = product.createRisk("42x4711", data);

        // crete application
        uint256 sumInsuredAmount = 1000;
        Seconds lifetime = SecondsLib.toSeconds(30);
        bytes memory applicationData = "";
        ReferralId referralId = ReferralLib.zero();
        NftId policyNftId = product.createApplication(
            customer,
            riskId,
            sumInsuredAmount,
            lifetime,
            applicationData,
            bundleNftId,
            referralId
        );

        assertTrue(policyNftId.gtz(), "policyNftId was zero");
        assertEq(chainNft.ownerOf(policyNftId.toInt()), customer, "customer not owner of policyNftId");
        assertTrue(instance.getProductStore().getState(policyNftId.toKey32(POLICY())) == APPLIED(), "state not APPLIED");

        vm.stopPrank();

        // WHEN - collateralize application
        bool requirePremiumPayment = false;
        product.createPolicy(policyNftId, requirePremiumPayment, TimestampLib.zero()); 

        // THEN - activatedAt is 0
        assertFalse(PolicyServiceLib.policyIsCloseable(instanceReader, policyNftId));

        vm.warp(block.timestamp + 1);

        uint256 currentTime = block.timestamp;
        Timestamp activateAt = TimestampLib.current().addSeconds(SecondsLib.toSeconds(10));
        Timestamp expiryAt = activateAt.addSeconds(lifetime);

        product.activate(policyNftId, activateAt);
        
        // THEN - activatedAt is 11, expiredAt is 41
        vm.warp(activateAt.toInt());
        assertFalse(PolicyServiceLib.policyIsCloseable(instanceReader, policyNftId));

        vm.warp(expiryAt.toInt());
        assertTrue(PolicyServiceLib.policyIsCloseable(instanceReader, policyNftId));
    }


    function test_policyServiceLibPolicyIsCloseableWithPayout() public {
        // GIVEN
        vm.startPrank(productOwner);

        // create test specific risk
        bytes memory data = "bla di blubb";
        RiskId riskId = product.createRisk("42x4711", data);

        // crete application
        uint256 sumInsuredAmount = 1000;
        Seconds lifetime = SecondsLib.toSeconds(30);
        bytes memory applicationData = "";
        ReferralId referralId = ReferralLib.zero();
        NftId policyNftId = product.createApplication(
            customer,
            riskId,
            sumInsuredAmount,
            lifetime,
            applicationData,
            bundleNftId,
            referralId
        );

        assertTrue(policyNftId.gtz(), "policyNftId was zero");
        assertEq(chainNft.ownerOf(policyNftId.toInt()), customer, "customer not owner of policyNftId");
        assertTrue(instance.getProductStore().getState(policyNftId.toKey32(POLICY())) == APPLIED(), "state not APPLIED");

        vm.stopPrank();

        // WHEN - collateralize application
        uint256 currentTime = block.timestamp;
        Timestamp activateAt = TimestampLib.current().addSeconds(SecondsLib.toSeconds(10));
        Timestamp expiryAt = activateAt.addSeconds(lifetime);

        bool requirePremiumPayment = false;
        product.createPolicy(policyNftId, requirePremiumPayment, activateAt); 

        // THEN 
        assertFalse(PolicyServiceLib.policyIsCloseable(instanceReader, policyNftId), "policy can be closed (but should not be closeable)");

        // THEN - set time to a point where a claim can be submitted
        vm.warp(activateAt.toInt() + lifetime.toInt() / 2);

        assertFalse(PolicyServiceLib.policyIsCloseable(instanceReader, policyNftId));

        Amount claimAmount = AmountLib.toAmount(500);
        ClaimId claimId = product.submitClaim(policyNftId, claimAmount, "");
        product.confirmClaim(policyNftId, claimId, claimAmount, "");
        PayoutId payoutId = product.createPayout(policyNftId, claimId, claimAmount, "");
        product.processPayout(policyNftId, payoutId);

        assertFalse(PolicyServiceLib.policyIsCloseable(instanceReader, policyNftId));

        // THEN - set time to a later time that is still within claimable period of policy
        vm.warp(activateAt.toInt() + 2 * lifetime.toInt() / 3);

        // 2nd claim will push policy payout amount to policy sum insured amount (1000 = 500 + 500)
        ClaimId claimId2 = product.submitClaim(policyNftId, claimAmount, "");
        product.confirmClaim(policyNftId, claimId2, claimAmount, "");
        PayoutId payoutId2 = product.createPayout(policyNftId, claimId2, claimAmount, "");
        product.processPayout(policyNftId, payoutId2);

        assertTrue(PolicyServiceLib.policyIsCloseable(instanceReader, policyNftId));
    }

    function _configureProduct(uint256 bundleCapital) internal {
        vm.startPrank(distributionOwner);
        Fee memory distributionFee = FeeLib.toFee(UFixedLib.zero(), 10);
        Fee memory minDistributionOwnerFee = FeeLib.toFee(UFixedLib.zero(), 10);
        distribution.setFees(
            distributionFee, 
            minDistributionOwnerFee);
        vm.stopPrank();

        vm.startPrank(poolOwner);
        Fee memory poolFee = FeeLib.toFee(UFixedLib.zero(), 10);
        pool.setFees(
            poolFee, 
            FeeLib.zero(), // staking fees
            FeeLib.zero()); // performance fees
        vm.stopPrank();

        vm.startPrank(tokenIssuer);
        token.transfer(investor, bundleCapital);
        vm.stopPrank();

        vm.startPrank(investor);
        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(poolNftId);
        token.approve(address(componentInfo.tokenHandler), bundleCapital);

        Fee memory bundleFee = FeeLib.toFee(UFixedLib.zero(), 10);
        (bundleNftId,) = pool.createBundle(
            bundleFee, 
            bundleCapital, 
            SecondsLib.toSeconds(604800), 
            ""
        );
        vm.stopPrank();
    }
}