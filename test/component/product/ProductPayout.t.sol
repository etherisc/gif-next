// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Vm, console} from "../../../lib/forge-std/src/Test.sol";

import {GifTest} from "../../base/GifTest.sol";
import {Amount, AmountLib} from "../../../contracts/type/Amount.sol";
import {NftId} from "../../../contracts/type/NftId.sol";
import {ClaimId} from "../../../contracts/type/ClaimId.sol";
import {IClaimService} from "../../../contracts/product/IClaimService.sol";
import {IPolicy} from "../../../contracts/instance/module/IPolicy.sol";
import {FeeLib} from "../../../contracts/type/Fee.sol";
import {Seconds, SecondsLib} from "../../../contracts/type/Seconds.sol";
import {Timestamp, TimestampLib} from "../../../contracts/type/Timestamp.sol";
import {PayoutId, PayoutIdLib} from "../../../contracts/type/PayoutId.sol";
import {RiskId} from "../../../contracts/type/RiskId.sol";
import {ReferralLib} from "../../../contracts/type/Referral.sol";
import {CANCELLED, COLLATERALIZED, CONFIRMED, CLOSED, EXPECTED, PAID} from "../../../contracts/type/StateId.sol";
import {StateId} from "../../../contracts/type/StateId.sol";


// solhint-disable func-name-mixedcase
contract TestProductClaim is GifTest {

    event LogClaimTestClaimInfo(NftId policyNftId, IPolicy.PolicyInfo policyInfo, ClaimId claimId, IPolicy.ClaimInfo claimInfo);

    uint256 public constant BUNDLE_CAPITAL = 100000;
    uint256 public constant SUM_INSURED = 1000;
    uint256 public constant CUSTOMER_FUNDS = 400;
    
    RiskId public riskId;
    NftId public policyNftId;

    function setUp() public override {
        super.setUp();

        _prepareProduct();  

        // create risk
        vm.startPrank(productOwner);
        riskId = product.createRisk("Risk_1", "");
        vm.stopPrank();

        // create application
        policyNftId = _createApplication(
            1000, // sum insured
            SecondsLib.toSeconds(60)); // lifetime
    }

    // TODO this should not be here (copy paste from IPolicyService)
    event LogPolicyServiceClaimSubmitted(NftId policyNftId, ClaimId claimId, Amount claimAmount);
    event LogPolicyServiceClaimDeclined(NftId policyNftId, ClaimId claimId);
    event LogPolicyServiceClaimConfirmed(NftId policyNftId, ClaimId claimId, Amount confirmedAmount);
    event LogClaimServicePayoutCreated(NftId policyNftId, PayoutId payoutId, Amount amount);
    event LogClaimServicePayoutProcessed(NftId policyNftId, PayoutId payoutId, Amount amount);


    function test_productPayoutCreateHappyCaseCheckLogAndPolicy() public {
        // GIVEN
        _approve();
        _collateralize(policyNftId, true, TimestampLib.blockTimestamp());
        Amount claimAmount = AmountLib.toAmount(499);

        (
            IPolicy.PolicyInfo memory policyInfo,
            ClaimId claimId,
            IPolicy.ClaimInfo memory claimInfo,
        ) = _makeClaim(policyNftId, claimAmount);

        assertEq(policyInfo.claimsCount, 1, "claims count not 1 (before)");
        assertEq(policyInfo.openClaimsCount, 1, "open claims count not 1 (before)");
        assertEq(claimInfo.payoutsCount, 0, "payouts count not 0");
        assertEq(claimInfo.openPayoutsCount, 0, "open payouts count not 0");
        assertEq(policyInfo.payoutAmount.toInt(), 0, "payout amount not 0 (before)");

        // WHEN
        Amount payoutAmount = AmountLib.toAmount(200);
        bytes memory payoutData = "some payout";
        PayoutId payoutIdExpected = PayoutIdLib.toPayoutId(claimId, 1);

        vm.recordLogs();
        PayoutId payoutId = product.createPayout(policyNftId, claimId, payoutAmount, payoutData);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        // THEN
        // checking last of 4 logs
        assertEq(entries.length, 3, "unexpected number of logs");
        assertEq(entries[2].emitter, address(claimService), "unexpected emitter");
        assertEq(entries[2].topics[0], keccak256("LogClaimServicePayoutCreated(uint96,uint40,uint96,address)"), "unexpected log signature");
        (uint96 nftIdInt ,uint40 payoutIdInt, uint96 payoutAmountInt, address beneficiary) = abi.decode(entries[2].data, (uint96,uint40,uint96, address));

        assertEq(nftIdInt, policyNftId.toInt(), "unexpected policy nft id");
        assertEq(payoutIdInt, payoutId.toInt(), "unexpected payout id");
        assertEq(payoutAmountInt, payoutAmount.toInt(), "unexpected payout amount");
        assertEq(beneficiary, customer, "unexpected beneficiary");

        assertTrue(payoutId.gtz(), "payout id zero");
        assertEq(payoutId.toInt(), payoutIdExpected.toInt(), "unexpected payoutId");

        // check policy info
        policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertEq(policyInfo.claimsCount, 1, "claims count not 1");
        assertEq(policyInfo.openClaimsCount, 1, "open claims count not 1");
        assertEq(policyInfo.payoutAmount.toInt(), 0, "payout amount not 0");

        // check claim state and info
        assertEq(instanceReader.getClaimState(policyNftId, claimId).toInt(), CONFIRMED().toInt(), "unexpected claim state");

        claimInfo = instanceReader.getClaimInfo(policyNftId, claimId);
        assertEq(claimInfo.claimAmount.toInt(), claimAmount.toInt(), "unexpected claim amount");
        assertEq(claimInfo.paidAmount.toInt(), 0, "paid amount not 0");
        assertEq(claimInfo.payoutsCount, 1, "payouts count not 1");
        assertEq(claimInfo.openPayoutsCount, 1, "open payouts count not 1");
    }


    function test_productPayoutCreateHappyCaseCheckClaimAndPayout() public {
        // GIVEN
        _approve();
        _collateralize(policyNftId, true, TimestampLib.blockTimestamp());

        uint256 claimAmountInt = 500;
        uint256 payoutAmountInt = 300;
        bytes memory payoutData = "some sample payout data";

        // WHEN
        (
            IPolicy.PolicyInfo memory policyInfo,
            ClaimId claimId,
            StateId claimState,
            IPolicy.ClaimInfo memory claimInfo,
            ,
            StateId payoutState,
            IPolicy.PayoutInfo memory payoutInfo
        ) = _createClaimAndPayout(policyNftId, claimAmountInt, payoutAmountInt, payoutData, false);

        // THEN
        // check policy info
        assertEq(policyInfo.claimsCount, 1, "claims count not 1");
        assertEq(policyInfo.openClaimsCount, 1, "open claims count not 1");
        assertEq(policyInfo.claimAmount.toInt(), claimAmountInt, "unexpected claim amount");
        assertEq(policyInfo.payoutAmount.toInt(), 0, "payout amount not 0");

        // check claim state and info
        assertEq(claimState.toInt(), CONFIRMED().toInt(), "unexpected claim state");

        assertEq(claimInfo.claimAmount.toInt(), claimAmountInt, "unexpected claim amount");
        assertEq(claimInfo.paidAmount.toInt(), 0, "paid amount not 0");
        assertEq(claimInfo.payoutsCount, 1, "payouts count not 1");
        assertEq(claimInfo.openPayoutsCount, 1, "open payouts count not 1");
        assertEq(claimInfo.closedAt.toInt(), 0, "unexpected closed at");

        // check payout state and info
        assertEq(payoutState.toInt(), EXPECTED().toInt(), "unexpected payout state");

        assertEq(payoutInfo.claimId.toInt(), claimId.toInt(), "unexpected claim id");
        assertEq(payoutInfo.amount.toInt(), payoutAmountInt, "unexpected payout amount");
        assertEq(keccak256(payoutInfo.data), keccak256(payoutData), "unexpected payout data");
        assertEq(payoutInfo.paidAt.toInt(), 0, "unexpected payout paid at");
    }


    function test_productPayoutProcessHappyCase() public {
        // GIVEN
        _approve();
        _collateralize(policyNftId, true, TimestampLib.blockTimestamp());

        uint256 claimAmountInt = 500;
        uint256 payoutAmountInt = 300;
        bytes memory payoutData = "some sample payout data";

        // record balances before
        uint256 poolBalanceBefore = product.getToken().balanceOf(pool.getWallet());
        uint256 customerBalanceBefore = product.getToken().balanceOf(customer);

        // solhint-disable
        console.log("payout amount:", payoutAmountInt);
        console.log("pool balance before: ", poolBalanceBefore);
        console.log("customer balance before: ", customerBalanceBefore);
        // solhint-enable

        // create claim and payout
        (
            , // IPolicy.PolicyInfo memory policyInfo,
            ClaimId claimId,
            , // StateId claimState,
            , // IPolicy.ClaimInfo memory claimInfo,
            PayoutId payoutId
            , // StateId payoutState,
            , // IPolicy.PayoutInfo memory payoutInfo
        ) = _createClaimAndPayout(policyNftId, claimAmountInt, payoutAmountInt, payoutData, false);

        // WHEN + THEN
        Amount payoutAmount = AmountLib.toAmount(payoutAmountInt);
        vm.expectEmit(address(claimService));
        emit IClaimService.LogClaimServicePayoutProcessed(
                policyNftId, 
                payoutId,
                payoutAmount);

        product.processPayout(policyNftId, payoutId);

        // THEN
        // check policy
        {
            IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);

            assertEq(policyInfo.claimsCount, 1, "claims count not 1");
            assertEq(policyInfo.openClaimsCount, 1, "open claims count not 1");
            assertEq(policyInfo.claimAmount.toInt(), claimAmountInt, "unexpected claim amount");
            assertEq(policyInfo.payoutAmount.toInt(), payoutAmountInt, "unexpected payout amount");
        }

        // check claim
        {
            StateId claimState = instanceReader.getClaimState(policyNftId, claimId);
            IPolicy.ClaimInfo memory claimInfo = instanceReader.getClaimInfo(policyNftId, claimId);

            assertEq(claimState.toInt(), CONFIRMED().toInt(), "unexpected claim state");
            assertEq(claimInfo.claimAmount.toInt(), claimAmountInt, "unexpected claim amount");
            assertEq(claimInfo.paidAmount.toInt(), payoutAmountInt, "unexpected paid amount");
            assertEq(claimInfo.payoutsCount, 1, "unexpected payouts count");
            assertEq(claimInfo.openPayoutsCount, 0, "open payouts count not 0");
            assertEq(claimInfo.closedAt.toInt(), 0, "unexpected closed at");
        }

        // check payout
        {
            StateId payoutState = instanceReader.getPayoutState(policyNftId, payoutId);
            IPolicy.PayoutInfo memory payoutInfo = instanceReader.getPayoutInfo(policyNftId, payoutId);

            assertEq(payoutState.toInt(), PAID().toInt(), "unexpected payout state");
            assertEq(payoutInfo.claimId.toInt(), claimId.toInt(), "unexpected claim id");
            assertEq(payoutInfo.amount.toInt(), payoutAmountInt, "unexpected payout amount");
            assertEq(keccak256(payoutInfo.data), keccak256(payoutData), "unexpected payout data");
            assertEq(payoutInfo.paidAt.toInt(), block.timestamp, "unexpected payout at timestamp");
        }

        // record balances after payout processing
        uint256 poolBalanceAfter = product.getToken().balanceOf(pool.getWallet());
        uint256 customerBalanceAfter = product.getToken().balanceOf(customer);

        // solhint-disable
        console.log("pool balance after: ", poolBalanceAfter);
        console.log("customer balance after: ", customerBalanceAfter);
        // solhint-enable

        // check new token balances
        assertEq(poolBalanceBefore - poolBalanceAfter, payoutAmountInt, "unexpected pool balance after payout");
        assertEq(customerBalanceAfter - customerBalanceBefore, payoutAmountInt, "unexpected customer balance after payout");
    }

    function test_productPayoutProcessHappyCaseWithProcessingFee() public {
        vm.startPrank(productOwner);
        product.setFees(FeeLib.zero(), FeeLib.percentageFee(10));
        vm.stopPrank();

        // GIVEN
        _approve();
        _collateralize(policyNftId, true, TimestampLib.blockTimestamp());

        uint256 claimAmountInt = 500;
        uint256 payoutAmountInt = 300;
        bytes memory payoutData = "some sample payout data";

        // record balances before
        uint256 productBalanceBefore = product.getToken().balanceOf(product.getWallet());
        uint256 poolBalanceBefore = product.getToken().balanceOf(pool.getWallet());
        uint256 customerBalanceBefore = product.getToken().balanceOf(customer);
        Amount productFeeBefore = instanceReader.getFeeAmount(productNftId);

        // solhint-disable
        console.log("payout amount:", payoutAmountInt);
        console.log("pool balance before: ", poolBalanceBefore);
        console.log("customer balance before: ", customerBalanceBefore);
        // solhint-enable

        // create claim and payout
        (
            , // IPolicy.PolicyInfo memory policyInfo,
            ClaimId claimId,
            , // StateId claimState,
            , // IPolicy.ClaimInfo memory claimInfo,
            PayoutId payoutId
            , // StateId payoutState,
            , // IPolicy.PayoutInfo memory payoutInfo
        ) = _createClaimAndPayout(policyNftId, claimAmountInt, payoutAmountInt, payoutData, false);

        // WHEN + THEN
        Amount payoutAmount = AmountLib.toAmount(payoutAmountInt);
        vm.expectEmit(address(claimService));
        emit IClaimService.LogClaimServicePayoutProcessed(
                policyNftId, 
                payoutId,
                payoutAmount);

        (Amount netPayoutAmount, Amount processingFeeAmount) = product.processPayout(policyNftId, payoutId);
        assertEq(payoutAmountInt, netPayoutAmount.toInt() + processingFeeAmount.toInt(), "net payout amount + processing fee amount not equal to payout amount");

        // THEN
        // check policy
        {
            IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);

            assertEq(policyInfo.claimsCount, 1, "claims count not 1");
            assertEq(policyInfo.openClaimsCount, 1, "open claims count not 1");
            assertEq(policyInfo.claimAmount.toInt(), claimAmountInt, "unexpected claim amount");
            assertEq(policyInfo.payoutAmount.toInt(), payoutAmountInt, "unexpected payout amount");
        }

        // check claim
        {
            StateId claimState = instanceReader.getClaimState(policyNftId, claimId);
            IPolicy.ClaimInfo memory claimInfo = instanceReader.getClaimInfo(policyNftId, claimId);

            assertEq(claimState.toInt(), CONFIRMED().toInt(), "unexpected claim state");
            assertEq(claimInfo.claimAmount.toInt(), claimAmountInt, "unexpected claim amount");
            assertEq(claimInfo.paidAmount.toInt(), payoutAmountInt, "unexpected paid amount");
            assertEq(claimInfo.payoutsCount, 1, "unexpected payouts count");
            assertEq(claimInfo.openPayoutsCount, 0, "open payouts count not 0");
            assertEq(claimInfo.closedAt.toInt(), 0, "unexpected closed at");
        }

        // check payout
        {
            StateId payoutState = instanceReader.getPayoutState(policyNftId, payoutId);
            IPolicy.PayoutInfo memory payoutInfo = instanceReader.getPayoutInfo(policyNftId, payoutId);

            assertEq(payoutState.toInt(), PAID().toInt(), "unexpected payout state");
            assertEq(payoutInfo.claimId.toInt(), claimId.toInt(), "unexpected claim id");
            assertEq(payoutInfo.amount.toInt(), payoutAmountInt, "unexpected payout amount");
            assertEq(keccak256(payoutInfo.data), keccak256(payoutData), "unexpected payout data");
            assertEq(payoutInfo.paidAt.toInt(), block.timestamp, "unexpected payout at timestamp");
        }

        // check product fees
        {
            Amount productFeeAfter = instanceReader.getFeeAmount(productNftId);
            assertEq(productFeeAfter.toInt(), productFeeBefore.toInt() + processingFeeAmount.toInt(), "unexpected product fee amount");
        }

        // record balances after payout processing
        {
            uint256 productBalanceAfter = product.getToken().balanceOf(product.getWallet());
            uint256 poolBalanceAfter = product.getToken().balanceOf(pool.getWallet());
            uint256 customerBalanceAfter = product.getToken().balanceOf(customer);

            // solhint-disable
            console.log("pool balance after: ", poolBalanceAfter);
            console.log("customer balance after: ", customerBalanceAfter);
            // solhint-enable

            // check new token balances
            assertEq(productBalanceAfter - productBalanceBefore, processingFeeAmount.toInt(), "unexpected product balance after payout");
            assertEq(poolBalanceBefore - poolBalanceAfter, payoutAmountInt, "unexpected pool balance after payout");
            assertEq(customerBalanceAfter - customerBalanceBefore, netPayoutAmount.toInt(), "unexpected customer balance after payout");
        }
    }

    function test_productClaimPayoutPartial() public {
        address newCustomer = makeAddr("customer_test_productClaimPayoutSimple");
        uint256 sumInsuredAmountInt = 20000;
        uint256 lifetimeInt = 365 * 24 * 3600;
        uint256 claimAmountInt = 5000;
        uint256 payoutAmountInt = 1500;

        StateId claimState;
        ClaimId claimId;
        IPolicy.ClaimInfo memory claimInfo;
        PayoutId payoutId;
        StateId payoutState;
        IPolicy.PayoutInfo memory payoutInfo;

        // implicit assigning of policy nft id
        (
            claimId,
            claimState,
            payoutId,
            payoutState
        ) = _createPolicyWithClaimAndPayout(
            newCustomer,
            sumInsuredAmountInt,
            lifetimeInt,
            claimAmountInt,
            payoutAmountInt, 
            true); // process payout

        // check policy
        {
            assertTrue(policyNftId.gtz(), "policy nft id zero");
            assertEq(registry.ownerOf(policyNftId), newCustomer, "unexpected policy holder");
            assertEq(instanceReader.getPolicyState(policyNftId).toInt(), COLLATERALIZED().toInt(), "unexpected policy state");

            IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
            assertEq(policyInfo.claimsCount, 1, "unexpected claims count");
            assertEq(policyInfo.openClaimsCount, 1, "unexpected open claims count");
            assertEq(policyInfo.claimAmount.toInt(), claimAmountInt, "unexpected claim amount (policy)");
            assertEq(policyInfo.payoutAmount.toInt(), payoutAmountInt, "unexpected payout amount (policy)");
        }

        // check claim
        {
            assertEq(claimId.toInt(), 1, "unexpected claim id");
            assertEq(claimState.toInt(), CONFIRMED().toInt(), "unexpected claim state");

            claimInfo = instanceReader.getClaimInfo(policyNftId, claimId);
            assertEq(claimInfo.claimAmount.toInt(), claimAmountInt, "unexpected claim amount (claim)");
            assertEq(claimInfo.paidAmount.toInt(), payoutAmountInt, "unexpected paid amount (claim)");
            assertEq(claimInfo.payoutsCount, 1, "unexpected payouts count");
            assertEq(claimInfo.openPayoutsCount, 0, "unexpected open payouts count");
        }

        // check payout
        {
            assertTrue(payoutId.gtz(), "claim id zero");
            assertEq(payoutId.toClaimId().toInt(), claimId.toInt(), "unexpected payout id claim id link");
            assertEq(payoutState.toInt(), PAID().toInt(), "unexpected payout state");

            payoutInfo = instanceReader.getPayoutInfo(policyNftId, payoutId);
            assertEq(payoutInfo.amount.toInt(), payoutAmountInt, "unexpected amount (payout)");
            assertEq(payoutInfo.paidAt.toInt(), block.timestamp, "unexpected paid at");
        }
    }

    function test_productClaimPayoutFullExpected() public {
        address newCustomer = makeAddr("customer_test_productClaimPayoutSimple");
        uint256 sumInsuredAmountInt = 20000;
        uint256 lifetimeInt = 365 * 24 * 3600;
        uint256 claimAmountInt = 5000;
        uint256 payoutAmountInt = claimAmountInt;

        StateId claimState;
        ClaimId claimId;
        IPolicy.ClaimInfo memory claimInfo;
        PayoutId payoutId;
        StateId payoutState;
        IPolicy.PayoutInfo memory payoutInfo;

        // implicit assigning of policy nft id
        (
            claimId,
            claimState,
            payoutId,
            payoutState
        ) = _createPolicyWithClaimAndPayout(
            newCustomer,
            sumInsuredAmountInt,
            lifetimeInt,
            claimAmountInt,
            payoutAmountInt, 
            false); // process payout

        // check policy
        {
            assertTrue(policyNftId.gtz(), "policy nft id zero");
            assertEq(registry.ownerOf(policyNftId), newCustomer, "unexpected policy holder");
            assertEq(instanceReader.getPolicyState(policyNftId).toInt(), COLLATERALIZED().toInt(), "unexpected policy state");

            IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
            assertEq(policyInfo.claimsCount, 1, "unexpected claims count");
            assertEq(policyInfo.openClaimsCount, 1, "unexpected open claims count");
            assertEq(policyInfo.claimAmount.toInt(), claimAmountInt, "unexpected claim amount (policy)");
            assertEq(policyInfo.payoutAmount.toInt(), 0, "unexpected payout amount (policy)");
        }

        // check claim
        {
            assertEq(claimId.toInt(), 1, "unexpected claim id");
            assertEq(claimState.toInt(), CONFIRMED().toInt(), "unexpected claim state");

            claimInfo = instanceReader.getClaimInfo(policyNftId, claimId);
            assertEq(claimInfo.claimAmount.toInt(), claimAmountInt, "unexpected claim amount (claim)");
            assertEq(claimInfo.paidAmount.toInt(), 0, "unexpected paid amount (claim)");
            assertEq(claimInfo.payoutsCount, 1, "unexpected payouts count");
            assertEq(claimInfo.openPayoutsCount, 1, "unexpected open payouts count");
        }

        // check payout
        {
            assertTrue(payoutId.gtz(), "claim id zero");
            assertEq(payoutId.toClaimId().toInt(), claimId.toInt(), "unexpected payout id claim id link");
            assertEq(payoutState.toInt(), EXPECTED().toInt(), "unexpected payout state");

            payoutInfo = instanceReader.getPayoutInfo(policyNftId, payoutId);
            assertEq(payoutInfo.amount.toInt(), payoutAmountInt, "unexpected amount (payout)");
            assertEq(payoutInfo.paidAt.toInt(), 0, "unexpected paid at");
        }
    }

    function test_productClaimPayoutFullProcessed() public {
        address newCustomer = makeAddr("customer_test_productClaimPayoutSimple");
        uint256 sumInsuredAmountInt = 20000;
        uint256 lifetimeInt = 365 * 24 * 3600;
        uint256 claimAmountInt = 5000;
        uint256 payoutAmountInt = claimAmountInt;

        // implicit assigning of policy nft id
        (
            ClaimId claimId,
            StateId claimState,
            PayoutId payoutId,
            StateId payoutState
        ) = _createPolicyWithClaimAndPayout(
            newCustomer,
            sumInsuredAmountInt,
            lifetimeInt,
            claimAmountInt,
            payoutAmountInt, 
            true); // process payout

        // check policy
        {
            assertTrue(policyNftId.gtz(), "policy nft id zero");
            assertEq(registry.ownerOf(policyNftId), newCustomer, "unexpected policy holder");
            assertEq(instanceReader.getPolicyState(policyNftId).toInt(), COLLATERALIZED().toInt(), "unexpected policy state");

            IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
            assertEq(policyInfo.claimsCount, 1, "unexpected claims count");
            assertEq(policyInfo.openClaimsCount, 0, "unexpected open claims count");
            assertEq(policyInfo.claimAmount.toInt(), claimAmountInt, "unexpected claim amount (policy)");
            assertEq(policyInfo.payoutAmount.toInt(), payoutAmountInt, "unexpected payout amount (policy)");
        }

        // check claim
        {
            assertEq(claimId.toInt(), 1, "unexpected claim id");
            assertEq(claimState.toInt(), CLOSED().toInt(), "unexpected claim state");

            IPolicy.ClaimInfo memory claimInfo = instanceReader.getClaimInfo(policyNftId, claimId);
            assertEq(claimInfo.claimAmount.toInt(), claimAmountInt, "unexpected claim amount (claim)");
            assertEq(claimInfo.paidAmount.toInt(), payoutAmountInt, "unexpected paid amount (claim)");
            assertEq(claimInfo.payoutsCount, 1, "unexpected payouts count");
            assertEq(claimInfo.openPayoutsCount, 0, "unexpected open payouts count");
        }

        // check payout
        {
            assertTrue(payoutId.gtz(), "claim id zero");
            assertEq(payoutId.toClaimId().toInt(), claimId.toInt(), "unexpected payout id claim id link");
            assertEq(payoutState.toInt(), PAID().toInt(), "unexpected payout state");

            IPolicy.PayoutInfo memory payoutInfo = instanceReader.getPayoutInfo(policyNftId, payoutId);
            assertEq(payoutInfo.amount.toInt(), payoutAmountInt, "unexpected amount (payout)");
            assertEq(payoutInfo.paidAt.toInt(), block.timestamp, "unexpected paid at");
        }
    }


    function test_productClaimPayoutPaidAmountUpdatedAfterProcessPayout() public {
        // GIVEN
        address newCustomer = makeAddr("customer_test_productClaimPayoutSimple");
        uint256 sumInsuredAmountInt = 20000;
        uint256 lifetimeInt = 365 * 24 * 3600;
        uint256 claimAmountInt = 5000;
        uint256 payoutAmountInt = 1000;

        // implicit assigning of policy nft id
        (
            ClaimId claimId,
            ,
            PayoutId payoutId,
        ) = _createPolicyWithClaimAndPayout(
            newCustomer,
            sumInsuredAmountInt,
            lifetimeInt,
            claimAmountInt,
            payoutAmountInt, 
            false); // don't process payout

        IPolicy.ClaimInfo memory claimInfo = instanceReader.getClaimInfo(policyNftId, claimId);
        assertEq(claimInfo.payoutsCount, 1, "unexpected payouts count (1)");
        assertEq(claimInfo.claimAmount.toInt(), claimAmountInt, "unexpected claim amount (1)");
        // check that paid amount is still 0
        assertEq(claimInfo.paidAmount.toInt(), 0, "unexpected paid amount (1)");

        // WHEN
        product.processPayout(policyNftId, payoutId);

        // THEN
        claimInfo = instanceReader.getClaimInfo(policyNftId, claimId);
        assertEq(claimInfo.payoutsCount, 1, "unexpected payouts count (2)");
        assertEq(claimInfo.claimAmount.toInt(), claimAmountInt, "unexpected claim amount (1)");
        // check that paid amount has been updated
        assertEq(claimInfo.paidAmount.toInt(), payoutAmountInt, "unexpected paid amount (2)");
    }


    function test_productClaimPayoutAmountLimit() public {
        // GIVEN
        address newCustomer = makeAddr("customer_test_productClaimPayoutSimple");
        uint256 sumInsuredAmountInt = 20000;
        uint256 lifetimeInt = 365 * 24 * 3600;
        uint256 claimAmountInt = 5000;
        uint256 payoutAmountInt = 1000;

        // implicit assigning of policy nft id
        (
            ClaimId claimId,
            ,
            PayoutId payoutId,
        ) = _createPolicyWithClaimAndPayout(
            newCustomer,
            sumInsuredAmountInt,
            lifetimeInt,
            claimAmountInt,
            payoutAmountInt, 
            false); // don't process payout

        // WHEN
        Amount okPayoutAmount = AmountLib.toAmount(4500);
        PayoutId secondPayoutId = product.createPayout(policyNftId, claimId, okPayoutAmount, "");

        // THEN
        IPolicy.ClaimInfo memory claimInfo = instanceReader.getClaimInfo(policyNftId, claimId);
        assertEq(claimInfo.payoutsCount, 2, "unexpected payouts count (1)");
        assertEq(claimInfo.claimAmount.toInt(), claimAmountInt, "unexpected claim amount (1)");
        // check that paid amount is still 0
        assertEq(claimInfo.paidAmount.toInt(), 0, "unexpected paid amount (1)");

        // WHEN + THEN
        Amount nokPayoutAmount = AmountLib.toAmount(5500);
        vm.expectRevert(
            abi.encodeWithSelector(
                IClaimService.ErrorClaimServicePayoutExceedsClaimAmount.selector, 
                policyNftId,
                claimId,
                claimAmountInt,
                nokPayoutAmount));

        product.createPayout(policyNftId, claimId, nokPayoutAmount, "");

        claimInfo = instanceReader.getClaimInfo(policyNftId, claimId);
        assertEq(claimInfo.payoutsCount, 2, "unexpected payouts count (2)");
        assertEq(claimInfo.claimAmount.toInt(), claimAmountInt, "unexpected claim amount (2)");
        // check that paid amount is still 0
        assertEq(claimInfo.paidAmount.toInt(), 0, "unexpected paid amount (2)");

        // WHEN
        product.processPayout(policyNftId, payoutId);

        // THEN
        claimInfo = instanceReader.getClaimInfo(policyNftId, claimId);
        assertEq(claimInfo.payoutsCount, 2, "unexpected payouts count (3)");
        assertEq(claimInfo.claimAmount.toInt(), claimAmountInt, "unexpected claim amount (3)");
        assertEq(claimInfo.paidAmount.toInt(), payoutAmountInt, "unexpected paid amount (3)");

        // WHEN + THEN
        Amount exceedingAmount = claimInfo.paidAmount + okPayoutAmount;
        vm.expectRevert(
            abi.encodeWithSelector(
                IClaimService.ErrorClaimServicePayoutExceedsClaimAmount.selector, 
                policyNftId,
                claimId,
                claimAmountInt,
                exceedingAmount));

        product.processPayout(policyNftId, secondPayoutId);

        // THEN
        claimInfo = instanceReader.getClaimInfo(policyNftId, claimId);
        assertEq(claimInfo.payoutsCount, 2, "unexpected payouts count (4)");
        assertEq(claimInfo.claimAmount.toInt(), claimAmountInt, "unexpected claim amount (4)");
        assertEq(claimInfo.paidAmount.toInt(), payoutAmountInt, "unexpected paid amount (4)");

    }


    function test_productClaimPayoutMultiplePaid() public {
        address newCustomer = makeAddr("customer_test_productClaimPayoutSimple");
        uint256 sumInsuredAmountInt = 20000;
        uint256 lifetimeInt = 365 * 24 * 3600;
        uint256 claimAmountInt = 5000;
        uint256 payoutAmountInt = 500;

        // implicit assigning of policy nft id
        (
            ClaimId claimId,
            StateId claimState,
            PayoutId payoutId,
            StateId payoutState
        ) = _createPolicyWithClaimAndPayout(
            newCustomer,
            sumInsuredAmountInt,
            lifetimeInt,
            claimAmountInt,
            payoutAmountInt, 
            true); // process payout

        // add two payouts
        uint256 payoutAmount2Int = 1000;
        uint256 payoutAmount3Int = 2000;

        PayoutId payoutId2 = product.createPayout(
            policyNftId, 
            claimId, 
            AmountLib.toAmount(payoutAmount2Int), 
            "");

        PayoutId payoutId3 = product.createPayout(
            policyNftId, 
            claimId, 
            AmountLib.toAmount(payoutAmount3Int), 
            "");

        // process 2nd payout
        product.processPayout(policyNftId, payoutId2);

        // check policy
        {
            assertTrue(policyNftId.gtz(), "policy nft id zero");
            assertEq(registry.ownerOf(policyNftId), newCustomer, "unexpected policy holder");
            assertEq(instanceReader.getPolicyState(policyNftId).toInt(), COLLATERALIZED().toInt(), "unexpected policy state");

            IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
            assertEq(policyInfo.claimsCount, 1, "unexpected claims count");
            assertEq(policyInfo.openClaimsCount, 1, "unexpected open claims count");
            assertEq(policyInfo.claimAmount.toInt(), claimAmountInt, "unexpected claim amount (policy)");
            assertEq(policyInfo.payoutAmount.toInt(), payoutAmountInt + payoutAmount2Int, "unexpected payout amount (policy)");
        }

        // check claim
        {
            assertEq(claimId.toInt(), 1, "unexpected claim id");
            assertEq(claimState.toInt(), CONFIRMED().toInt(), "unexpected claim state");

            IPolicy.ClaimInfo memory claimInfo = instanceReader.getClaimInfo(policyNftId, claimId);
            assertEq(claimInfo.claimAmount.toInt(), claimAmountInt, "unexpected claim amount (claim)");
            assertEq(claimInfo.paidAmount.toInt(), payoutAmountInt + payoutAmount2Int, "unexpected paid amount (claim)");
            assertEq(claimInfo.payoutsCount, 3, "unexpected payouts count");
            assertEq(claimInfo.openPayoutsCount, 1, "unexpected open payouts count");
        }

        // check 1st payout
        {
            assertTrue(payoutId.gtz(), "payout id zero (1)");
            assertEq(payoutId.toClaimId().toInt(), claimId.toInt(), "unexpected payout id claim id link");
            assertEq(payoutState.toInt(), PAID().toInt(), "unexpected payout state");

            IPolicy.PayoutInfo memory payoutInfo = instanceReader.getPayoutInfo(policyNftId, payoutId);
            assertEq(payoutInfo.amount.toInt(), payoutAmountInt, "unexpected amount (payout)");
            assertEq(payoutInfo.paidAt.toInt(), block.timestamp, "unexpected paid at");
        }

        // check 2nd payout
        {
            payoutState = instanceReader.getPayoutState(policyNftId, payoutId2);
            assertTrue(payoutId2.gtz(), "payout id zero (2)");
            assertEq(payoutId2.toInt()-payoutId.toInt(), 1, "payout id not consecutive (2)");
            assertEq(payoutId2.toClaimId().toInt(), claimId.toInt(), "unexpected payout id claim id link");
            assertEq(payoutState.toInt(), PAID().toInt(), "unexpected payout state");

            IPolicy.PayoutInfo memory payoutInfo = instanceReader.getPayoutInfo(policyNftId, payoutId2);
            assertEq(payoutInfo.amount.toInt(), payoutAmount2Int, "unexpected amount (payout)");
            assertEq(payoutInfo.paidAt.toInt(), block.timestamp, "unexpected paid at");
        }

        // check 3rd payout
        {
            payoutState = instanceReader.getPayoutState(policyNftId, payoutId3);
            assertTrue(payoutId3.gtz(), "payout id zero (3)");
            assertEq(payoutId3.toInt()-payoutId2.toInt(), 1, "payout id not consecutive (2)");
            assertEq(payoutId3.toClaimId().toInt(), claimId.toInt(), "unexpected payout id claim id link");
            assertEq(payoutState.toInt(), EXPECTED().toInt(), "unexpected payout state");

            IPolicy.PayoutInfo memory payoutInfo = instanceReader.getPayoutInfo(policyNftId, payoutId3);
            assertEq(payoutInfo.amount.toInt(), payoutAmount3Int, "unexpected amount (payout)");
            assertEq(payoutInfo.paidAt.toInt(), 0, "unexpected paid at");
        }
    }


    function test_productClaimMultiplePayoutMultiple() public {
        address newCustomer = makeAddr("customer_test_productClaimPayoutSimple");

        // implicit assigning of policy nft id
        (ClaimId claimId,, PayoutId payoutId,) = _createPolicyWithClaimAndPayout(
            newCustomer,
            20000, // sum insured
            365 * 24 * 3600, // lifetime
            1000, // claim amount 1
            100, // payout mount 1
            true); // process payout

        // add 2nd payout to 1st claim (filling up to full claim amount)
        PayoutId payoutId2 = product.createPayout(
            policyNftId, 
            claimId, 
            AmountLib.toAmount(900), 
            "");

        product.processPayout(policyNftId, payoutId2);

        // add 2nd claim
        // uint256 claimAmount2Int = 2000;
        // uint256 payoutAmount3Int = 2000;
        (, ClaimId claimId2,,, PayoutId payoutId3,,) = _createClaimAndPayout(
            policyNftId,
            2000, // claim amount 2
            2000, // payout amount 3,
            "",  // payout data
            true); // processPayout

        // add 3rd claim
        (, ClaimId claimId3,,, PayoutId payoutId4,,) = _createClaimAndPayout(
            policyNftId,
            3000, // claim amount 3
            300, // payout amount 4
            "",  // payout data
            false); // processPayout

        // check policy
        {
            assertTrue(policyNftId.gtz(), "policy nft id zero");
            assertEq(registry.ownerOf(policyNftId), newCustomer, "unexpected policy holder");
            assertEq(instanceReader.getPolicyState(policyNftId).toInt(), COLLATERALIZED().toInt(), "unexpected policy state");

            IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
            assertEq(policyInfo.claimsCount, 3, "unexpected claims count");
            assertEq(policyInfo.openClaimsCount, 1, "unexpected open claims count");
            assertEq(policyInfo.claimAmount.toInt(), 1000 + 2000 + 3000, "unexpected claim amount (policy)");
            assertEq(policyInfo.payoutAmount.toInt(), 1000 + 2000, "unexpected payout amount (policy)");
        }

        // check claim (1)
        {
            assertEq(claimId.toInt(), 1, "unexpected claim id (1)");
            assertEq(instanceReader.getClaimState(policyNftId, claimId).toInt(), CLOSED().toInt(), "unexpected claim (1) state");

            IPolicy.ClaimInfo memory claimInfo = instanceReader.getClaimInfo(policyNftId, claimId);
            assertEq(claimInfo.claimAmount.toInt(), 1000, "unexpected claim (1) amount (claim)");
            assertEq(claimInfo.paidAmount.toInt(), 1000, "unexpected paid amount (claim 1)");
            assertEq(claimInfo.payoutsCount, 2, "unexpected payouts count (claim 1)");
            assertEq(claimInfo.openPayoutsCount, 0, "unexpected open payouts count (claim 1)");
        }

        // check claim (2)
        {
            assertEq(claimId2.toInt(), 2, "unexpected claim id (2)");
            assertEq(instanceReader.getClaimState(policyNftId, claimId2).toInt(), CLOSED().toInt(), "unexpected claim (2) state");

            IPolicy.ClaimInfo memory claimInfo = instanceReader.getClaimInfo(policyNftId, claimId2);
            assertEq(claimInfo.claimAmount.toInt(), 2000, "unexpected claim (2) amount (claim)");
            assertEq(claimInfo.paidAmount.toInt(), 2000, "unexpected paid amount (claim 2)");
            assertEq(claimInfo.payoutsCount, 1, "unexpected payouts count (claim 2)");
            assertEq(claimInfo.openPayoutsCount, 0, "unexpected open payouts count (claim 2)");
        }

        // check claim (3)
        {
            assertEq(claimId3.toInt(), 3, "unexpected claim id (3)");
            assertEq(instanceReader.getClaimState(policyNftId, claimId3).toInt(), CONFIRMED().toInt(), "unexpected claim (3) state");

            IPolicy.ClaimInfo memory claimInfo = instanceReader.getClaimInfo(policyNftId, claimId3);
            assertEq(claimInfo.claimAmount.toInt(), 3000, "unexpected claim (3) amount (claim)");
            assertEq(claimInfo.paidAmount.toInt(), 0, "unexpected paid amount (claim 3)");
            assertEq(claimInfo.payoutsCount, 1, "unexpected payouts count (claim 3)");
            assertEq(claimInfo.openPayoutsCount, 1, "unexpected open payouts count (claim 3)");
        }

        // check 1st payout
        {
            StateId payoutState = instanceReader.getPayoutState(policyNftId, payoutId);
            assertTrue(payoutId2.gtz(), "payout id zero (1)");
            assertEq(payoutId2.toClaimId().toInt(), claimId.toInt(), "unexpected payout id claim id link");
            assertEq(payoutState.toInt(), PAID().toInt(), "unexpected payout state");

            IPolicy.PayoutInfo memory payoutInfo = instanceReader.getPayoutInfo(policyNftId, payoutId);
            assertEq(payoutInfo.amount.toInt(), 100, "unexpected amount (payout 1)");
            assertEq(payoutInfo.paidAt.toInt(), block.timestamp, "unexpected paid at");
        }

        // check 2nd payout
        {
            StateId payoutState = instanceReader.getPayoutState(policyNftId, payoutId2);
            assertTrue(payoutId2.gtz(), "payout id zero (2)");
            assertEq(payoutId2.toClaimId().toInt(), claimId.toInt(), "unexpected payout id claim id link");
            assertEq(payoutState.toInt(), PAID().toInt(), "unexpected payout state");

            IPolicy.PayoutInfo memory payoutInfo = instanceReader.getPayoutInfo(policyNftId, payoutId2);
            assertEq(payoutInfo.amount.toInt(), 900, "unexpected amount (payout 2)");
            assertEq(payoutInfo.paidAt.toInt(), block.timestamp, "unexpected paid at");
        }

        // check 3nd payout
        {
            StateId payoutState = instanceReader.getPayoutState(policyNftId, payoutId3);
            assertTrue(payoutId3.gtz(), "payout id zero (3)");
            assertEq(payoutId3.toClaimId().toInt(), claimId2.toInt(), "unexpected payout id claim id link");
            assertEq(payoutState.toInt(), PAID().toInt(), "unexpected payout state");

            IPolicy.PayoutInfo memory payoutInfo = instanceReader.getPayoutInfo(policyNftId, payoutId3);
            assertEq(payoutInfo.amount.toInt(), 2000, "unexpected amount (payout 3)");
            assertEq(payoutInfo.paidAt.toInt(), block.timestamp, "unexpected paid at");
        }

        // check 4th payout
        {
            StateId payoutState = instanceReader.getPayoutState(policyNftId, payoutId4);
            assertTrue(payoutId4.gtz(), "payout id zero (4)");
            assertEq(payoutId4.toClaimId().toInt(), claimId3.toInt(), "unexpected payout id claim id link");
            assertEq(payoutState.toInt(), EXPECTED().toInt(), "unexpected payout state");

            IPolicy.PayoutInfo memory payoutInfo = instanceReader.getPayoutInfo(policyNftId, payoutId4);
            assertEq(payoutInfo.amount.toInt(), 300, "unexpected amount (payout 3)");
            assertEq(payoutInfo.paidAt.toInt(), 0, "unexpected paid at");
        }

    }


    function test_productPayoutProcessTwice() public {
        // GIVEN
        _approve();
        _collateralize(policyNftId, true, TimestampLib.blockTimestamp());

        uint256 claimAmountInt = 500;
        uint256 payoutAmountInt = 300;
        bytes memory payoutData = "some sample payout data";

        // WHEN
        (
            ,
            ,
            ,
            ,
            PayoutId payoutId,
            StateId payoutState,
            IPolicy.PayoutInfo memory payoutInfo
        ) = _createClaimAndPayout(policyNftId, claimAmountInt, payoutAmountInt, payoutData, true);

        // THEN
        assertEq(payoutState.toInt(), PAID().toInt(), "unexpected payout state");

        // WHEN + THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                IClaimService.ErrorClaimServicePayoutNotExpected.selector, 
                policyNftId,
                payoutId,
                payoutState));

        product.processPayout(policyNftId, payoutId);
    }


    function test_productPayoutCancelPayout() public {
        // GIVEN
        _approve();
        _collateralize(policyNftId, true, TimestampLib.blockTimestamp());

        uint256 claimAmountInt = 500;
        uint256 payoutAmountInt = 300;
        bytes memory payoutData = "some sample payout data";

        (
            IPolicy.PolicyInfo memory policyInfo,
            ClaimId claimId,
            StateId claimState,
            IPolicy.ClaimInfo memory claimInfo,
            PayoutId payoutId,
            StateId payoutState,
            IPolicy.PayoutInfo memory payoutInfo
        ) = _createClaimAndPayout(policyNftId, claimAmountInt, payoutAmountInt, payoutData, false);

        // check policy info
        assertEq(policyInfo.claimsCount, 1, "claims count not 1");
        assertEq(policyInfo.openClaimsCount, 1, "open claims count not 1");
        assertEq(policyInfo.claimAmount.toInt(), claimAmountInt, "unexpected claim amount");
        assertEq(policyInfo.payoutAmount.toInt(), 0, "payout amount not 0 (before)");

        // check claim state and info
        assertEq(claimState.toInt(), CONFIRMED().toInt(), "unexpected claim state");

        assertEq(claimInfo.claimAmount.toInt(), claimAmountInt, "unexpected claim amount");
        assertEq(claimInfo.paidAmount.toInt(), 0, "paid amount not 0");
        assertEq(claimInfo.payoutsCount, 1, "payouts count not 1");
        assertEq(claimInfo.openPayoutsCount, 1, "open payouts count not 1");
        assertEq(claimInfo.closedAt.toInt(), 0, "unexpected closed at");

        // check payout state and info
        assertEq(payoutState.toInt(), EXPECTED().toInt(), "unexpected payout state");

        assertEq(payoutInfo.claimId.toInt(), claimId.toInt(), "unexpected claim id");
        assertEq(payoutInfo.amount.toInt(), payoutAmountInt, "unexpected payout amount");
        assertEq(keccak256(payoutInfo.data), keccak256(payoutData), "unexpected payout data");
        assertEq(payoutInfo.paidAt.toInt(), 0, "unexpected payout paid at");

        // WHEN
        product.cancelPayout(policyNftId, payoutId);

        // THEN
        // check policy info
        policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertEq(policyInfo.claimsCount, 1, "claims count not 1");
        assertEq(policyInfo.openClaimsCount, 1, "open claims count not 1");
        assertEq(policyInfo.claimAmount.toInt(), claimAmountInt, "unexpected claim amount");
        assertEq(policyInfo.payoutAmount.toInt(), 0, "payout amount not 0");

        // check claim state and info
        assertEq(CONFIRMED().toInt(), instanceReader.getClaimState(policyNftId, claimId).toInt(), "unexpected claim state");

        claimInfo = instanceReader.getClaimInfo(policyNftId, claimId);
        assertEq(claimInfo.claimAmount.toInt(), claimAmountInt, "unexpected claim amount");
        assertEq(claimInfo.paidAmount.toInt(), 0, "paid amount not 0");
        assertEq(claimInfo.payoutsCount, 1, "payouts count not 1");
        assertEq(claimInfo.openPayoutsCount, 0, "open payouts count not 0");
        assertEq(claimInfo.closedAt.toInt(), 0, "unexpected closed at");

        // check payout state and info
        payoutState = instanceReader.getPayoutState(policyNftId, payoutId);
        assertEq(payoutState.toInt(), CANCELLED().toInt(), "unexpected payout state");

        payoutInfo = instanceReader.getPayoutInfo(policyNftId, payoutId);
        assertEq(payoutInfo.claimId.toInt(), claimId.toInt(), "unexpected claim id");
        assertEq(payoutInfo.amount.toInt(), payoutAmountInt, "unexpected payout amount");
        assertEq(keccak256(payoutInfo.data), keccak256(payoutData), "unexpected payout data");
        assertEq(payoutInfo.paidAt.toInt(), 0, "unexpected payout paid at");

        // WHEN (try to process payout)
        vm.expectRevert(
            abi.encodeWithSelector(
                IClaimService.ErrorClaimServicePayoutNotExpected.selector, 
                policyNftId,
                payoutId,
                payoutState));

        product.processPayout(policyNftId, payoutId);
    }


    function test_productPayoutCancelPaidOutPayout() public {
        // GIVEN
        _approve();
        _collateralize(policyNftId, true, TimestampLib.blockTimestamp());

        uint256 claimAmountInt = 500;
        uint256 payoutAmountInt = 300;
        bytes memory payoutData = "some sample payout data";

        // WHEN
        (
            ,
            ,
            ,
            ,
            PayoutId payoutId,
            StateId payoutState,
            IPolicy.PayoutInfo memory payoutInfo
        ) = _createClaimAndPayout(policyNftId, claimAmountInt, payoutAmountInt, payoutData, true);

        // THEN
        assertEq(payoutState.toInt(), PAID().toInt(), "unexpected payout state");

        // WHEN + THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                IClaimService.ErrorClaimServicePayoutNotExpected.selector, 
                policyNftId,
                payoutId,
                payoutState));

        product.cancelPayout(policyNftId, payoutId);
    }

    function _createPolicyWithClaimAndPayout(
        address policyHolder,
        uint256 sumInsuredAmountInt, 
        uint256 lifetimeInt,
        uint256 claimAmountInt, 
        uint256 payoutAmountInt,
        bool processPayout
    )
        internal
        returns (
            ClaimId claimId,
            StateId claimState,
            PayoutId payoutId,
            StateId payoutState
        )

    {
        // create application for policy holder
        policyNftId = product.createApplication(
            policyHolder,
            riskId,
            sumInsuredAmountInt,
            SecondsLib.toSeconds(lifetimeInt),
            "", // application data
            bundleNftId,
            ReferralLib.zero());

        // fund policy holder to pay premium
        uint256 premiumAmountInt = instanceReader.getPolicyInfo(policyNftId).premiumAmount.toInt();

        // add token allowance to pay premiums
        vm.startPrank(registryOwner);
        token.transfer(policyHolder, premiumAmountInt);
        vm.stopPrank();

        vm.startPrank(policyHolder);
        address tokenHandlerAddress = address(instanceReader.getComponentInfo(productNftId).tokenHandler);
        token.approve(tokenHandlerAddress, premiumAmountInt);
        vm.stopPrank();

        // collateralize policy
        bool collectPremium = true;
        Timestamp activateAt = TimestampLib.blockTimestamp();

        vm.startPrank(productOwner);
        product.createPolicy(policyNftId, collectPremium, activateAt); 
        vm.stopPrank();

        // create claim with payout
        (
            , // policyInfo
            claimId,
            , // claimState
            , // claimInfo
            payoutId,
            , // payoutState
            // payoutInfo
        ) = _createClaimAndPayout(
            policyNftId,
            claimAmountInt,
            payoutAmountInt,
            "",  // payout data
            processPayout
        );

        claimState = instanceReader.getClaimState(policyNftId, claimId);
        payoutState = instanceReader.getPayoutState(policyNftId, payoutId);
    }

    function _createClaimAndPayout(
        NftId plcyNftId, 
        uint256 claimAmount, 
        uint256 payoutAmount,
        bytes memory payoutData,
        bool processPayout
    )
        internal
        returns (
            IPolicy.PolicyInfo memory policyInfo,
            ClaimId claimId,
            StateId claimState,
            IPolicy.ClaimInfo memory claimInfo,
            PayoutId payoutId,
            StateId payoutState,
            IPolicy.PayoutInfo memory payoutInfo
        )
    {
        // after create claim
        (
            policyInfo, 
            claimId,
            claimInfo, 
            claimState
        ) = _makeClaim(plcyNftId, AmountLib.toAmount(claimAmount));

        payoutId = product.createPayout(
            policyNftId, 
            claimId, 
            AmountLib.toAmount(payoutAmount), 
            payoutData);

        if (processPayout) {
            product.processPayout(policyNftId, payoutId);
        }

        // after create payout
        policyInfo = instanceReader.getPolicyInfo(policyNftId);
        claimState = instanceReader.getClaimState(policyNftId, claimId);
        claimInfo = instanceReader.getClaimInfo(policyNftId, claimId);
        payoutState = instanceReader.getPayoutState(policyNftId, payoutId);
        payoutInfo = instanceReader.getPayoutInfo(policyNftId, payoutId);
    }


    function _makeClaim(NftId nftId, Amount claimAmount)
        internal
        returns (
            IPolicy.PolicyInfo memory policyInfo,
            ClaimId claimId,
            IPolicy.ClaimInfo memory claimInfo,
            StateId claimState)
    {
        bytes memory claimData = "please pay";
        claimId = product.submitClaim(nftId, claimAmount, claimData); 
        product.confirmClaim(nftId, claimId, claimAmount, ""); 
        policyInfo = instanceReader.getPolicyInfo(policyNftId);
        claimInfo = instanceReader.getClaimInfo(policyNftId, claimId);
        claimState = instanceReader.getClaimState(policyNftId, claimId);
    }

    // add allowance to pay premiums
    function _approve() internal {
        vm.startPrank(customer);
        address tokenHandlerAddress = address(instanceReader.getComponentInfo(productNftId).tokenHandler);
        token.approve(tokenHandlerAddress, CUSTOMER_FUNDS);
        vm.stopPrank();
    }

    function _collateralize(
        NftId nftId,
        bool collectPremium,
        Timestamp activateAt
    )
        internal
    {
        vm.startPrank(productOwner);
        product.createPolicy(nftId, collectPremium, activateAt); 
        vm.stopPrank();
    }


    function _createApplication(
        uint256 sumInsuredAmount,
        Seconds lifetime
    )
        internal
        returns (NftId)
    {
        return product.createApplication(
            customer,
            riskId,
            sumInsuredAmount,
            lifetime,
            "",
            bundleNftId,
            ReferralLib.zero());
    }


    // function _prepareProductLocal() internal {

    //     // create product
    //     vm.startPrank(productOwner);
    //     prdct = new SimpleProduct(
    //         address(registry),
    //         instanceNftId, // parent of product is instance
    //         new BasicProductAuthorization("SimpleProduct"),
    //         productOwner,
    //         address(token),
    //         false, // isInterceptor
    //         false, // has distribution
    //         0 // number of oracles
    //     );
    //     vm.stopPrank();

    //     // instance owner registes product with instance (and registry)
    //     vm.startPrank(instanceOwner);
    //     prdctNftId = instance.registerProduct(address(prdct));
    //     vm.stopPrank();

    //     // create pool
    //     vm.startPrank(poolOwner);
    //     pool = new SimplePool(
    //         address(registry),
    //         prdctNftId, // parent of pool is product
    //         address(token),
    //         new BasicPoolAuthorization("SimplePool"),
    //         poolOwner);
    //     vm.stopPrank();

    //     // product owner registes product with instance (and registry)
    //     vm.startPrank(productOwner);
    //     plNftId = prdct.registerComponent(address(prdct));
    //     vm.stopPrank();

    //     // fund investor and customer
    //     vm.startPrank(registryOwner);
    //     token.transfer(investor, BUNDLE_CAPITAL);
    //     token.transfer(customer, CUSTOMER_FUNDS);
    //     vm.stopPrank();

    //     vm.startPrank(investor);
    //     IComponents.ComponentInfo memory poolComponentInfo = instanceReader.getComponentInfo(poolNftId);
    //     token.approve(address(poolComponentInfo.tokenHandler), BUNDLE_CAPITAL);

    //     // SimplePool spool = SimplePool(address(pool));
    //     (bundleNftId,) = SimplePool(address(pool)).createBundle(
    //         FeeLib.zero(), 
    //         BUNDLE_CAPITAL, 
    //         SecondsLib.toSeconds(604800), 
    //         ""
    //     );
    //     vm.stopPrank();
    // }

}
