// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../../../lib/forge-std/src/Test.sol";

import {IBundleService} from "../../../contracts/pool/IBundleService.sol";
import {BundleSet} from "../../../contracts/instance/BundleSet.sol";
import {GifTest} from "../../base/GifTest.sol";
import {NftId, NftIdLib} from "../../../contracts/type/NftId.sol";
import {SimpleProduct} from "../../../contracts/examples/unpermissioned/SimpleProduct.sol";
import {IComponents} from "../../../contracts/instance/module/IComponents.sol";
import {IDistribution} from "../../../contracts/instance/module/IDistribution.sol";
import {IPolicy} from "../../../contracts/instance/module/IPolicy.sol";
import {Amount, AmountLib} from "../../../contracts/type/Amount.sol";
import {Fee, FeeLib} from "../../../contracts/type/Fee.sol";
import {UFixedLib} from "../../../contracts/type/UFixed.sol";
import {Seconds, SecondsLib} from "../../../contracts/type/Seconds.sol";
import {Timestamp, TimestampLib, zeroTimestamp} from "../../../contracts/type/Timestamp.sol";
import {IRisk} from "../../../contracts/instance/module/IRisk.sol";
import {RiskId, RiskIdLib, eqRiskId} from "../../../contracts/type/RiskId.sol";
import {ReferralId, ReferralLib} from "../../../contracts/type/Referral.sol";
import {ReferralId, ReferralLib} from "../../../contracts/type/Referral.sol";
import {APPLIED, COLLATERALIZED, CLOSED, DECLINED, PAID, EXPECTED} from "../../../contracts/type/StateId.sol";
import {POLICY} from "../../../contracts/type/ObjectType.sol";
import {DistributorType} from "../../../contracts/type/DistributorType.sol";
import {IPolicyService} from "../../../contracts/product/IPolicyService.sol";
import {PolicyServiceLib} from "../../../contracts/product/PolicyServiceLib.sol";

// solhint-disable func-name-mixedcase
contract PolicyServiceLibTest is GifTest {

    function test_PolicyServiceLib_policyIsActive() public {
        // GIVEN
        vm.warp(100);
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
        assertTrue(instance.getInstanceStore().getState(policyNftId.toKey32(POLICY())) == APPLIED(), "state not APPLIED");

        vm.stopPrank();

        // WHEN - collateralize application
        bool requirePremiumPayment = false;
        product.createPolicy(policyNftId, requirePremiumPayment, TimestampLib.zero()); 

        // THEN - activatedAt is 0
        assertFalse(PolicyServiceLib.policyIsActive(instanceReader, policyNftId));

        vm.warp(1);

        Timestamp activateAt = TimestampLib.blockTimestamp().addSeconds(SecondsLib.toSeconds(10));
        product.activate(policyNftId, activateAt);
        
        // THEN - activatedAt is 11, expiredAt is 41
        assertFalse(PolicyServiceLib.policyIsActive(instanceReader, policyNftId));

        vm.warp(11);

        assertTrue(PolicyServiceLib.policyIsActive(instanceReader, policyNftId));

        vm.warp(41);

        assertFalse(PolicyServiceLib.policyIsActive(instanceReader, policyNftId));

        vm.warp(42);

        assertFalse(PolicyServiceLib.policyIsActive(instanceReader, policyNftId));
    }

    function _configureProduct(uint bundleCapital) internal {
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

        vm.startPrank(registryOwner);
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