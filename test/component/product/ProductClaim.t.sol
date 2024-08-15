// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Vm, console} from "../../../lib/forge-std/src/Test.sol";

import {GifTest} from "../../base/GifTest.sol";
import {Amount, AmountLib} from "../../../contracts/type/Amount.sol";
import {NftId, NftIdLib} from "../../../contracts/type/NftId.sol";
import {ClaimId} from "../../../contracts/type/ClaimId.sol";
import {SimpleProduct} from "../../../contracts/examples/unpermissioned/SimpleProduct.sol";
import {SimplePool} from "../../../contracts/examples/unpermissioned/SimplePool.sol";
import {IComponents} from "../../../contracts/instance/module/IComponents.sol";
import {ILifecycle} from "../../../contracts/shared/ILifecycle.sol";
import {IPolicy} from "../../../contracts/instance/module/IPolicy.sol";
import {IBundle} from "../../../contracts/instance/module/IBundle.sol";
import {Fee, FeeLib} from "../../../contracts/type/Fee.sol";
import {UFixedLib} from "../../../contracts/type/UFixed.sol";
import {Seconds, SecondsLib} from "../../../contracts/type/Seconds.sol";
import {Timestamp, TimestampLib, zeroTimestamp} from "../../../contracts/type/Timestamp.sol";
import {IPolicyService} from "../../../contracts/product/IPolicyService.sol";
import {IRisk} from "../../../contracts/instance/module/IRisk.sol";
import {PayoutId, PayoutIdLib} from "../../../contracts/type/PayoutId.sol";
import {POLICY} from "../../../contracts/type/ObjectType.sol";
import {RiskId, RiskIdLib, eqRiskId} from "../../../contracts/type/RiskId.sol";
import {ReferralLib} from "../../../contracts/type/Referral.sol";
import {SUBMITTED, ACTIVE, COLLATERALIZED, CONFIRMED, DECLINED, CLOSED, REVOKED} from "../../../contracts/type/StateId.sol";
import {StateId} from "../../../contracts/type/StateId.sol";

