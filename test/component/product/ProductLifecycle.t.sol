// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {console} from "forge-std/Test.sol";

import {IClaimService} from "../../../contracts/product/IClaimService.sol";

import {GifTest} from "../../base/GifTest.sol";
import {MyPolicyHolder} from "../../mock/MyPolicyHolder.sol";
import {Amount, AmountLib} from "../../../contracts/type/Amount.sol";
import {NftId} from "../../../contracts/type/NftId.sol";
import {ClaimId, ClaimIdLib} from "../../../contracts/type/ClaimId.sol";
import {ContractLib} from "../../../contracts/shared/ContractLib.sol";
import {IPolicy} from "../../../contracts/instance/module/IPolicy.sol";
import {IPolicyHolder} from "../../../contracts/shared/IPolicyHolder.sol";
import {Seconds, SecondsLib} from "../../../contracts/type/Seconds.sol";
import {Timestamp, TimestampLib} from "../../../contracts/type/Timestamp.sol";
import {PayoutId, PayoutIdLib} from "../../../contracts/type/PayoutId.sol";
import {RiskId} from "../../../contracts/type/RiskId.sol";
import {ReferralLib} from "../../../contracts/type/Referral.sol";
import {SUBMITTED, CONFIRMED} from "../../../contracts/type/StateId.sol";
import {StateId} from "../../../contracts/type/StateId.sol";

