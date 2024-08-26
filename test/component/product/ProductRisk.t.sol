// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../../../lib/forge-std/src/Test.sol";

import {GifTest} from "../../base/GifTest.sol";
import {KeyId} from "../../../contracts/type/Key32.sol";
import {NftId} from "../../../contracts/type/NftId.sol";
import {ILifecycle} from "../../../contracts/shared/ILifecycle.sol";
import {SecondsLib} from "../../../contracts/type/Seconds.sol";
import {Timestamp, zeroTimestamp} from "../../../contracts/type/Timestamp.sol";
import {RISK} from "../../../contracts/type/ObjectType.sol";
import {RiskId, RiskIdLib, eqRiskId} from "../../../contracts/type/RiskId.sol";
import {ReferralLib} from "../../../contracts/type/Referral.sol";
import {ACTIVE, PAUSED, ARCHIVED} from "../../../contracts/type/StateId.sol";

contract TestProductRisk is GifTest {

    uint256 public constant BUNDLE_CAPITAL = 5000;
    uint256 public constant SUM_INSURED = 1000;
    uint256 public constant LIFETIME = 365 * 24 * 3600;
    uint256 public constant CUSTOMER_FUNDS = 2000;
    
    RiskId public initialRiskId;
    NftId public initialPolicyNftId;

    function setUp() public override {
        super.setUp();

        _prepareProduct();  

        // create risk
        vm.startPrank(productOwner);
        initialRiskId = product.createRisk("Risk1", abi.encode(1,2,3));
        vm.stopPrank();

        // create application
        initialPolicyNftId = _createApplication(initialRiskId); 

        // fund and approve customer
        vm.startPrank(registryOwner);
        token.transfer(customer, CUSTOMER_FUNDS);
        vm.stopPrank();

        _approve();
    }

    function test_productRiskIdLib() public view {
        // GIVEN
        RiskId riskId = RiskIdLib.toRiskId(productNftId, "Risk1");
        KeyId keyId = RiskIdLib.toKeyId(riskId);
        RiskId riskIdReverse = RiskIdLib.toRiskId(keyId);

        // solhint-disable
        console.log("initialRiskId.toInt()", initialRiskId.toInt());
        console.log("riskIdReverse.toInt()", riskIdReverse.toInt());
        // solhint-enable

        // THEN
        assertTrue(riskId == riskIdReverse, "risk ids not same");
    }

    function test_productRiskSetUp() public {
        // GIVEN
        // WHEN
        // THEN
        // solhint-disable-next-line
        console.log("initialRiskId", initialRiskId.toInt());

        assertEq(instanceReader.risks(productNftId), 1, "unexpected number of risks");
        assertEq(instanceReader.getRiskId(productNftId, 0).toInt(), initialRiskId.toInt(), "unexpected risk id");

        bytes memory riskData = instanceReader.getRiskInfo(initialRiskId).data;
        (uint256 a, uint256 b, uint256 c) = abi.decode(riskData, (uint256, uint256, uint256));
        assertEq(a, 1, "unexpected risk data part 1");
        assertEq(b, 2, "unexpected risk data part 2");
        assertEq(c, 3, "unexpected risk data part 3");

        assertEq(instanceReader.activeRisks(productNftId), 1, "unexpected number of active risks");
        assertEq(instanceReader.getActiveRiskId(productNftId, 0).toInt(), initialRiskId.toInt(), "unexpected active risk id");

        assertEq(initialRiskId.toInt(), RiskIdLib.toRiskId(productNftId, "Risk1").toInt(), "unexpected initial risk id");
        assertEq(instanceReader.getPolicyInfo(initialPolicyNftId).riskId.toInt(), initialRiskId.toInt(), "unexpected risk id for policy");
        assertEq(instanceReader.policiesForRisk(initialRiskId), 0, "unexpected number of policies for risk");
    }

    // create and a new risk with risk data
    function test_productRiskCreate() public {
        // GIVEN
        
        // WHEN
        vm.startPrank(productOwner);
        RiskId newRiskId = product.createRisk("RiskA", abi.encode(4,5,6));
        vm.stopPrank();

        // THEN
        assertEq(instanceReader.risks(productNftId), 2, "unexpected number of risks");
        assertEq(instanceReader.getRiskId(productNftId, 1).toInt(), newRiskId.toInt(), "unexpected new risk id");

        bytes memory riskData = instanceReader.getRiskInfo(newRiskId).data;
        (uint256 a, uint256 b, uint256 c) = abi.decode(riskData, (uint256, uint256, uint256));
        assertEq(a, 4, "unexpected risk data part 1");
        assertEq(b, 5, "unexpected risk data part 2");
        assertEq(c, 6, "unexpected risk data part 3");

        // check active risks
        assertEq(instanceReader.activeRisks(productNftId), 2, "unexpected number of active risks");
        assertEq(instanceReader.getActiveRiskId(productNftId, 0).toInt(), initialRiskId.toInt(), "unexpected active initial risk id");
        assertEq(instanceReader.getActiveRiskId(productNftId, 1).toInt(), newRiskId.toInt(), "unexpected active new risk id");

        // check all risks
        assertEq(newRiskId.toInt(), RiskIdLib.toRiskId(productNftId, "RiskA").toInt(), "unexpected new risk id");
        assertEq(instanceReader.policiesForRisk(initialRiskId), 0, "unexpected number of policies for initial risk");
        assertEq(instanceReader.policiesForRisk(newRiskId), 0, "unexpected number of policies for new risk");

        // check risk state
        assertEq(instanceReader.getRiskState(initialRiskId).toInt(), ACTIVE().toInt(), "unexpected initial risk state");
        assertEq(instanceReader.getRiskState(newRiskId).toInt(), ACTIVE().toInt(), "unexpected new risk state");
    }


    // check pausing and unpausing risks with no policies linked
    function test_productRiskPauseUnpauseNoPolicies() public {
        // GIVEN
        RiskId riskId1 = _createRisk("XYZ1");
        RiskId riskId2 = _createRisk("XYZ2");
        RiskId riskId3 = _createRisk("XYZ3");
        RiskId riskId4 = _createRisk("XYZ4");
        assertEq(instanceReader.getRiskState(riskId1).toInt(), ACTIVE().toInt(), "unexpected new risk state");

        assertEq(instanceReader.risks(productNftId), 5, "unexpected number of risks (before pausing)");
        assertEq(instanceReader.activeRisks(productNftId), 5, "unexpected number of active risks (before pausing)");

        assertEq(instanceReader.policiesForRisk(initialRiskId), 0, "unexpected number of policies for initial risk");
        assertEq(instanceReader.policiesForRisk(riskId1), 0, "unexpected number of policies for risk 1");
        assertEq(instanceReader.policiesForRisk(riskId2), 0, "unexpected number of policies for risk 2");
        assertEq(instanceReader.policiesForRisk(riskId3), 0, "unexpected number of policies for risk 3");
        assertEq(instanceReader.policiesForRisk(riskId4), 0, "unexpected number of policies for risk 4");

        // WHEN pausing
        vm.startPrank(productOwner);
        product.updateRiskState(riskId1, PAUSED());
        product.updateRiskState(riskId3, PAUSED());
        product.updateRiskState(riskId4, PAUSED());
        vm.stopPrank();

        // THEN
        assertEq(instanceReader.risks(productNftId), 5, "unexpected number of risks (after pausing)");
        assertEq(instanceReader.activeRisks(productNftId), 2, "unexpected number of active risks (after pausing)");
        assertEq(instanceReader.getActiveRiskId(productNftId, 0).toInt(), initialRiskId.toInt(), "unexpected active risk id 1");
        assertEq(instanceReader.getActiveRiskId(productNftId, 1).toInt(), riskId2.toInt(), "unexpected active risk id 2");

        // WHEN re-activating
        vm.startPrank(productOwner);
        product.updateRiskState(riskId1, ACTIVE());
        product.updateRiskState(riskId3, ACTIVE());
        vm.stopPrank();

        // THEN
        assertEq(instanceReader.risks(productNftId), 5, "unexpected number of risks (after re-activating)");
        assertEq(instanceReader.activeRisks(productNftId), 4, "unexpected number of active risks (after re-activating)");
        assertEq(instanceReader.getActiveRiskId(productNftId, 0).toInt(), initialRiskId.toInt(), "unexpected active new risk id");
        assertEq(instanceReader.getActiveRiskId(productNftId, 1).toInt(), riskId2.toInt(), "unexpected active new risk id");
        assertEq(instanceReader.getActiveRiskId(productNftId, 2).toInt(), riskId1.toInt(), "unexpected active new risk id");
        assertEq(instanceReader.getActiveRiskId(productNftId, 3).toInt(), riskId3.toInt(), "unexpected active new risk id");
    }

    // check pausing and unpausing risks with policies linked
    function test_productRiskPauseUnpauseWithPolicies() public {
        // GIVEN

        // create and check risks
        RiskId riskId1 = _createRisk("XYZ1");
        RiskId riskId2 = _createRisk("XYZ2");
        assertEq(instanceReader.getRiskState(riskId1).toInt(), ACTIVE().toInt(), "unexpected new risk state");

        assertEq(instanceReader.risks(productNftId), 3, "unexpected number of risks (before pausing)");
        assertEq(instanceReader.activeRisks(productNftId), 3, "unexpected number of active risks (before pausing)");

        assertEq(instanceReader.policiesForRisk(initialRiskId), 0, "unexpected number of policies for initial risk");
        assertEq(instanceReader.policiesForRisk(riskId1), 0, "unexpected number of policies for risk 1");
        assertEq(instanceReader.policiesForRisk(riskId2), 0, "unexpected number of policies for risk 2");

        // create and check policies
        NftId policyNftId1 = _createPolicy(initialRiskId);
        NftId policyNftId2 = _createPolicy(riskId1);
        NftId policyNftId3 = _createPolicy(riskId1);

        assertEq(instanceReader.policiesForRisk(initialRiskId), 1, "unexpected number of policies for initial risk (after creating policies)");
        assertEq(instanceReader.policiesForRisk(riskId1), 2, "unexpected number of policies for risk 1 (after creating policies)");
        assertEq(instanceReader.policiesForRisk(riskId2), 0, "unexpected number of policies for risk 2 (after creating policies)");

        // WHEN pausing
        vm.startPrank(productOwner);
        product.updateRiskState(riskId1, PAUSED());
        vm.stopPrank();

        // THEN
        assertEq(instanceReader.risks(productNftId), 3, "unexpected number of risks (after pausing)");
        assertEq(instanceReader.activeRisks(productNftId), 2, "unexpected number of active risks (after pausing)");
        assertEq(instanceReader.getActiveRiskId(productNftId, 0).toInt(), initialRiskId.toInt(), "unexpected active risk id 1 (after pausing)");
        assertEq(instanceReader.getActiveRiskId(productNftId, 1).toInt(), riskId2.toInt(), "unexpected active risk id 2 (after pausing)");

        assertEq(instanceReader.policiesForRisk(initialRiskId), 1, "unexpected number of policies for initial risk (after creating policies)");
        assertEq(instanceReader.policiesForRisk(riskId1), 2, "unexpected number of policies for risk 1 (after creating policies)");
        assertEq(instanceReader.policiesForRisk(riskId2), 0, "unexpected number of policies for risk 2 (after creating policies)");

        // WHEN re-activating
        vm.startPrank(productOwner);
        product.updateRiskState(riskId1, ACTIVE());
        vm.stopPrank();

        // THEN
        assertEq(instanceReader.risks(productNftId), 3, "unexpected number of risks (after re-activating)");
        assertEq(instanceReader.activeRisks(productNftId), 3, "unexpected number of active risks (after re-activating)");
        assertEq(instanceReader.getActiveRiskId(productNftId, 0).toInt(), initialRiskId.toInt(), "unexpected active risk id 1 (after re-activating)");
        assertEq(instanceReader.getActiveRiskId(productNftId, 1).toInt(), riskId2.toInt(), "unexpected active new id 2 (after re-activating)");
        assertEq(instanceReader.getActiveRiskId(productNftId, 2).toInt(), riskId1.toInt(), "unexpected active new id 3 (after re-activating)");

        assertEq(instanceReader.policiesForRisk(initialRiskId), 1, "unexpected number of policies for initial risk (after creating policies)");
        assertEq(instanceReader.policiesForRisk(riskId1), 2, "unexpected number of policies for risk 1 (after creating policies)");
        assertEq(instanceReader.policiesForRisk(riskId2), 0, "unexpected number of policies for risk 2 (after creating policies)");
    }

    // check risk lifecycle
    function test_productRiskLifecycle1() public {
        // GIVEN
        RiskId riskId = _createRisk("XYZ");
        assertEq(instanceReader.getRiskState(riskId).toInt(), ACTIVE().toInt(), "unexpected new risk state");

        // WHEN + THEN (activec -> paused)
        vm.prank(productOwner);
        product.updateRiskState(riskId, PAUSED());
        assertEq(instanceReader.getRiskState(riskId).toInt(), PAUSED().toInt(), "risk not paused");

        // WHEN + THEN (paused -> active)
        vm.prank(productOwner);
        product.updateRiskState(riskId, ACTIVE());
        assertEq(instanceReader.getRiskState(riskId).toInt(), ACTIVE().toInt(), "risk not active");
    }

    // check risk lifecycle
    function test_productRiskLifecycle2() public {
        // GIVEN
        RiskId riskId = _createRisk("XYZ");
        assertEq(instanceReader.getRiskState(riskId).toInt(), ACTIVE().toInt(), "unexpected new risk state");

        // WHEN + THEN (activec -> paused)
        vm.prank(productOwner);
        product.updateRiskState(riskId, PAUSED());
        assertEq(instanceReader.getRiskState(riskId).toInt(), PAUSED().toInt(), "risk not paused");

        // WHEN + THEN (paused -> archived)
        vm.prank(productOwner);
        product.updateRiskState(riskId, ARCHIVED());
        assertEq(instanceReader.getRiskState(riskId).toInt(), ARCHIVED().toInt(), "risk not active");
    }

    // check risk lifecycle
    function test_productRiskLifecycleActiveToArchivedError() public {
        // GIVEN
        RiskId riskId = _createRisk("XYZ");
        assertEq(instanceReader.getRiskState(riskId).toInt(), ACTIVE().toInt(), "unexpected new risk state");

        // WHEN + THEN (active -> archived)
        vm.expectRevert(
            abi.encodeWithSelector(
                ILifecycle.ErrorInvalidStateTransition.selector,
                address(instanceStore),
                RISK(),
                ACTIVE(),
                ARCHIVED()));

        vm.prank(productOwner);
        product.updateRiskState(riskId, ARCHIVED());
    }

    // check risk lifecycle
    function test_productRiskLifecycleArchivedToActiveError() public {
        // GIVEN
        RiskId riskId = _createRisk("XYZ");

        vm.startPrank(productOwner);
        product.updateRiskState(riskId, PAUSED());
        product.updateRiskState(riskId, ARCHIVED());
        vm.stopPrank();

        assertEq(instanceReader.getRiskState(riskId).toInt(), ARCHIVED().toInt(), "unexpected new risk state");

        // WHEN + THEN (archived -> active)
        vm.expectRevert(
            abi.encodeWithSelector(
                ILifecycle.ErrorInvalidStateTransition.selector,
                address(instanceStore),
                RISK(),
                ARCHIVED(),
                ACTIVE()));

        vm.prank(productOwner);
        product.updateRiskState(riskId, ACTIVE());
    }

    // check risk lifecycle
    function test_productRiskLifecycleArchivedToPausedError() public {
        // GIVEN
        RiskId riskId = _createRisk("XYZ");

        vm.startPrank(productOwner);
        product.updateRiskState(riskId, PAUSED());
        product.updateRiskState(riskId, ARCHIVED());
        vm.stopPrank();

        assertEq(instanceReader.getRiskState(riskId).toInt(), ARCHIVED().toInt(), "unexpected new risk state");

        // WHEN + THEN (archived -> paused)
        vm.expectRevert(
            abi.encodeWithSelector(
                ILifecycle.ErrorInvalidStateTransition.selector,
                address(instanceStore),
                RISK(),
                ARCHIVED(),
                PAUSED()));

        vm.prank(productOwner);
        product.updateRiskState(riskId, PAUSED());
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

    function _createPolicy(RiskId riskId)
        internal
        returns (NftId policyNftId)
    {
        policyNftId = _createApplication(riskId);
        _collateralize(policyNftId, true, zeroTimestamp());
    }

    function _createApplication(RiskId riskId)
        internal
        returns (NftId)
    {
        return product.createApplication(
            customer,
            riskId,
            SUM_INSURED,
            SecondsLib.toSeconds(LIFETIME),
            "",
            bundleNftId,
            ReferralLib.zero());
    }

    // create risk from string for product
    function _createRisk(string memory riskName) internal returns (RiskId riskId) {
        // solhint-disable-next-line
        console.log("creating risk", riskName, riskId.toInt());

        vm.startPrank(productOwner);
        riskId = product.createRisk(riskName, "");
        vm.stopPrank();
    }

}
