// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {TestGifBase} from "./base/TestGifBase.sol";
import {IPolicy} from "../contracts/instance/module/policy/IPolicy.sol";
import {IPool} from "../contracts/instance/module/pool/IPoolModule.sol";
import {IBundle} from "../contracts/instance/module/bundle/IBundle.sol";
import {TokenHandler} from "../contracts/instance/module/treasury/TokenHandler.sol";
import {APPLIED, UNDERWRITTEN, ACTIVE} from "../contracts/types/StateId.sol";
import {NftId, toNftId} from "../contracts/types/NftId.sol";
import {Timestamp, blockTimestamp, zeroTimestamp} from "../contracts/types/Timestamp.sol";
import {Fee, FeeLib} from "../contracts/types/Fee.sol";
import {ReferralId, ReferralIdLib} from "../contracts/types/ReferralId.sol";
import {UFixed, UFixedMathLib} from "../contracts/types/UFixed.sol";
import {IComponent} from "../contracts/instance/module/component/IComponent.sol";
import {IComponentOwnerService} from "../contracts/instance/service/IComponentOwnerService.sol";
import {ITreasuryModule} from "../contracts/instance/module/treasury/ITreasury.sol";

contract TestApplicationCreate is TestGifBase {
    uint256 public sumInsuredAmount = 1000 * 10 ** 6;
    uint256 public lifetime = 365 * 24 * 3600;
    uint256 public premiumAmount = calculateExpectedPremium();
    ReferralId public referralId = ReferralIdLib.zeroReferralId();

    function calculateExpectedPremium() public view returns (uint256 expectedPremiumAmount) {
        uint256 netPremiumAmount = sumInsuredAmount / 10;

        Fee memory totalFee = FeeLib.percentageFee(0
            + initialProductFeePercentage
            + initialPoolFeePercentage
            + initialBundleFeePercentage
            + initialDistributionFeePercentage            
        );
        (uint256 feeAmount,) = FeeLib.calculateFee(totalFee, netPremiumAmount);

        return netPremiumAmount + feeAmount;
    }

    function testApplicationCreateSimple() public {
        vm.prank(customer);
        NftId policyNftId = product.applyForPolicy(
            sumInsuredAmount,
            lifetime,
            bundleNftId,
            referralId
        );

        assertNftId(policyNftId, toNftId(113133705), "policy id not 113133705");
        assertEq(
            registry.getOwner(policyNftId),
            customer,
            "customer not policy owner"
        );

        IPolicy.PolicyInfo memory info = instance.getPolicyInfo(policyNftId);
        assertEq(
            instance.getPolicyState(policyNftId).toInt(),
            APPLIED().toInt(),
            "policy state not applied"
        );

        assertEq(
            info.sumInsuredAmount,
            sumInsuredAmount,
            "wrong sum insured amount"
        );

        assertEq(info.premiumAmount, premiumAmount, "wrong premium amount");
        assertEq(info.lifetime, lifetime, "wrong lifetime");

        assertTrue(info.activatedAt == zeroTimestamp(), "wrong activated at");
        assertTrue(info.expiredAt == zeroTimestamp(), "wrong expired at");
        assertTrue(info.closedAt == zeroTimestamp(), "wrong closed at");
    }

    function testApplicationCreateAndUnderwrite() public {
        vm.prank(customer);
        NftId policyNftId = product.applyForPolicy(
            sumInsuredAmount,
            lifetime,
            bundleNftId,
            referralId
        );

        // get bundle details before underwriting (and token transfer)
        IBundle.BundleInfo memory infoBefore = instance.getBundleInfo(bundleNftId);

        // underwrite and don't collect premium and don't activate
        bool requirePremiumPayment = false;
        Timestamp activateAt = zeroTimestamp();
        product.underwrite(policyNftId, requirePremiumPayment, activateAt);

        IBundle.BundleInfo memory infoAfter = instance.getBundleInfo(bundleNftId);
        IPolicy.PolicyInfo memory policyInfo = instance.getPolicyInfo(policyNftId);

        assertEq(
            instance.getPolicyState(policyNftId).toInt(),
            UNDERWRITTEN().toInt(),
            "policy state not underwritten"
        );

        // solhint-disable-next-line not-rely-on-time
        assertTrue(policyInfo.activatedAt == zeroTimestamp(), "wrong activated at");
        assertTrue(policyInfo.expiredAt == zeroTimestamp(), "wrong expired at");
        assertTrue(policyInfo.closedAt == zeroTimestamp(), "wrong closed at");

        assertEq(infoBefore.lockedAmount, 0, "capital locked not 0");
        assertEq(
            infoAfter.lockedAmount,
            sumInsuredAmount,
            "capital locked not sum insured"
        );
    }

    function testUnderwriteAndActivatePolicyCollectPremiumNoFee() public {
        // set fees to zeroFee
        Fee memory zeroFee = FeeLib.zeroFee();
        vm.prank(productOwner);
        product.setFees(zeroFee, zeroFee);

        // check updated policy fee
        ITreasuryModule treasuryModule = ITreasuryModule(address(instance));
        ITreasuryModule.TreasuryInfo memory info = treasuryModule
            .getTreasuryInfo(product.getNftId());
        assertTrue(
            FeeLib.feeIsSame(info.productFee, FeeLib.zeroFee()),
            "updated productFee not zeroFee"
        );
        assertTrue(
            FeeLib.feeIsSame(info.processingFee, FeeLib.zeroFee()),
            "updated processingFee not zeroFee"
        );

        vm.prank(customer);
        NftId policyNftId = product.applyForPolicy(
            sumInsuredAmount,
            lifetime,
            bundleNftId,
            referralId
        );

        // check bookkeeping before collecting premium
        IPolicy.PolicyInfo memory infoBefore = instance.getPolicyInfo(
            policyNftId
        );

        assertEq(
            infoBefore.premiumAmount,
            premiumAmount,
            "unexpected policy premium amount"
        );
        assertEq(
            infoBefore.premiumPaidAmount,
            0,
            "unexpected policy premium paid amount"
        );
        assertEq(
            token.balanceOf(pool.getWallet()),
            initialCapitalAmount,
            "unexpected pool balance"
        );

        // prepare customer to pay premium amount
        vm.prank(instanceOwner);
        fundAccount(customer, premiumAmount);

        TokenHandler tokenHandler = instance.getTokenHandler(
            product.getNftId()
        );
        address tokenHandlerAddress = address(tokenHandler);

        vm.prank(customer);
        token.approve(tokenHandlerAddress, premiumAmount);

        assertEq(
            token.balanceOf(customer),
            premiumAmount,
            "customer balance not premium"
        );
        assertEq(
            token.allowance(customer, tokenHandlerAddress),
            premiumAmount,
            "customer token approval not premium"
        );

        // underwrite, collect premium and activate policy
        bool requirePremiumPayment = true;
        Timestamp activateAt = blockTimestamp();
        product.underwrite(
            policyNftId,
            requirePremiumPayment,
            activateAt);

        IPolicy.PolicyInfo memory policyInfo = instance.getPolicyInfo(policyNftId);
        assertEq(
            instance.getPolicyState(policyNftId).toInt(),
            ACTIVE().toInt(),
            "policy state not active"
        );

        // solhint-disable-next-line not-rely-on-time
        assertTrue(policyInfo.activatedAt == activateAt, "wrong activated at");
        assertTrue(
            policyInfo.expiredAt ==
            activateAt.addSeconds(policyInfo.lifetime),
            "wrong expired at"
        );
        assertTrue(policyInfo.closedAt == zeroTimestamp(), "wrong closed at");
        assertEq(
            policyInfo.premiumAmount,
            premiumAmount,
            "unexpected policy premium amount (after)"
        );
        assertEq(
            policyInfo.premiumPaidAmount,
            premiumAmount,
            "unexpected policy premium paid amount (after)"
        );

        // TODO needs proper premium collection and fee distribution
        // to be implemented
        premiumAmount = calculateExpectedPremium();
        assertEq(
            token.balanceOf(pool.getWallet()),
            initialCapitalAmount + premiumAmount,
            "unexpected pool balance (after)"
        );
    }

    function testUnderwriteAndActivatePolicyCollectPremiumWithFee() public {
        // check initial policy fee
        ITreasuryModule treasuryModule = ITreasuryModule(address(instance));
        ITreasuryModule.TreasuryInfo memory info = treasuryModule
            .getTreasuryInfo(product.getNftId());

        assertTrue(
            FeeLib.feeIsSame(info.productFee, product.getProductFee()),
            "unexpected initial productFee"
        );

        assertTrue(
            FeeLib.feeIsSame(info.processingFee, product.getProcessingFee()),
            "unexpected initial processingFee"
        );

        // updated policy fee (15% + 20 cents)
        UFixed fractionalFee = UFixedMathLib.toUFixed(15, -2);
        uint256 fixedFee = 2 * 10 ** (token.decimals() - 1);
        Fee memory productFee = FeeLib.toFee(fractionalFee, fixedFee);

        Fee memory zeroFee = FeeLib.zeroFee();
        vm.prank(productOwner);
        product.setFees(productFee, zeroFee);

        // check updated policy fee
        info = treasuryModule.getTreasuryInfo(product.getNftId());
        assertTrue(
            FeeLib.feeIsSame(info.productFee, productFee),
            "updated policyFee not 15% + 20 cents"
        );
        assertTrue(
            FeeLib.feeIsSame(info.processingFee, FeeLib.zeroFee()),
            "updated processingFee not zeroFee"
        );

        bytes memory applicationData = "";
        premiumAmount = product.calculatePremium(
            sumInsuredAmount,
            product.getDefaultRiskId(),
            lifetime,
            applicationData,
            referralId,
            bundleNftId
        );

        // create appliation
        vm.prank(customer);
        NftId policyNftId = product.applyForPolicy(
            sumInsuredAmount,
            lifetime,
            bundleNftId,
            referralId
        );

        // prepare customer to pay premium amount
        vm.prank(instanceOwner);
        fundAccount(customer, premiumAmount);

        TokenHandler tokenHandler = instance.getTokenHandler(
            product.getNftId()
        );
        address tokenHandlerAddress = address(tokenHandler);

        vm.prank(customer);
        token.approve(tokenHandlerAddress, premiumAmount);

        // underwrite, collect premium, and activate
        bool requirePremiumPayment = true;
        Timestamp activateAt = blockTimestamp();
        product.underwrite(
            policyNftId,
            requirePremiumPayment,
            activateAt);

        IPolicy.PolicyInfo memory policyInfo = instance.getPolicyInfo(policyNftId);
        assertEq(
            policyInfo.premiumAmount,
            premiumAmount,
            "unexpected policy premium amount (after)"
        );
        assertEq(
            policyInfo.premiumPaidAmount,
            premiumAmount,
            "unexpected policy premium paid amount (after)"
        );

        (
            uint256 productFeeAmount,
            uint256 netPremiumAmount
        ) = instance.calculateFeeAmount(premiumAmount, productFee);

        assertEq(
            token.balanceOf(product.getWallet()),
            productFeeAmount,
            "unexpected product balance (after)"
        );
        assertEq(
            token.balanceOf(pool.getWallet()),
            initialCapitalAmount + netPremiumAmount,
            "unexpected pool balance (after)"
        );

        // check bundle book keeping after collecting premium
        IBundle.BundleInfo memory bundleInfo = instance.getBundleInfo(
            bundleNftId
        );
        assertEq(
            bundleInfo.lockedAmount,
            sumInsuredAmount,
            "locked amount in bundle not sum insured"
        );
        assertEq(
            bundleInfo.balanceAmount,
            initialCapitalAmount + netPremiumAmount,
            "bundle balance not initial capital + net premium"
        );
    }
}
