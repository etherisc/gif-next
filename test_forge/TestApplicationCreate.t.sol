// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {TestGifBase} from "./TestGifBase.sol";
import {IPolicy} from "../contracts/instance/policy/IPolicy.sol";
import {IPool} from "../contracts/instance/pool/IPoolModule.sol";
import {TokenHandler} from "../contracts/instance/treasury/TokenHandler.sol";
import {APPLIED, ACTIVE} from "../contracts/types/StateId.sol";
import {NftId, toNftId} from "../contracts/types/NftId.sol";
import {blockTimestamp, zeroTimestamp} from "../contracts/types/Timestamp.sol";
import {Fee, toFee, zeroFee, feeIsZero, feeIsSame} from "../contracts/types/Fee.sol";
import {UFixed, UFixedMathLib} from "../contracts/types/UFixed.sol";
import {IComponent, IComponentOwnerService} from "../contracts/instance/component/IComponent.sol";
import {ITreasuryModule} from "../contracts/instance/treasury/ITreasury.sol";

contract TestApplicationCreate is TestGifBase {
    uint256 public sumInsuredAmount = 1000 * 10 ** 6;
    uint256 public premiumAmount = 110 * 10 ** 6;
    uint256 public lifetime = 365 * 24 * 3600;

    IComponentOwnerService public componentOwnerService;

    function setUp() public override {
        super.setUp();
        componentOwnerService = instance.getComponentOwnerService();
    }

    function testApplicationCreateSimple() public {
        vm.prank(customer);
        NftId policyNftId = product.applyForPolicy(
            sumInsuredAmount,
            premiumAmount,
            lifetime
        );

        assertNftId(policyNftId, toNftId(53133705), "policy id not 53133705");
        assertEq(
            registry.getOwner(policyNftId),
            customer,
            "customer not policy owner"
        );
        assertNftIdZero(
            instance.getBundleNftForPolicy(policyNftId),
            "bundle id not 0"
        );

        IPolicy.PolicyInfo memory info = instance.getPolicyInfo(policyNftId);
        assertNftId(info.nftId, policyNftId, "policy id differs");
        assertEq(
            info.state.toInt(),
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

        assertTrue(info.createdAt == blockTimestamp(), "wrong created at");
        assertTrue(info.activatedAt == zeroTimestamp(), "wrong activated at");
        assertTrue(info.expiredAt == zeroTimestamp(), "wrong expired at");
        assertTrue(info.closedAt == zeroTimestamp(), "wrong closed at");
    }

    function testApplicationCreateAndUnderwrite() public {
        vm.prank(customer);
        NftId policyNftId = product.applyForPolicy(
            sumInsuredAmount,
            premiumAmount,
            lifetime
        );

        IPool.PoolInfo memory poolInfoBefore = instance.getPoolInfo(
            pool.getNftId()
        );

        product.underwrite(policyNftId);

        IPolicy.PolicyInfo memory info = instance.getPolicyInfo(policyNftId);
        assertNftId(info.nftId, policyNftId, "policy id differs");
        assertEq(
            info.state.toInt(),
            ACTIVE().toInt(),
            "policy state not active/underwritten"
        );

        // solhint-disable-next-line not-rely-on-time
        assertTrue(info.activatedAt == blockTimestamp(), "wrong activated at");
        assertTrue(
            info.expiredAt ==
            blockTimestamp().addSeconds(info.lifetime),
            "wrong expired at"
        );
        assertTrue(info.closedAt == zeroTimestamp(), "wrong closed at");

        IPool.PoolInfo memory poolInfoAfter = instance.getPoolInfo(
            pool.getNftId()
        );
        assertEq(poolInfoAfter.nftId.toInt(), 33133705, "pool id not 33133705");
        assertEq(poolInfoBefore.lockedCapital, 0, "capital locked not 0");
        assertEq(
            poolInfoAfter.lockedCapital,
            sumInsuredAmount,
            "capital locked not sum insured"
        );
    }

    function testCreatePolicyAndCollectPremiumNoFee() public {
        // set fees to zeroFee
        vm.prank(productOwner);
        product.setFees(zeroFee(), zeroFee());

        // check updated policy fee
        ITreasuryModule treasuryModule = ITreasuryModule(address(instance));
        ITreasuryModule.ProductSetup memory setup = treasuryModule
            .getProductSetup(product.getNftId());
        assertTrue(
            feeIsSame(setup.policyFee, zeroFee()),
            "updated policyFee not zeroFee"
        );
        assertTrue(
            feeIsSame(setup.processingFee, zeroFee()),
            "updated processingFee not zeroFee"
        );

        vm.prank(customer);
        NftId policyNftId = product.applyForPolicy(
            sumInsuredAmount,
            premiumAmount,
            lifetime
        );

        product.underwrite(policyNftId);

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
            0,
            "unexpected pool balance"
        );

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

        product.collectPremium(policyNftId);

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
        assertEq(
            token.balanceOf(pool.getWallet()),
            premiumAmount,
            "unexpected pool balance (after)"
        );
    }

    function testCreatePolicyAndCollectPremiumPolicyFee() public {
        // check initial policy fee
        ITreasuryModule treasuryModule = ITreasuryModule(address(instance));
        ITreasuryModule.ProductSetup memory setup = treasuryModule
            .getProductSetup(product.getNftId());
        Fee memory expectedInitialPolicyFee = zeroFee();

        assertTrue(
            feeIsSame(setup.policyFee, expectedInitialPolicyFee),
            "initial policyFee not zeroFee"
        );
        assertTrue(
            feeIsZero(setup.processingFee),
            "initial processingFee not zeroFee"
        );

        // updated policy fee (15% + 20 cents)
        UFixed fractionalFee = UFixedMathLib.itof(15, -2);
        uint256 fixedFee = 2 * 10 ** (token.decimals() - 1);
        Fee memory policyFee = toFee(fractionalFee, fixedFee);

        vm.prank(productOwner);
        product.setFees(policyFee, zeroFee());

        // check updated policy fee
        setup = treasuryModule.getProductSetup(product.getNftId());
        assertTrue(
            feeIsSame(setup.policyFee, policyFee),
            "updated policyFee not 15% + 20 cents"
        );
        assertTrue(
            feeIsSame(setup.processingFee, zeroFee()),
            "updated processingFee not zeroFee"
        );

        vm.prank(customer);
        NftId policyNftId = product.applyForPolicy(
            sumInsuredAmount,
            premiumAmount,
            lifetime
        );

        product.underwrite(policyNftId);

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
            0,
            "unexpected pool balance"
        );

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

        product.collectPremium(policyNftId);

        UFixed premiumUFixed = UFixedMathLib.itof(premiumAmount);
        UFixed fractionalFeeAmountUFixed = premiumUFixed *
            policyFee.fractionalFee;
        uint fractionalFeeAmount = UFixedMathLib.ftoi(
            fractionalFeeAmountUFixed
        );
        uint policyFeeAmount = fractionalFeeAmount + policyFee.fixedFee;
        uint netPremiumAmount = premiumAmount - policyFeeAmount;

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
        assertEq(
            token.balanceOf(product.getWallet()),
            policyFeeAmount,
            "unexpected product balance (after)"
        );
        assertEq(
            token.balanceOf(pool.getWallet()),
            netPremiumAmount,
            "unexpected pool balance (after)"
        );
    }
}