contract TestProductLifecycle
    is GifTest
{

    uint256 public constant BUNDLE_CAPITAL = 5000;
    uint256 public constant SUM_INSURED = 1000;
    uint256 public constant CUSTOMER_FUNDS = 400;
    
    RiskId public riskId;
    NftId public policyNftId;
    MyPolicyHolder public policyHolder;
    address public policyHolderAddress;

    function setUp() public override {
        super.setUp();

        _prepareProduct();  

        // create risk
        vm.startPrank(productOwner);
        riskId = product.createRisk("Risk_1", "");
        vm.stopPrank();

        policyHolder = new MyPolicyHolder(address(registry));
        policyHolderAddress = address(policyHolder);

        // create application
        policyNftId = _createApplication(
            address(policyHolder), // initial owner
            1000, // sum insured
            SecondsLib.toSeconds(60)); // lifetime
    }

    // TODO this should not be here (copy paste from IPolicyService)
    event LogPolicyServiceClaimSubmitted(NftId policyNftId, ClaimId claimId, Amount claimAmount);
    event LogPolicyServiceClaimDeclined(NftId policyNftId, ClaimId claimId);
    event LogPolicyServiceClaimConfirmed(NftId policyNftId, ClaimId claimId, Amount confirmedAmount);
    event LogClaimServicePayoutCreated(NftId policyNftId, PayoutId payoutId, Amount amount);
    event LogClaimServicePayoutProcessed(NftId policyNftId, PayoutId payoutId, Amount amount);


    function test_policyHolderSetUp() public {
        assertTrue(ERC165Checker.supportsERC165(policyHolderAddress), "does not support ERC165 (variant 1)");
        assertTrue(ContractLib.isPolicyHolder(policyHolderAddress), "not policy holder (variant 1)");
        assertTrue(ContractLib.supportsInterface(policyHolderAddress, type(IPolicyHolder).interfaceId), "not policy holder (variant 1)");
        assertEq(registry.ownerOf(policyNftId), address(policyHolder), "unexpected owner");
        assertEq(policyHolder.activatedAt(policyNftId).toInt(), 0, "unexpected activated at");
        assertEq(policyHolder.expiredAt(policyNftId).toInt(), 0, "unexpected expired at");
    }


    function test_policyHolderCreationAndActivationCallback() public {
        // GIVEN just setup
        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertEq(policyInfo.activatedAt.toInt(), 0, "unexpected activated at (info, before)");
        assertEq(policyHolder.activatedAt(policyNftId).toInt(), 0, "unexpected activated at (holder, before)");
        assertEq(policyInfo.expiredAt.toInt(), 0, "unexpected expired at (info, before)");
        assertEq(policyHolder.expiredAt(policyNftId).toInt(), 0, "unexpected expired at (holder, before)");

        // WHEN
        Timestamp activateAt = TimestampLib.current().addSeconds(SecondsLib.toSeconds(42));
        _createAndActivate(policyNftId, activateAt);

        // THEN
        policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertEq(policyInfo.activatedAt.toInt(), activateAt.toInt(), "unexpected activated at (info, after)");
        assertEq(policyHolder.activatedAt(policyNftId).toInt(), activateAt.toInt(), "unexpected activated at (holder, after)");

        // check that expriy callback has not yet happened
        assertEq(policyInfo.expiredAt.toInt(), activateAt.addSeconds(policyInfo.lifetime).toInt(), "unexpected expired at (info, after)");
        assertEq(policyHolder.expiredAt(policyNftId).toInt(), 0, "unexpected expired at (holder, after)");
    }


    function test_policyHolderCreationAndActivationCallbackNonReentrant() public {
        // GIVEN switch policy holder to reentrant
        Timestamp activateAt = TimestampLib.current();

        // WHEN setting policy holder to mode that tries to do reentrancy on services
        policyHolder.setReentrant(product, true);
        assertTrue(policyHolder.isReentrant(), "unexpected reentrant"); 
    
        _fundAccount(address(policyHolder));
        _createAllowance(address(policyHolder));

        // THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                ReentrancyGuardUpgradeable.ReentrancyGuardReentrantCall.selector));

        vm.startPrank(productOwner);
        product.createPolicy(policyNftId, false, activateAt); 
        vm.stopPrank();
    }


    function test_policyHolderActivationOnlyCallback() public {
        // GIVEN create policy without activating it
        _createAndActivate(policyNftId, TimestampLib.zero());

        // check that no callback has yet happened
        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertEq(policyInfo.activatedAt.toInt(), 0, "unexpected activated at (info, before)");
        assertEq(policyHolder.activatedAt(policyNftId).toInt(), 0, "unexpected activated at (holder, before)");
        assertEq(policyInfo.expiredAt.toInt(), 0, "unexpected expired at (info, before)");
        assertEq(policyHolder.expiredAt(policyNftId).toInt(), 0, "unexpected expired at (holder, before)");

        // WHEN
        Timestamp activateAt = TimestampLib.current().addSeconds(SecondsLib.toSeconds(42));
        product.activate(policyNftId, activateAt);

        // THEN
        policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertEq(policyInfo.activatedAt.toInt(), activateAt.toInt(), "unexpected activated at (info, after)");
        assertEq(policyHolder.activatedAt(policyNftId).toInt(), activateAt.toInt(), "unexpected activated at (holder, after)");

        // check that expriy callback has not yet happened
        assertEq(policyInfo.expiredAt.toInt(), activateAt.addSeconds(policyInfo.lifetime).toInt(), "unexpected expired at (info, after)");
        assertEq(policyHolder.expiredAt(policyNftId).toInt(), 0, "unexpected expired at (holder, after)");
    }


    function test_policyHolderExpiryCallback() public {
        // GIVEN create active policy
        Timestamp activateAt = TimestampLib.current();
        _createAndActivate(policyNftId, activateAt);

        // check that no expiry callback has yet happened
        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertEq(policyInfo.expiredAt.toInt(), activateAt.addSeconds(policyInfo.lifetime).toInt(), "unexpected expired at (info, before)");
        assertEq(policyHolder.expiredAt(policyNftId).toInt(), 0, "unexpected expired at (holder, before)");

        // WHEN
        Timestamp expiryAt = policyInfo.activatedAt.addSeconds(SecondsLib.toSeconds(10));
        product.expire(policyNftId, expiryAt);

        // THEN
        policyInfo = instanceReader.getPolicyInfo(policyNftId);
        assertEq(policyInfo.activatedAt.toInt(), activateAt.toInt(), "unexpected activated at (info, after)");
        assertEq(policyHolder.activatedAt(policyNftId).toInt(), activateAt.toInt(), "unexpected activated at (holder, after)");
        assertEq(policyInfo.expiredAt.toInt(), expiryAt.toInt(), "unexpected expired at (info, after)");
        assertEq(policyHolder.expiredAt(policyNftId).toInt(), expiryAt.toInt(), "unexpected expired at (holder, after)");
    }


    function test_policyHolderClaimSubmitOnly() public {
        // GIVEN create active policy
        Timestamp activateAt = TimestampLib.current();
        _createAndActivate(policyNftId, activateAt);

        // check that no claim callback has yet happened
        ClaimId claimIdExpected = ClaimIdLib.toClaimId(1);
        assertEq(policyHolder.activatedAt(policyNftId).toInt(), activateAt.toInt(), "unexpected activated at (holder, before)");
        assertEq(policyHolder.expiredAt(policyNftId).toInt(), 0, "unexpected expired at (holder, before)");
        assertEq(policyHolder.claimAmount(policyNftId, claimIdExpected).toInt(), 0, "unexpected claim amount (holder, before)");

        // WHEN
        Amount claimAmount = AmountLib.toAmount(100);
        (
            IPolicy.PolicyInfo memory policyInfo, 
            ClaimId claimId, 
            IPolicy.ClaimInfo memory claimInfo, 
            StateId claimState
        ) = _makeClaim(policyNftId, claimAmount, false);

        // solhint-disable-next-line
        console.log("claimId", claimId.toInt());
        assertEq(claimId.toInt(), claimIdExpected.toInt(), "unexpected claim id");

        // THEN
        assertEq(claimState.toInt(), SUBMITTED().toInt(), "unexpected claim state");

        assertEq(policyHolder.activatedAt(policyNftId).toInt(), activateAt.toInt(), "unexpected activated at (holder, after)");
        assertEq(policyHolder.expiredAt(policyNftId).toInt(), 0, "unexpected expired at (holder, after)");

        // no callback as still only submitted, not confirmed
        assertEq(policyHolder.claimAmount(policyNftId, claimId).toInt(), 0, "unexpected claim amount (holder, after)");
    }

    function test_policyHolderClaimConfirmationCallback() public {
        // GIVEN create active policy
        Timestamp activateAt = TimestampLib.current();
        _createAndActivate(policyNftId, activateAt);

        // check that no claim callback has yet happened
        ClaimId claimIdExpected = ClaimIdLib.toClaimId(1);
        assertEq(policyHolder.activatedAt(policyNftId).toInt(), activateAt.toInt(), "unexpected activated at (holder, before)");
        assertEq(policyHolder.expiredAt(policyNftId).toInt(), 0, "unexpected expired at (holder, before)");
        assertEq(policyHolder.claimAmount(policyNftId, claimIdExpected).toInt(), 0, "unexpected claim amount (holder, before)");

        // WHEN
        Amount claimAmount = AmountLib.toAmount(100);
        (
            IPolicy.PolicyInfo memory policyInfo, 
            ClaimId claimId, 
            IPolicy.ClaimInfo memory claimInfo, 
            StateId claimState
        ) = _makeClaim(policyNftId, claimAmount, true);

        // solhint-disable-next-line
        console.log("claimId", claimId.toInt());
        assertEq(claimId.toInt(), claimIdExpected.toInt(), "unexpected claim id");

        // THEN
        assertEq(claimState.toInt(), CONFIRMED().toInt(), "unexpected claim state");

        assertEq(policyHolder.activatedAt(policyNftId).toInt(), activateAt.toInt(), "unexpected activated at (holder, after)");
        assertEq(policyHolder.expiredAt(policyNftId).toInt(), 0, "unexpected expired at (holder, after)");
        assertEq(policyHolder.claimAmount(policyNftId, claimId).toInt(), claimAmount.toInt(), "unexpected claim amount (holder, after)");
    }

    // disabled as claim service functions no longer have reentrancy guards
    // such guards prevent various re insurane use cases
    // function test_policyHolderClaimConfirmationCallbackNonReentrant() public {
    //     // GIVEN switch policy holder to reentrant
    //     Timestamp activateAt = TimestampLib.current();
    //     _createAndActivate(policyNftId, activateAt);

    //     policyHolder.setReentrant(product, true);
    //     assertTrue(policyHolder.isReentrant(), "unexpected reentrant"); 

    //     // WHEN
    //     Amount claimAmount = AmountLib.toAmount(100);
    //     ClaimId claimId = product.submitClaim(policyNftId, claimAmount, ""); 

    //     // THEN
    //     vm.expectRevert(
    //         abi.encodeWithSelector(
    //             ReentrancyGuardUpgradeable.ReentrancyGuardReentrantCall.selector));

    //     vm.startPrank(productOwner);
    //     product.confirmClaim(policyNftId, claimId, claimAmount, ""); 
    //     vm.stopPrank();
    // }


    function test_policyHolderPayoutExecutedBeneficiaryCallback() public {
        // GIVEN 
        // create active policy
        Timestamp activateAt = TimestampLib.current();
        _createAndActivate(policyNftId, activateAt);

        // create confirmed claim
        Amount claimAmount = AmountLib.toAmount(100);
        (, ClaimId claimId,,) = _makeClaim(policyNftId, claimAmount, true);

        // check that no payout callback has yet happened
        PayoutId payoutIdExpected = PayoutIdLib.toPayoutId(claimId, 1);
        Amount payoutAmount = claimAmount;
        address beneficiary = makeAddr("beneficiary");

        assertEq(policyHolder.activatedAt(policyNftId).toInt(), activateAt.toInt(), "unexpected activated at (holder, before)");
        assertEq(policyHolder.expiredAt(policyNftId).toInt(), 0, "unexpected expired at (holder, before)");
        assertEq(policyHolder.beneficiary(policyNftId, payoutIdExpected), address(0), "unexpected beneficiary (holder, before)");
        assertEq(policyHolder.payoutAmount(policyNftId, payoutIdExpected).toInt(), 0, "unexpected amount (holder, before)");
        assertEq(token.balanceOf(beneficiary), 0, "unexpected balance (beneficiary, before)");

        // WHEN - create payout
        PayoutId payoutId = product.createPayoutForBeneficiary(policyNftId, claimId, payoutAmount, beneficiary, "");

        // THEN
        IPolicy.PayoutInfo memory payoutInfo = instanceReader.getPayoutInfo(policyNftId, payoutId);
        assertEq(payoutInfo.beneficiary, beneficiary, "unexpected beneficiary (info)");

        // check still no callback (only create payout, no tokens moved so far)
        assertEq(payoutId.toInt(), payoutIdExpected.toInt(), "unexpected payout id");
        assertEq(policyHolder.activatedAt(policyNftId).toInt(), activateAt.toInt(), "unexpected activated at (holder, after)");
        assertEq(policyHolder.expiredAt(policyNftId).toInt(), 0, "unexpected expired at (holder, after)");
        assertEq(policyHolder.beneficiary(policyNftId, payoutIdExpected), address(0), "unexpected beneficiary (holder, after)");
        assertEq(policyHolder.payoutAmount(policyNftId, payoutIdExpected).toInt(), 0, "unexpected amount (holder, after)");
        assertEq(token.balanceOf(beneficiary), 0, "unexpected balance (beneficiary, after)");

        // WHEN - process payout
        product.processPayout(policyNftId, payoutIdExpected);

        // THEN - check callback has now happened
        assertEq(policyHolder.activatedAt(policyNftId).toInt(), activateAt.toInt(), "unexpected activated at (holder, after2)");
        assertEq(policyHolder.expiredAt(policyNftId).toInt(), 0, "unexpected expired at (holder, after2)");
        assertEq(policyHolder.beneficiary(policyNftId, payoutIdExpected), beneficiary, "unexpected beneficiary (holder, after2)");
        assertEq(policyHolder.payoutAmount(policyNftId, payoutIdExpected).toInt(), payoutAmount.toInt(), "unexpected amount (holder, after2)");
        assertEq(token.balanceOf(beneficiary), payoutAmount.toInt(), "unexpected balance (beneficiary, after2)");
    }

    function test_policyHolderPayoutExecutedBeneficiaryZero() public {
        // GIVEN 
        // create active policy
        Timestamp activateAt = TimestampLib.current();
        _createAndActivate(policyNftId, activateAt);

        // create confirmed claim
        Amount claimAmount = AmountLib.toAmount(100);
        (, ClaimId claimId,,) = _makeClaim(policyNftId, claimAmount, true);

        // check that no payout callback has yet happened
        PayoutId payoutIdExpected = PayoutIdLib.toPayoutId(claimId, 1);
        Amount payoutAmount = claimAmount;

        // THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                IClaimService.ErrorClaimServiceBeneficiaryIsZero.selector,
                policyNftId,
                claimId));

        // WHEN - create payout
        product.createPayoutForBeneficiary(policyNftId, claimId, payoutAmount, address(0), "");
    }


    function test_policyHolderPayoutExecutedDefaultCallback() public {
        // GIVEN 
        // create active policy
        Timestamp activateAt = TimestampLib.current();
        _createAndActivate(policyNftId, activateAt);

        address beneficiary = registry.ownerOf(policyNftId);
        uint256 balanceInitial = token.balanceOf(beneficiary);

        // create confirmed claim
        Amount claimAmount = AmountLib.toAmount(100);
        (, ClaimId claimId,,) = _makeClaim(policyNftId, claimAmount, true);

        // check that no payout callback has yet happened
        PayoutId payoutIdExpected = PayoutIdLib.toPayoutId(claimId, 1);
        Amount payoutAmount = claimAmount;

        assertEq(policyHolder.activatedAt(policyNftId).toInt(), activateAt.toInt(), "unexpected activated at (holder, before)");
        assertEq(policyHolder.expiredAt(policyNftId).toInt(), 0, "unexpected expired at (holder, before)");
        assertEq(policyHolder.beneficiary(policyNftId, payoutIdExpected), address(0), "unexpected beneficiary (holder, before)");
        assertEq(policyHolder.payoutAmount(policyNftId, payoutIdExpected).toInt(), 0, "unexpected amount (holder, before)");
        assertEq(token.balanceOf(beneficiary), balanceInitial, "unexpected balance (beneficiary, before)");

        // WHEN - create payout
        PayoutId payoutId = product.createPayout(policyNftId, claimId, payoutAmount, "");

        // THEN
        IPolicy.PayoutInfo memory payoutInfo = instanceReader.getPayoutInfo(policyNftId, payoutId);
        assertEq(payoutInfo.beneficiary, beneficiary, "unexpected beneficiary (info)");

        // check still no callback (only create payout, no tokens moved so far)
        assertEq(payoutId.toInt(), payoutIdExpected.toInt(), "unexpected payout id");
        assertEq(policyHolder.activatedAt(policyNftId).toInt(), activateAt.toInt(), "unexpected activated at (holder, after)");
        assertEq(policyHolder.expiredAt(policyNftId).toInt(), 0, "unexpected expired at (holder, after)");
        assertEq(policyHolder.beneficiary(policyNftId, payoutIdExpected), address(0), "unexpected beneficiary (holder, after)");
        assertEq(policyHolder.payoutAmount(policyNftId, payoutIdExpected).toInt(), 0, "unexpected amount (holder, after)");
        assertEq(token.balanceOf(beneficiary), balanceInitial, "unexpected balance (beneficiary, after)");

        // WHEN - process payout
        product.processPayout(policyNftId, payoutIdExpected);

        // THEN - check callback has now happened
        assertEq(policyHolder.activatedAt(policyNftId).toInt(), activateAt.toInt(), "unexpected activated at (holder, after2)");
        assertEq(policyHolder.expiredAt(policyNftId).toInt(), 0, "unexpected expired at (holder, after2)");
        assertEq(policyHolder.beneficiary(policyNftId, payoutIdExpected), beneficiary, "unexpected beneficiary (holder, after2)");
        assertEq(policyHolder.payoutAmount(policyNftId, payoutIdExpected).toInt(), payoutAmount.toInt(), "unexpected amount (holder, after2)");
        assertEq(token.balanceOf(beneficiary), balanceInitial + payoutAmount.toInt(), "unexpected balance (beneficiary, after2)");
    }

    function _makeClaim(NftId nftId, Amount claimAmount, bool confirm)
        internal
        returns (
            IPolicy.PolicyInfo memory policyInfo,
            ClaimId claimId,
            IPolicy.ClaimInfo memory claimInfo,
            StateId claimState)
    {
        bytes memory claimData = "please pay";
        claimId = product.submitClaim(nftId, claimAmount, claimData); 

        if (confirm) {
            product.confirmClaim(nftId, claimId, claimAmount, ""); 
        }

        policyInfo = instanceReader.getPolicyInfo(policyNftId);
        claimInfo = instanceReader.getClaimInfo(policyNftId, claimId);
        claimState = instanceReader.getClaimState(policyNftId, claimId);
    }

    function _createAndActivate(
        NftId nftId,
        Timestamp activateAt
    )
        internal
    {
        _fundAccount(address(policyHolder));
        _createAllowance(address(policyHolder));

        vm.startPrank(productOwner);
        product.createPolicy(nftId, true, activateAt); 
        vm.stopPrank();
    }


    function _fundAccount(
        address policyHolderAddress
    ) internal {
        vm.startPrank(tokenIssuer);
        token.transfer(policyHolderAddress, CUSTOMER_FUNDS);
        vm.stopPrank();
    }

    function _createAllowance(
        address policyHolderAddress
    ) internal {
        address tokenHandlerAddress = address(instanceReader.getComponentInfo(productNftId).tokenHandler);

        vm.startPrank(policyHolderAddress);
        token.approve(tokenHandlerAddress, CUSTOMER_FUNDS);
        vm.stopPrank();
    }


    function _createApplication(
        address initialOwner,
        uint256 sumInsuredAmount,
        Seconds lifetime
    )
        internal
        returns (NftId)
    {
        return product.createApplication(
            initialOwner,
            riskId,
            sumInsuredAmount,
            lifetime,
            "",
            bundleNftId,
            ReferralLib.zero());
    }
}
