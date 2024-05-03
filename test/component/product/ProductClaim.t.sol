// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {Vm, console} from "../../../lib/forge-std/src/Test.sol";

import {TestGifBase} from "../../base/TestGifBase.sol";
import {Amount, AmountLib} from "../../../contracts/type/Amount.sol";
import {NftId, NftIdLib} from "../../../contracts/type/NftId.sol";
import {ClaimId} from "../../../contracts/type/ClaimId.sol";
import {PRODUCT_OWNER_ROLE} from "../../../contracts/type/RoleId.sol";
import {SimpleProduct} from "../../mock/SimpleProduct.sol";
import {SimplePool} from "../../mock/SimplePool.sol";
import {IComponents} from "../../../contracts/instance/module/IComponents.sol";
import {ILifecycle} from "../../../contracts/instance/base/ILifecycle.sol";
import {ISetup} from "../../../contracts/instance/module/ISetup.sol";
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
import {SUBMITTED, ACTIVE, COLLATERALIZED, CONFIRMED, DECLINED, CLOSED} from "../../../contracts/type/StateId.sol";
import {StateId} from "../../../contracts/type/StateId.sol";

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
        ClaimId claimId = prdct.submitClaim(policyNftId, claimAmount, claimData); 
        Vm.Log[] memory entries = vm.getRecordedLogs();

        // THEN
        // checking last of 4 logs
        assertEq(entries.length, 4, "unexpected number of logs");
        assertEq(entries[3].emitter, address(claimService), "unexpected emitter");
        assertEq(entries[3].topics[0], keccak256("LogClaimServiceClaimSubmitted(uint96,uint16,uint96)"), "unexpected log signature");
        (uint96 nftIdInt ,uint24 claimIdInt, uint96 claimAmountInt) = abi.decode(entries[3].data, (uint96,uint16,uint96));
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
        ClaimId claimId = prdct.submitClaim(policyNftId, claimAmount, claimData); 

        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertEq(policyInfo.claimsCount, 1, "claims count not 1 (before)");
        assertEq(policyInfo.openClaimsCount, 1, "open claims count not 1 (before)");
        assertEq(policyInfo.payoutAmount.toInt(), 0, "payout amount not 0 (before)");

        // WHEN
        Amount confirmedAmount = AmountLib.toAmount(450);

        vm.recordLogs();
        string memory processData = "claim good to go";
        prdct.confirmClaim(policyNftId, claimId, confirmedAmount, bytes(processData)); 
        Vm.Log[] memory entries = vm.getRecordedLogs();

        // THEN
        // checking last of 4 logs
        assertEq(entries.length, 5, "unexpected number of logs");
        assertEq(entries[4].emitter, address(claimService), "unexpected emitter");
        assertEq(entries[4].topics[0], keccak256("LogClaimServiceClaimConfirmed(uint96,uint16,uint96)"), "unexpected log signature");
        (uint96 nftIdInt,uint24 claimIdInt, uint96 amountInt ) = abi.decode(entries[4].data, (uint96,uint16,uint96));
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
        // emit LogPolicyServiceClaimDeclined(policyNftId, ClaimId.wrap(1));
        vm.recordLogs();
        string memory processData = "claim invalid";
        prdct.declineClaim(policyNftId, claimId, bytes(processData)); 
        Vm.Log[] memory entries = vm.getRecordedLogs();

        // THEN
        // checking last of 4 logs
        assertEq(entries.length, 5, "unexpected number of logs");
        assertEq(entries[4].emitter, address(claimService), "unexpected emitter");
        assertEq(entries[4].topics[0], keccak256("LogClaimServiceClaimDeclined(uint96,uint16)"), "unexpected log signature");
        (uint96 nftIdInt ,uint24 claimIdInt) = abi.decode(entries[4].data, (uint96,uint16));
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
        claimId = prdct.submitClaim(nftId, claimAmount, claimData); 
        prdct.confirmClaim(nftId, claimId, claimAmount, ""); 
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
        instanceOzAccessManager.grantRole(PRODUCT_OWNER_ROLE().toInt(), productOwner, 0);
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
