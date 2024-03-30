// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {console} from "../../../lib/forge-std/src/Test.sol";

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
import {SUBMITTED, ACTIVE, COLLATERALIZED, CONFIRMED, DECLINED, CLOSED} from "../../../contracts/types/StateId.sol";
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
    event LogPolicyServicePayoutCreated(NftId policyNftId, PayoutId payoutId, Amount amount);
    event LogPolicyServicePayoutProcessed(NftId policyNftId, PayoutId payoutId, Amount amount);

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

        vm.expectEmit(address(policyService));
        emit LogPolicyServiceClaimSubmitted(policyNftId, ClaimId.wrap(1), claimAmount);
        ClaimId claimId = prdct.submitClaim(policyNftId, claimAmount, claimData); 

        // THEN
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
        assertEq(keccak256(claimInfo.data), keccak256(claimData), "unexpected claim data");
        assertTrue(claimInfo.closedAt.eqz(), "closed at not 0");
    }


    function test_ProductClaimConfirmHappyCase() public {
        // GIVEN
        _approve();
        _collateralize(policyNftId, true, TimestampLib.blockTimestamp());
        Amount claimAmount = AmountLib.toAmount(499);
        bytes memory claimData = "please pay";
        ClaimId claimId = prdct.submitClaim(policyNftId, claimAmount, claimData); 

        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertEq(policyInfo.claimsCount, 1, "claims count not 1 (before)");
        assertEq(policyInfo.openClaimsCount, 1, "open claims count not 1 (before)");
        assertEq(policyInfo.payoutAmount.toInt(), 0, "payout amount not 0 (before)");

        // WHEN
        Amount confirmedAmount = AmountLib.toAmount(450);
        vm.expectEmit(address(policyService));
        emit LogPolicyServiceClaimConfirmed(policyNftId, ClaimId.wrap(1), confirmedAmount);
        prdct.confirmClaim(policyNftId, claimId, confirmedAmount); 

        // THEN
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
    }


    function test_ProductClaimDeclineHappyCase() public {
        // GIVEN
        _approve();
        _collateralize(policyNftId, true, TimestampLib.blockTimestamp());
        Amount claimAmount = AmountLib.toAmount(499);
        bytes memory claimData = "please pay";
        ClaimId claimId = prdct.submitClaim(policyNftId, claimAmount, claimData); 

        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertEq(policyInfo.claimsCount, 1, "claims count not 1 (before)");
        assertEq(policyInfo.openClaimsCount, 1, "open claims count not 1 (before)");
        assertEq(policyInfo.payoutAmount.toInt(), 0, "payout amount not 0 (before)");

        // WHEN
        vm.expectEmit(address(policyService));
        emit LogPolicyServiceClaimDeclined(policyNftId, ClaimId.wrap(1));
        prdct.declineClaim(policyNftId, claimId); 

        // THEN
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
        assertEq(keccak256(claimInfo.data), keccak256(claimData), "unexpected claim data");
        assertEq(claimInfo.closedAt.toInt(), block.timestamp, "unexpected closed at");

        // emit LogClaimTestClaimInfo(policyNftId, policyInfo, claimId, claimInfo);
        // require(false, "ups...");
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

    function test_ProductPayoutCreateHappyCase() public {
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
        assertEq(policyInfo.payoutAmount.toInt(), 0, "payout amount not 0 (before)");

        // WHEN
        Amount payoutAmount = AmountLib.toAmount(200);
        bytes memory payoutData = "some payout";
        PayoutId payoutIdExpected = PayoutIdLib.toPayoutId(claimId, 1);

        vm.expectEmit(address(policyService));
        emit LogPolicyServicePayoutCreated(policyNftId, payoutIdExpected, payoutAmount);
        PayoutId payoutId = prdct.createPayout(policyNftId, claimId, payoutAmount, payoutData);

        // THEN
        assertTrue(payoutId.gtz(), "payout id zero");
        assertEq(payoutId.toInt(), payoutIdExpected.toInt(), "unexpected payoutId");

        policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertEq(policyInfo.claimsCount, 1, "claims count not 1");
        assertEq(policyInfo.openClaimsCount, 1, "open claims count not 1");
        assertEq(policyInfo.payoutAmount.toInt(), 0, "payout amount not 0");

        // check claim state and info
        assertEq(instanceReader.getClaimState(policyNftId, claimId).toInt(), CONFIRMED().toInt(), "unexpected claim state");

        claimInfo = instanceReader.getClaimInfo(policyNftId, claimId);
        assertEq(claimInfo.claimAmount.toInt(), claimAmount.toInt(), "unexpected claim amount");
        assertEq(claimInfo.paidAmount.toInt(), 0, "paid amount not 0");
        assertEq(claimInfo.payoutsCount, 0, "payouts count not 0");
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
        bundleNftId = pool.createBundle(
            FeeLib.zeroFee(), 
            BUNDLE_CAPITAL, 
            SecondsLib.toSeconds(604800), 
            ""
        );
        vm.stopPrank();
    }

}
