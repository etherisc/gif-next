// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {Vm, console} from "../../../lib/forge-std/src/Test.sol";

import {TestGifBase} from "../../base/TestGifBase.sol";
import {Amount, AmountLib} from "../../../contracts/types/Amount.sol";
import {NftId, NftIdLib} from "../../../contracts/types/NftId.sol";
import {ClaimId} from "../../../contracts/types/ClaimId.sol";
import {PRODUCT_OWNER_ROLE} from "../../../contracts/types/RoleId.sol";
import {SimpleProduct} from "../../mock/SimpleProduct.sol";
import {SimplePool} from "../../mock/SimplePool.sol";
import {IComponents} from "../../../contracts/instance/module/IComponents.sol";
import {ILifecycle} from "../../../contracts/instance/base/ILifecycle.sol";
import {ISetup} from "../../../contracts/instance/module/ISetup.sol";
import {IPolicy} from "../../../contracts/instance/module/IPolicy.sol";
import {IBundle} from "../../../contracts/instance/module/IBundle.sol";
import {Fee, FeeLib} from "../../../contracts/types/Fee.sol";
import {UFixedLib} from "../../../contracts/types/UFixed.sol";
import {Seconds, SecondsLib} from "../../../contracts/types/Seconds.sol";
import {Timestamp, TimestampLib, zeroTimestamp} from "../../../contracts/types/Timestamp.sol";
import {IPolicyService} from "../../../contracts/instance/service/IPolicyService.sol";
import {IRisk} from "../../../contracts/instance/module/IRisk.sol";
import {PayoutId, PayoutIdLib} from "../../../contracts/types/PayoutId.sol";
import {POLICY} from "../../../contracts/types/ObjectType.sol";
import {RiskId, RiskIdLib, eqRiskId} from "../../../contracts/types/RiskId.sol";
import {ReferralLib} from "../../../contracts/types/Referral.sol";
import {SUBMITTED, ACTIVE, COLLATERALIZED, CONFIRMED, DECLINED, CLOSED, EXPECTED, PAID} from "../../../contracts/types/StateId.sol";
import {StateId} from "../../../contracts/types/StateId.sol";