contract TestProductClaim is GifTest {

    event LogClaimTestClaimInfo(NftId policyNftId, IPolicy.PolicyInfo policyInfo, ClaimId claimId, IPolicy.ClaimInfo claimInfo);

    uint256 public constant BUNDLE_CAPITAL = 5000;
    uint256 public constant SUM_INSURED = 1000;
    uint256 public constant CUSTOMER_FUNDS = 400;
    
    RiskId public riskId;
    NftId public policyNftId;

    function setUp() public override {
        super.setUp();

        _prepareProduct();  

        // create risk
        vm.startPrank(productOwner);
        riskId = RiskIdLib.toRiskId("Risk_1");
        product.createRisk(riskId, "");
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


    function test_ProductClaimSubmitHappyCase() public {
        // GIVEN
        _approve();
        _collateralize(policyNftId, true, TimestampLib.blockTimestamp());

        // check policy info
        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertEq(policyInfo.claimsCount, 0, "claims count not 0 (before)");
        assertEq(policyInfo.openClaimsCount, 0, "open claims count not 0 (before)");
        assertEq(policyInfo.payoutAmount.toInt(), 0, "payout amount not 0 (before)");

        // WHEN
        Amount claimAmount = AmountLib.toAmount(499);
        bytes memory claimData = "please pay";

        vm.recordLogs();
        ClaimId claimId = product.submitClaim(policyNftId, claimAmount, claimData); 
        Vm.Log[] memory entries = vm.getRecordedLogs();

        // THEN
        // checking last of 3 logs
        assertEq(entries.length, 3, "unexpected number of logs");
        assertEq(entries[2].emitter, address(claimService), "unexpected emitter");
        assertEq(entries[2].topics[0], keccak256("LogClaimServiceClaimSubmitted(uint96,uint16,uint96)"), "unexpected log signature");
        (uint96 nftIdInt ,uint24 claimIdInt, uint96 claimAmountInt) = abi.decode(entries[2].data, (uint96,uint16,uint96));
        assertEq(nftIdInt, policyNftId.toInt(), "unexpected policy nft id");
        assertEq(claimIdInt, claimId.toInt(), "unexpected claim id");
        assertEq(claimAmountInt, claimAmount.toInt(), "unexpected claim amount");

        assertTrue(claimId.gtz(), "claim id zero");
        assertEq(claimId.toInt(), 1, "claim id not 1");

        // check updated policy info
        policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertEq(policyInfo.claimsCount, 1, "claims count not 1");
        assertEq(policyInfo.openClaimsCount, 1, "open claims count not 1");
        assertEq(policyInfo.payoutAmount.toInt(), 0, "payout amount not 0");

        // check claim state and info
        assertEq(instanceReader.getClaimState(policyNftId, claimId).toInt(), SUBMITTED().toInt(), "unexpected claim state");

        IPolicy.ClaimInfo memory claimInfo = instanceReader.getClaimInfo(policyNftId, claimId);
        assertEq(claimInfo.claimAmount.toInt(), claimAmount.toInt(), "unexpected claim amount");
        assertEq(claimInfo.paidAmount.toInt(), 0, "paid amount not 0");
        assertEq(claimInfo.payoutsCount, 0, "payouts count not 0");
        assertEq(claimInfo.openPayoutsCount, 0, "open payouts count not 0");
        assertEq(keccak256(claimInfo.submissionData), keccak256(claimData), "unexpected claim data");
        assertTrue(claimInfo.closedAt.eqz(), "closed at not 0");
    }


    function test_ProductClaimConfirmHappyCase() public {
        // GIVEN
        _approve();
        _collateralize(policyNftId, true, TimestampLib.blockTimestamp());
        Amount claimAmount = AmountLib.toAmount(499);
        bytes memory claimData = "please pay";
        ClaimId claimId = product.submitClaim(policyNftId, claimAmount, claimData); 

        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertEq(policyInfo.claimsCount, 1, "claims count not 1 (before)");
        assertEq(policyInfo.openClaimsCount, 1, "open claims count not 1 (before)");
        assertEq(policyInfo.payoutAmount.toInt(), 0, "payout amount not 0 (before)");

        // WHEN
        Amount confirmedAmount = AmountLib.toAmount(450);

        vm.recordLogs();
        string memory processData = "claim good to go";
        product.confirmClaim(policyNftId, claimId, confirmedAmount, bytes(processData)); 
        Vm.Log[] memory entries = vm.getRecordedLogs();

        // THEN
        // checking last of 4 logs
        assertEq(entries.length, 4, "unexpected number of logs");
        assertEq(entries[3].emitter, address(claimService), "unexpected emitter");
        assertEq(entries[3].topics[0], keccak256("LogClaimServiceClaimConfirmed(uint96,uint16,uint96)"), "unexpected log signature");
        (uint96 nftIdInt,uint24 claimIdInt, uint96 amountInt ) = abi.decode(entries[3].data, (uint96,uint16,uint96));
        assertEq(nftIdInt, policyNftId.toInt(), "unexpected policy nft id");
        assertEq(claimIdInt, claimId.toInt(), "unexpected claim id");
        assertEq(amountInt, confirmedAmount.toInt(), "unexpected amount");

        policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertEq(policyInfo.claimsCount, 1, "claims count not 1");
        assertEq(policyInfo.openClaimsCount, 1, "open claims count not 1");
        assertEq(policyInfo.payoutAmount.toInt(), 0, "payout amount not 0");

        // check claim state and info
        assertEq(instanceReader.getClaimState(policyNftId, claimId).toInt(), CONFIRMED().toInt(), "unexpected claim state");

        IPolicy.ClaimInfo memory claimInfo = instanceReader.getClaimInfo(policyNftId, claimId);
        assertEq(claimInfo.claimAmount.toInt(), confirmedAmount.toInt(), "unexpected claim amount");
        assertEq(claimInfo.paidAmount.toInt(), 0, "paid amount not 0");
        assertEq(claimInfo.payoutsCount, 0, "payouts count not 0");
        assertEq(keccak256(claimInfo.processData), keccak256(bytes(processData)), "unexpected claim process data");
    }


    function test_ProductClaimRevokeHappyCase() public {
        // GIVEN
        _approve();
        _collateralize(policyNftId, true, TimestampLib.blockTimestamp());
        Amount claimAmount = AmountLib.toAmount(499);
        ClaimId claimId = product.submitClaim(policyNftId, claimAmount, ""); 

        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertEq(policyInfo.claimsCount, 1, "claims count not 1 (before)");
        assertEq(policyInfo.openClaimsCount, 1, "open claims count not 1 (before)");
        assertEq(policyInfo.payoutAmount.toInt(), 0, "payout amount not 0 (before)");

        // WHEN
        // emit LogPolicyServiceClaimDeclined(policyNftId, ClaimId.wrap(1));
        vm.recordLogs();
        string memory processData = "claim invalid";
        product.revokeClaim(policyNftId, claimId); 
        Vm.Log[] memory entries = vm.getRecordedLogs();

        // THEN
        // checking last of 4 logs
        assertEq(entries.length, 4, "unexpected number of logs");
        assertEq(entries[3].emitter, address(claimService), "unexpected emitter");
        assertEq(entries[3].topics[0], keccak256("LogClaimServiceClaimRevoked(uint96,uint16)"), "unexpected log signature");
        (uint96 nftIdInt ,uint24 claimIdInt) = abi.decode(entries[3].data, (uint96,uint16));
        assertEq(nftIdInt, policyNftId.toInt(), "unexpected policy nft id");
        assertEq(claimIdInt, claimId.toInt(), "unexpected claim id");

        policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertEq(policyInfo.claimsCount, 1, "claims count not 1");
        assertEq(policyInfo.openClaimsCount, 0, "open claims count not 0");
        assertEq(policyInfo.payoutAmount.toInt(), 0, "payout amount not 0");

        // check claim state and info
        assertEq(instanceReader.getClaimState(policyNftId, claimId).toInt(), REVOKED().toInt(), "unexpected claim state");

        IPolicy.ClaimInfo memory claimInfo = instanceReader.getClaimInfo(policyNftId, claimId);
        assertEq(claimInfo.claimAmount.toInt(), claimAmount.toInt(), "unexpected claim amount");
        assertEq(claimInfo.paidAmount.toInt(), 0, "paid amount not 0");
        assertEq(claimInfo.payoutsCount, 0, "payouts count not 0");
        assertEq(claimInfo.openPayoutsCount, 0, "open payouts count not 0");
        assertEq(claimInfo.closedAt.toInt(), block.timestamp, "unexpected closed at");
    }


    function test_ProductClaimDeclineHappyCase() public {
        // GIVEN
        _approve();
        _collateralize(policyNftId, true, TimestampLib.blockTimestamp());
        Amount claimAmount = AmountLib.toAmount(499);
        bytes memory claimData = "please pay";
        ClaimId claimId = product.submitClaim(policyNftId, claimAmount, claimData); 

        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertEq(policyInfo.claimsCount, 1, "claims count not 1 (before)");
        assertEq(policyInfo.openClaimsCount, 1, "open claims count not 1 (before)");
        assertEq(policyInfo.payoutAmount.toInt(), 0, "payout amount not 0 (before)");

        // WHEN
        // emit LogPolicyServiceClaimDeclined(policyNftId, ClaimId.wrap(1));
        vm.recordLogs();
        string memory processData = "claim invalid";
        product.declineClaim(policyNftId, claimId, bytes(processData)); 
        Vm.Log[] memory entries = vm.getRecordedLogs();

        // THEN
        // checking last of 4 logs
        assertEq(entries.length, 4, "unexpected number of logs");
        assertEq(entries[3].emitter, address(claimService), "unexpected emitter");
        assertEq(entries[3].topics[0], keccak256("LogClaimServiceClaimDeclined(uint96,uint16)"), "unexpected log signature");
        (uint96 nftIdInt ,uint24 claimIdInt) = abi.decode(entries[3].data, (uint96,uint16));
        assertEq(nftIdInt, policyNftId.toInt(), "unexpected policy nft id");
        assertEq(claimIdInt, claimId.toInt(), "unexpected claim id");

        policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertEq(policyInfo.claimsCount, 1, "claims count not 1");
        assertEq(policyInfo.openClaimsCount, 0, "open claims count not 0");
        assertEq(policyInfo.payoutAmount.toInt(), 0, "payout amount not 0");

        // check claim state and info
        assertEq(instanceReader.getClaimState(policyNftId, claimId).toInt(), DECLINED().toInt(), "unexpected claim state");

        IPolicy.ClaimInfo memory claimInfo = instanceReader.getClaimInfo(policyNftId, claimId);
        assertEq(claimInfo.claimAmount.toInt(), claimAmount.toInt(), "unexpected claim amount");
        assertEq(claimInfo.paidAmount.toInt(), 0, "paid amount not 0");
        assertEq(claimInfo.payoutsCount, 0, "payouts count not 0");
        assertEq(claimInfo.openPayoutsCount, 0, "open payouts count not 0");
        assertEq(keccak256(claimInfo.submissionData), keccak256(claimData), "unexpected claim data");
        assertEq(claimInfo.closedAt.toInt(), block.timestamp, "unexpected closed at");
        assertEq(keccak256(claimInfo.processData), keccak256(bytes(processData)), "unexpected claim process data");
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
        address tokenHandlerAddress = address(instanceReader.getComponentInfo(productNftId).tokenHandler);

        vm.startPrank(customer);
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

}
