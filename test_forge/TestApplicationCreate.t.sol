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
import {UFixed, UFixedMathLib} from "../contracts/types/UFixed.sol";
import {IComponent} from "../contracts/instance/module/component/IComponent.sol";
import {IComponentOwnerService} from "../contracts/instance/service/IComponentOwnerService.sol";
import {ITreasuryModule} from "../contracts/instance/module/treasury/ITreasury.sol";

contract TestApplicationCreate is TestGifBase {
    uint256 public sumInsuredAmount = 1000 * 10 ** 6;
    uint256 public premiumAmount = 110 * 10 ** 6;
    uint256 public lifetime = 365 * 24 * 3600;

    function testApplicationCreateSimple() public {
        vm.prank(customer);
        NftId policyNftId = product.applyForPolicy(
            sumInsuredAmount,
            premiumAmount,
            lifetime,
            bundleNftId
        );

        assertNftId(policyNftId, toNftId(103133705), "policy id not 103133705");
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
            premiumAmount,
            lifetime,
            bundleNftId
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
        ITreasuryModule.ProductSetup memory setup = treasuryModule
            .getProductSetup(product.getNftId());
        assertTrue(
            FeeLib.feeIsSame(setup.policyFee, FeeLib.zeroFee()),
            "updated policyFee not zeroFee"
        );
        assertTrue(
            FeeLib.feeIsSame(setup.processingFee, FeeLib.zeroFee()),
            "updated processingFee not zeroFee"
        );

        vm.prank(customer);
        NftId policyNftId = product.applyForPolicy(
            sumInsuredAmount,
            premiumAmount,
            lifetime,
            bundleNftId
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

        IPolicy.PolicyInfo memory info = instance.getPolicyInfo(policyNftId);
        assertEq(
            instance.getPolicyState(policyNftId).toInt(),
            ACTIVE().toInt(),
            "policy state not active"
        );

        // solhint-disable-next-line not-rely-on-time
        assertTrue(info.activatedAt == activateAt, "wrong activated at");
        assertTrue(
            info.expiredAt ==
            activateAt.addSeconds(info.lifetime),
            "wrong expired at"
        );
        assertTrue(info.closedAt == zeroTimestamp(), "wrong closed at");
        assertEq(
            info.premiumAmount,
            premiumAmount,
            "unexpected policy premium amount (after)"
        );
        assertEq(
            info.premiumPaidAmount,
            premiumAmount,
            "unexpected policy premium paid amount (after)"
        );
        assertEq(
            token.balanceOf(pool.getWallet()),
            initialCapitalAmount + premiumAmount,
            "unexpected pool balance (after)"
        );
    }

    function testUnderwriteAndActivatePolicyCollectPremiumWithFee() public {
        // check initial policy fee
        ITreasuryModule treasuryModule = ITreasuryModule(address(instance));
        ITreasuryModule.ProductSetup memory setup = treasuryModule
            .getProductSetup(product.getNftId());
        Fee memory expectedInitialPolicyFee = FeeLib.zeroFee();

        assertTrue(
            FeeLib.feeIsSame(setup.policyFee, expectedInitialPolicyFee),
            "initial policyFee not zeroFee"
        );
        assertTrue(
            FeeLib.feeIsZero(setup.processingFee),
            "initial processingFee not zeroFee"
        );

        // updated policy fee (15% + 20 cents)
        UFixed fractionalFee = UFixedMathLib.toUFixed(15, -2);
        uint256 fixedFee = 2 * 10 ** (token.decimals() - 1);
        Fee memory policyFee = FeeLib.toFee(fractionalFee, fixedFee);

        Fee memory zeroFee = FeeLib.zeroFee();
        vm.prank(productOwner);
        product.setFees(policyFee, zeroFee);

        // check updated policy fee
        setup = treasuryModule.getProductSetup(product.getNftId());
        assertTrue(
            FeeLib.feeIsSame(setup.policyFee, policyFee),
            "updated policyFee not 15% + 20 cents"
        );
        assertTrue(
            FeeLib.feeIsSame(setup.processingFee, FeeLib.zeroFee()),
            "updated processingFee not zeroFee"
        );

        // create appliation
        vm.prank(customer);
        NftId policyNftId = product.applyForPolicy(
            sumInsuredAmount,
            premiumAmount,
            lifetime,
            bundleNftId
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

        IPolicy.PolicyInfo memory info = instance.getPolicyInfo(policyNftId);
        assertEq(
            info.premiumAmount,
            premiumAmount,
            "unexpected policy premium amount (after)"
        );
        assertEq(
            info.premiumPaidAmount,
            premiumAmount,
            "unexpected policy premium paid amount (after)"
        );

        (
            uint256 policyFeeAmount,
            uint256 netPremiumAmount
        ) = instance.calculateFeeAmount(premiumAmount, policyFee);

        assertEq(
            token.balanceOf(product.getWallet()),
            policyFeeAmount,
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