contract TestProductClaim is TestGifBase {

    event LogClaimTestClaimInfo(NftId policyNftId, IPolicy.PolicyInfo policyInfo, ClaimId claimId, IPolicy.ClaimInfo claimInfo);

    uint256 public constant BUNDLE_CAPITAL = 5000;
    uint256 public constant SUM_INSURED = 1000;
    uint256 public constant CUSTOMER_FUNDS = 400;
    
    SimpleProduct public prdct;
    RiskId public riskId;
    NftId public policyNftId;

    function setUp() public override {
        super.setUp();

        _prepareProduct();  

        // create risk
        vm.startPrank(productOwner);
        riskId = RiskIdLib.toRiskId("Risk_1");
        prdct.createRisk(riskId, "");
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


    function test_ProductPayoutCreateHappyCaseCheckLogAndPolicy() public {
        // GIVEN
        _approve();
        _collateralize(policyNftId, true, TimestampLib.blockTimestamp());
        Amount claimAmount = AmountLib.toAmount(499);

        (
            IPolicy.PolicyInfo memory policyInfo,
            ClaimId claimId,
            IPolicy.ClaimInfo memory claimInfo,
            StateId claimState
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
        PayoutId payoutId = prdct.createPayout(policyNftId, claimId, payoutAmount, payoutData);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        // THEN
        // checking last of 4 logs
        assertEq(entries.length, 6, "unexpected number of logs");
        assertEq(entries[5].emitter, address(claimService), "unexpected emitter");
        assertEq(entries[5].topics[0], keccak256("LogClaimServicePayoutCreated(uint96,uint24,uint96)"), "unexpected log signature");
        (uint96 nftIdInt ,uint24 payoutIdInt, uint96 payoutAmountInt) = abi.decode(entries[5].data, (uint96,uint24,uint96));
        assertEq(nftIdInt, policyNftId.toInt(), "unexpected policy nft id");
        assertEq(payoutIdInt, payoutId.toInt(), "unexpected payout id");
        assertEq(payoutAmountInt, payoutAmount.toInt(), "unexpected payout amount");

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


    function test_ProductPayoutCreateHappyCaseCheckClaimAndPayout() public {
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
            PayoutId payoutId,
            StateId payoutState,
            IPolicy.PayoutInfo memory payoutInfo
        ) = _createClaimAndPayout(policyNftId, claimAmountInt, payoutAmountInt, payoutData);

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


    function test_ProductPayoutProcessHappyCase() public {
        // GIVEN
        _approve();
        _collateralize(policyNftId, true, TimestampLib.blockTimestamp());

        uint256 claimAmountInt = 500;
        uint256 payoutAmountInt = 300;
        bytes memory payoutData = "some sample payout data";

        // record balances before
        uint256 poolBalanceBefore = prdct.getToken().balanceOf(pool.getWallet());
        uint256 customerBalanceBefore = prdct.getToken().balanceOf(customer);

        console.log("payout amount:", payoutAmountInt);
        console.log("pool balance before: ", poolBalanceBefore);
        console.log("customer balance before: ", customerBalanceBefore);

        // create claim and payout
        (
            , // IPolicy.PolicyInfo memory policyInfo,
            ClaimId claimId,
            , // StateId claimState,
            , // IPolicy.ClaimInfo memory claimInfo,
            PayoutId payoutId
            , // StateId payoutState,
            , // IPolicy.PayoutInfo memory payoutInfo
        ) = _createClaimAndPayout(policyNftId, claimAmountInt, payoutAmountInt, payoutData);

        // WHEN
        vm.recordLogs();
        prdct.processPayout(policyNftId, payoutId);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        // THEN
        // checking last of 10 logs
        assertEq(entries.length, 10, "unexpected number of logs");
        assertEq(entries[9].emitter, address(claimService), "unexpected emitter");
        assertEq(entries[9].topics[0], keccak256("LogClaimServicePayoutProcessed(uint96,uint24,uint96,address,uint96)"), "unexpected log signature");
        (uint96 nftIdInt ,uint24 payoutIdInt, uint96 payoutAmntInt) = abi.decode(entries[9].data, (uint96,uint24,uint96));
        assertEq(nftIdInt, policyNftId.toInt(), "unexpected policy nft id");
        assertEq(payoutIdInt, payoutId.toInt(), "unexpected payout id");
        assertEq(payoutAmntInt, payoutAmountInt, "unexpected payout amount");

        // check policy
        {
            IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);

            assertFalse(instanceReader.policyIsCloseable(policyNftId), "policy is closeable (with open claim)");
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
        uint256 poolBalanceAfter = prdct.getToken().balanceOf(pool.getWallet());
        uint256 customerBalanceAfter = prdct.getToken().balanceOf(customer);

        console.log("pool balance after: ", poolBalanceAfter);
        console.log("customer balance after: ", customerBalanceAfter);

        // check new token balances
        assertEq(poolBalanceBefore - poolBalanceAfter, payoutAmountInt, "unexpected pool balance after payout");
        assertEq(customerBalanceAfter - customerBalanceBefore, payoutAmountInt, "unexpected customer balance after payout");
    }


    function _createClaimAndPayout(
        NftId plcyNftId, 
        uint256 claimAmount, 
        uint256 payoutAmount,
        bytes memory payoutData
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

        payoutId = prdct.createPayout(
            policyNftId, 
            claimId, 
            AmountLib.toAmount(payoutAmount), 
            payoutData);

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
        claimId = prdct.submitClaim(nftId, claimAmount, claimData); 
        prdct.confirmClaim(nftId, claimId, claimAmount); 
        policyInfo = instanceReader.getPolicyInfo(policyNftId);
        claimInfo = instanceReader.getClaimInfo(policyNftId, claimId);
        claimState = instanceReader.getClaimState(policyNftId, claimId);
    }

    function _approve() internal {
        // add allowance to pay premiums
        ISetup.ProductSetupInfo memory productSetup = instanceReader.getProductSetupInfo(productNftId);(productNftId);

        vm.startPrank(customer);
        token.approve(
            address(productSetup.tokenHandler), 
            CUSTOMER_FUNDS);
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
        prdct.collateralize(nftId, collectPremium, activateAt); 
        vm.stopPrank();
    }


    function _createApplication(
        uint256 sumInsuredAmount,
        Seconds lifetime
    )
        internal
        returns (NftId)
    {
        return prdct.createApplication(
            customer,
            riskId,
            sumInsuredAmount,
            lifetime,
            "",
            bundleNftId,
            ReferralLib.zero());
    }


    function _prepareProduct() internal {
        vm.startPrank(instanceOwner);
        instanceAccessManager.grantRole(PRODUCT_OWNER_ROLE(), productOwner);
        vm.stopPrank();

        _prepareDistributionAndPool();

        vm.startPrank(productOwner);
        prdct = new SimpleProduct(
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
        
        productNftId = productService.register(address(prdct));
        vm.stopPrank();


        vm.startPrank(registryOwner);
        token.transfer(investor, BUNDLE_CAPITAL);
        token.transfer(customer, CUSTOMER_FUNDS);
        vm.stopPrank();

        vm.startPrank(investor);
        IComponents.ComponentInfo memory poolComponentInfo = instanceReader.getComponentInfo(poolNftId);
        token.approve(address(poolComponentInfo.tokenHandler), BUNDLE_CAPITAL);

        // SimplePool spool = SimplePool(address(pool));
        bundleNftId = SimplePool(address(pool)).createBundle(
            FeeLib.zeroFee(), 
            BUNDLE_CAPITAL, 
            SecondsLib.toSeconds(604800), 
            ""
        );
        vm.stopPrank();
    }

}
