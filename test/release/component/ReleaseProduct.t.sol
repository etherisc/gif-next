// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {Vm, console} from "../../../lib/forge-std/src/Test.sol";

import {GifTest} from "../../base/GifTest.sol";
import {AccessManagerCloneable} from "../../../contracts/authorization/AccessManagerCloneable.sol";
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
import {Timestamp, TimestampLib} from "../../../contracts/type/Timestamp.sol";
import {IPolicyService} from "../../../contracts/product/IPolicyService.sol";
import {IRisk} from "../../../contracts/instance/module/IRisk.sol";
import {PayoutId, PayoutIdLib} from "../../../contracts/type/PayoutId.sol";
import {POLICY} from "../../../contracts/type/ObjectType.sol";
import {RiskId, RiskIdLib, eqRiskId} from "../../../contracts/type/RiskId.sol";
import {ReferralId, ReferralLib} from "../../../contracts/type/Referral.sol";
import {APPLIED, SUBMITTED, ACTIVE, COLLATERALIZED, CONFIRMED, DECLINED, CLOSED, REVOKED} from "../../../contracts/type/StateId.sol";
import {StateId} from "../../../contracts/type/StateId.sol";
import {VersionPart, VersionPartLib} from "../../../contracts/type/Version.sol";

contract ReleaseProductTest is GifTest {

    uint256 public constant BUNDLE_CAPITAL = 5000;
    uint256 public constant SUM_INSURED = 1000;
    uint256 public constant CUSTOMER_FUNDS = 400;

    uint256 public constant LIFETIME = 30 * 24 * 3600;

    VersionPart public RELEASE_3 = VersionPartLib.toVersionPart(3);
    Seconds public lifetime = SecondsLib.toSeconds(LIFETIME);
    Timestamp public activateAt = TimestampLib.blockTimestamp();
    ReferralId public referralIdZero = ReferralLib.zero();
    Amount public claimAmount = AmountLib.toAmount(100);

    RiskId public riskId;
    NftId public applicationNftId;
    NftId public policyNftId;

    function setUp() public override {
        super.setUp();

        _prepareProduct();  

        // create objects
        riskId = _createRisk("RiskSetUp");
        applicationNftId = _createApplication(); 
        policyNftId = _createPolicy(false);

        // transfer and approve funds
        vm.startPrank(registryOwner);
        token.transfer(customer, CUSTOMER_FUNDS);
        vm.stopPrank();
        vm.startPrank(customer);
        token.approve(address(product.getTokenHandler()), CUSTOMER_FUNDS);
        vm.stopPrank();
    }

    function test_releaseProductRiskCreateActiveInactive() public {
        // GIVEN release active

        RiskId riskId =_createRisk("RiskWhileReleaseActive");
        assertTrue(riskId.gtz(), "new risk id zero");

        // WHEN release is locked
        vm.startPrank(registryOwner);
        releaseRegistry.setActive(RELEASE_3, false);
        vm.stopPrank();

        // THEN risk creation fails
        
        // product -[X]-> riskService
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessManaged.AccessManagedUnauthorized.selector, 
                address(product)));

        vm.startPrank(productOwner);
        RiskId riskId2 = product.createRisk("RiskWhileReleaseInactive", "");
        vm.stopPrank();

        assertTrue(instanceReader.getRiskInfo(riskId2).createdAt.eqz(), "new risk unexpectedly created");
    }

    function test_releaseProductApplicationCreateActiveInactive() public {
        // GIVEN release active

        NftId applNftId =_createApplication(); 
        assertTrue(applNftId.gtz(), "application nft id zero");

        // WHEN release is locked
        vm.startPrank(registryOwner);
        releaseRegistry.setActive(RELEASE_3, false);
        vm.stopPrank();

        // THEN 
        // applicationService -[X]-> registryService.registerPolicy
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessManaged.AccessManagedUnauthorized.selector, 
                address(applicationService)));

        NftId newApplNftId =_createApplication(); 
        assertTrue(newApplNftId.eqz(), "new application nft id not zero");
    }


    function test_releaseProductApplicationCollateralizeActiveInactive() public {

        NftId applNftId1 =_createApplication(); 
        NftId applNftId2 =_createApplication(); 
        assertTrue(applNftId1.gtz(), "new application nft id 1 zero");
        assertTrue(applNftId2.gtz(), "new application nft id 2 zero");

        product.createPolicy(applNftId1, false, activateAt); 
        assertEq(instanceReader.getPolicyState(applNftId1).toInt(), COLLATERALIZED().toInt(), "1 not collateralized");
        assertEq(instanceReader.getPolicyState(applNftId2).toInt(), APPLIED().toInt(), "2 not applied");

        // WHEN release is locked
        vm.startPrank(registryOwner);
        releaseRegistry.setActive(RELEASE_3, false);
        vm.stopPrank();

        // THEN 
        // policyService -[X]-> poolService.lockCollateral
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessManaged.AccessManagedUnauthorized.selector, 
                address(policyService)));

        product.createPolicy(applNftId2, false, activateAt); 
        assertEq(instanceReader.getPolicyState(applNftId1).toInt(), COLLATERALIZED().toInt(), "1 not collateralized (after)");
        assertEq(instanceReader.getPolicyState(applNftId2).toInt(), APPLIED().toInt(), "2 not applied (after)");

        // THEN
        // policyService -[X]-> accountingService.increaseProductFees
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessManaged.AccessManagedUnauthorized.selector, 
                address(policyService)));

        product.collectPremium(applNftId1, activateAt);
    }

    function test_releaseProductClaimSubmitActiveInactive() public {

        NftId plcylNftId1 =_createPolicy(false); 
        NftId plcylNftId2 =_createPolicy(false); 
        assertTrue(plcylNftId1.gtz(), "new policy nft id 1 zero");
        assertTrue(plcylNftId2.gtz(), "new policy nft id 2 zero");

        product.submitClaim(plcylNftId1, claimAmount, ""); 
        assertEq(instanceReader.getPolicyInfo(plcylNftId1).claimsCount, 1, "1 claim expected (1)");
        assertEq(instanceReader.getPolicyInfo(plcylNftId2).claimsCount, 0, "0 claims expected (2)");

        // WHEN release is locked
        vm.startPrank(registryOwner);
        releaseRegistry.setActive(RELEASE_3, false);
        vm.stopPrank();

        // THEN 
        // product -[X]-> claimService
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessManaged.AccessManagedUnauthorized.selector, 
                address(product)));

        product.submitClaim(plcylNftId2, claimAmount, ""); 
        assertEq(instanceReader.getPolicyInfo(plcylNftId1).claimsCount, 1, "1 claim expected (1)");
        assertEq(instanceReader.getPolicyInfo(plcylNftId2).claimsCount, 0, "0 claims expected (2)");
    }

    function _createRisk(string memory riskName) internal returns (RiskId rskId) {
        vm.startPrank(productOwner);
        rskId = product.createRisk(riskName, "");
        vm.stopPrank();
    }

    // add allowance to pay premiums
    function _approve() internal {
        address tokenHandlerAddress = address(instanceReader.getComponentInfo(productNftId).tokenHandler);

        vm.startPrank(customer);
        token.approve(tokenHandlerAddress, CUSTOMER_FUNDS);
        vm.stopPrank();
    }


    function _createApplication()
        internal
        returns (NftId)
    {
        return product.createApplication(
            customer,
            riskId,
            SUM_INSURED,
            lifetime,
            "",
            bundleNftId,
            referralIdZero);
    }


    function _createPolicy(bool collectPremium)
        internal
        returns (NftId plcyNftId)
    {
        plcyNftId = _createApplication();
        product.createPolicy(plcyNftId, collectPremium, activateAt); 
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
}