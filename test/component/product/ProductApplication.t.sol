// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../../../lib/forge-std/src/Test.sol";

import {IApplicationService} from "../../../contracts/product/IApplicationService.sol";
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

contract ProductApplicationTest is GifTest {

    Seconds public sec30;

    mapping(address account => uint previousBalance) public pb;

    function setUp() public override {
        super.setUp();

        _prepareProduct();
        _configureProduct(DEFAULT_BUNDLE_CAPITALIZATION);
        
        sec30 = SecondsLib.toSeconds(30);
    }

    function test_productCreateApplication() public {

        Fee memory productFee = FeeLib.toFee(UFixedLib.zero(), 10);

        vm.startPrank(productOwner);
        product.setFees(productFee, FeeLib.zero());

        bytes memory data = "bla di blubb";
        SimpleProduct dproduct = SimpleProduct(address(product));
        RiskId riskId = dproduct.createRisk("42x4711", data);

        NftId policyNftId = dproduct.createApplication(
            customer,
            riskId,
            1000,
            SecondsLib.toSeconds(30),
            "",
            bundleNftId,
            ReferralLib.zero()
        );

        assertTrue(policyNftId.gtz(), "policyNftId was zero");
        assertEq(chainNft.ownerOf(policyNftId.toInt()), customer, "customer not owner of policyNftId");

        assertTrue(instance.getInstanceStore().getState(policyNftId.toKey32(POLICY())) == APPLIED(), "state not APPLIED");

        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertTrue(eqRiskId(policyInfo.riskId, riskId), "riskId not set");
        assertEq(policyInfo.sumInsuredAmount.toInt(), 1000, "sumInsuredAmount not set");
        assertEq(policyInfo.lifetime.toInt(), 30, "lifetime not set");
        assertTrue(policyInfo.bundleNftId.eq(bundleNftId), "bundleNftId not set");        
    }

    function test_Product_createApplication_invalidRisk() public {
        vm.startPrank(productOwner);

        RiskId riskId = product.createRisk("42x4711", "bla di blubb");
        RiskId riskId2 = RiskIdLib.toRiskId(productNftId, "42x4712");
        Seconds lifetime = SecondsLib.toSeconds(30);
        ReferralId noReferral = ReferralLib.zero();
        Amount sumInsured = AmountLib.toAmount(1000);
        Amount premium = AmountLib.toAmount(100);

        vm.expectRevert(abi.encodeWithSelector(
            IApplicationService.ErrorApplicationServiceRiskUnknown.selector, 
            riskId2,
            productNftId));
        NftId policyNftId = product.createApplication2(
            customer,
            riskId2,
            sumInsured,
            premium,
            lifetime,
            "",
            bundleNftId,
            noReferral
        );
    }

    function test_Product_createApplication_lockedRisk() public {
        vm.startPrank(productOwner);

        RiskId riskId = product.createRisk("42x4711", "bla di blubb");
        Seconds lifetime = SecondsLib.toSeconds(30);
        ReferralId noReferral = ReferralLib.zero();
        Amount sumInsured = AmountLib.toAmount(1000);
        Amount premium = AmountLib.toAmount(100);

        product.setRiskLocked(riskId, true);

        vm.expectRevert(abi.encodeWithSelector(
            IApplicationService.ErrorApplicationServiceRiskLocked.selector, 
            riskId,
            productNftId));
        NftId policyNftId = product.createApplication2(
            customer,
            riskId,
            sumInsured,
            premium,
            lifetime,
            "",
            bundleNftId,
            noReferral
        );
    }

    function test_productDeclineApplication() public {
        // GIVEN

        vm.startPrank(productOwner);
        bytes memory data = "bla di blubb";
        RiskId riskId = product.createRisk("42x4711", data);
        vm.stopPrank();

        vm.startPrank(customer);

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

        vm.stopPrank();

        assertTrue(policyNftId.gtz(), "policyNftId was zero");
        assertEq(chainNft.ownerOf(policyNftId.toInt()), customer, "customer not owner of policyNftId");
        assertTrue(instance.getInstanceStore().getState(policyNftId.toKey32(POLICY())) == APPLIED(), "state not APPLIED");
        
        vm.startPrank(productOwner);
        
        // THEN
        vm.expectEmit();
        emit IPolicyService.LogPolicyServicePolicyDeclined(policyNftId);

        // WHEN
        product.decline(policyNftId);

        // THEN 
        assertTrue(instanceReader.getPolicyState(policyNftId) == DECLINED(), "policy state not DECLINED");
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