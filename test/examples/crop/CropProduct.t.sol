// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console, console2} from "../../../lib/forge-std/src/Test.sol";

import {IBaseStore} from "../../../contracts/instance/IBaseStore.sol";
import {IPolicy} from "../../../contracts/instance/module/IPolicy.sol";

import {Amount, AmountLib} from "../../../contracts/type/Amount.sol";
import {ClaimId} from "../../../contracts/type/ClaimId.sol";
import {CropBaseTest} from "./CropBase.t.sol";
import {CropProduct} from "../../../contracts/examples/crop/CropProduct.sol";
import {Key32} from "../../../contracts/type/Key32.sol";
import {Location} from "../../../contracts/examples/crop/Location.sol";
import {NftId} from "../../../contracts/type/NftId.sol";
import {PayoutId} from "../../../contracts/type/PayoutId.sol";
import {POLICY} from "../../../contracts/type/ObjectType.sol";
import {RiskId} from "../../../contracts/type/RiskId.sol";
import {Seconds, SecondsLib} from "../../../contracts/type/Seconds.sol";
import {StateId, ACTIVE, COLLATERALIZED, PAID, CLOSED} from "../../../contracts/type/StateId.sol";
import {Str, StrLib} from "../../../contracts/type/String.sol";
import {Timestamp, TimestampLib} from "../../../contracts/type/Timestamp.sol";
import {UFixed, UFixedLib} from "../../../contracts/type/UFixed.sol";

// solhint-disable func-name-mixedcase
contract CropProductTest is CropBaseTest {

    function setUp() public override {
        super.setUp();

        // create and set bundle for flight product
        bundleNftId = _createInitialBundle();

        vm.prank(cropOwner);
        cropProduct.setDefaultBundle(bundleNftId);
    }


    function approveProductTokenHandler() public {
        // approve flight product to buy policies
        vm.startPrank(customer);
        accountingToken.approve(
            address(cropProduct.getTokenHandler()), 
            accountingToken.balanceOf(customer));
        vm.stopPrank();
    }


    function test_cropProductSetup() public {
        // GIVEN - setp from flight base test
        approveProductTokenHandler();
        
        _printAuthz(instance.getInstanceAdmin(), "instance");

        // solhint-disable
        console.log("");
        console.log("crop product", cropProductNftId.toInt(), address(cropProduct));
        console.log("crop product wallet", cropProduct.getWallet());
        console.log("crop pool token handler", address(cropProduct.getTokenHandler()));
        console.log("crop owner", cropOwner);
        console.log("customer", customer);
        console.log("customer balance [$]", accountingToken.balanceOf(customer) / 10 ** accountingToken.decimals());
        console.log("customer allowance [$] (token handler)", accountingToken.allowance(customer, address(cropProduct.getTokenHandler())) / 10 ** accountingToken.decimals());
        // solhint-enable

        // THEN
        assertTrue(accountingToken.allowance(customer, address(cropProduct.getTokenHandler())) > 0, "product allowance zero");
        assertEq(registry.getNftIdForAddress(address(cropProduct)).toInt(), cropProductNftId.toInt(), "unexpected pool nft id");
        assertEq(registry.ownerOf(cropProductNftId), cropOwner, "unexpected product owner");
        assertEq(cropProduct.getWallet(), address(cropProduct.getTokenHandler()), "unexpected product wallet address");
    }


    function test_cropProductCreateSeason() public {
        // GIVEN
        string memory nanoId = "7Zv4TZoBLxUi";
        Str seasonId = StrLib.toStr(nanoId);
        uint16 year = 2025;
        Str name = StrLib.toStr("MainSeasons 2025");
        Str seasonStart = StrLib.toStr("2025-03-25");
        Str seasonEnd = StrLib.toStr("2025-06-30");
        uint16 seasonDays = 110;

        assertEq(cropProduct.seasons().length, 0, "season count not zero");

        // WHEN
        vm.startPrank(productOperator);
        cropProduct.createSeason(seasonId, year, name, seasonStart, seasonEnd, seasonDays);
        vm.stopPrank();

        // THEN
        assertEq(cropProduct.seasons().length, 1, "unexpected season count");
        assertEq(cropProduct.seasons()[0].toString(), nanoId, "unexpected season id");

        CropProduct.Season memory season = cropProduct.getSeason(seasonId);
        assertEq(season.year, year, "unexpected season year");
        assertEq(season.name.toString(), "MainSeasons 2025", "unexpected season name");
        assertEq(season.seasonStart.toString(), "2025-03-25", "unexpected season begin");
        assertEq(season.seasonEnd.toString(), "2025-06-30", "unexpected season end");
        assertEq(season.seasonDays, seasonDays, "unexpected season days");
    }


    function test_cropProductCreateLocation() public {
        // GIVEN
        string memory nanoId = "kDho7606IRdr";
        Str locationId = StrLib.toStr(nanoId);
        int32 latitude = -436500;
        int32 longitude = 31678000;

        // WHEN
        vm.startPrank(productOperator);
        cropProduct.createLocation(locationId, latitude, longitude);
        vm.stopPrank();

        // THEN
        Location location = cropProduct.getLocation(locationId);
        assertEq(locationId.toString(), nanoId, "unexpected location id");
        assertEq(location.latitude(), latitude, "unexpected location latitude");
        assertEq(location.longitude(), longitude, "unexpected location longitude");
    }


    function test_cropProductCreateCrop() public {
        // GIVEN
        string memory cropName = "maize";

        assertEq(cropProduct.crops().length, 0, "crop count not zero");

        // WHEN
        vm.startPrank(productOperator);
        cropProduct.createCrop(StrLib.toStr(cropName));
        vm.stopPrank();

        // THEN
        assertEq(cropProduct.crops().length, 1, "unexpected crop count");
        assertEq(cropProduct.crops()[0].toString(), cropName, "unexpected crop name");
    }


    function test_cropProductCreateRisk() public {
        // GIVEN
        string memory nanoId = "kDho7606IRdr";
        Str riskIdStr = StrLib.toStr(nanoId);
        Str seasonId = _createSeason("7Zv4TZoBLxUi");
        Str locationId = _createLocation("kDho7606IRdr");
        Str crop = _createCrop("maize");
        Timestamp seasonEndAt = TimestampLib.current().addSeconds(SecondsLib.toSeconds(120 days));

        assertEq(instanceReader.risks(cropProductNftId), 0, "risk count not zero");

        // WHEN
        vm.startPrank(productOperator);
        RiskId riskId = cropProduct.createRisk(riskIdStr, seasonId, locationId, crop, seasonEndAt);
        vm.stopPrank();

        // THEN
        assertEq(instanceReader.risks(cropProductNftId), 1, "unexpected risk count");
        assertTrue(instanceReader.getRiskId(cropProductNftId, 0) == riskId, "unexpected risk id");

        (
            bool exists, 
            CropProduct.CropRisk memory risk
        ) = cropProduct.getRisk(riskId);
    
        assertTrue(exists, "risk not found");
        assertEq(risk.seasonId.toString(), seasonId.toString(), "unexpected sesaon id");
        assertEq(risk.locationId.toString(), locationId.toString(), "unexpected location id");
        assertEq(risk.crop.toString(), "maize", "unexpected crop");
        assertTrue(risk.seasonEndAt.gtz(), "unexpected season is 0");
        assertTrue(risk.payoutFactor.eqz(), "payout factor is not 0");
    }


    function test_cropProductRiskPayoutFactorUpdate() public {
        // GIVEN
        string memory nanoId = "kDho7606IRdr";
        RiskId riskId = _createRisk(nanoId);
        UFixed payoutFactor = UFixedLib.toUFixed(35, -2); // 35%

        (bool exists, CropProduct.CropRisk memory riskBefore) = cropProduct.getRisk(riskId);
        assertTrue(exists, "risk not found");
        assertEq(riskBefore.payoutFactor.toInt(), 0, "unexpected payout factor");

        // WHEN
        vm.startPrank(productOperator);
        cropProduct.updatePayoutFactor(riskId, payoutFactor);
        vm.stopPrank();

        (, CropProduct.CropRisk memory riskAfter) = cropProduct.getRisk(riskId);
        _printRisk(riskId, riskAfter);
    }


    function test_cropProductPolicyCreate() public {
        // GIVEN
        string memory nanoId = "kDho7606IRdr";
        RiskId riskId = _createRisk(nanoId);
        Timestamp activateAt = TimestampLib.current();
        Amount sumInsuredAmount = AmountLib.toAmount(400 * 10 ** accountingToken.decimals());
        Amount premiumAmount = AmountLib.toAmount(25 * 10 ** accountingToken.decimals());

        assertEq(instanceReader.policiesForRisk(riskId), 0, "policy count not zero");

        // WHEN
        vm.startPrank(productOperator);
        NftId policyNftId = cropProduct.createPolicy(
            customer,
            riskId, 
            activateAt,
            sumInsuredAmount,
            premiumAmount);
        vm.stopPrank();

        // THEN
        assertEq(instanceReader.policiesForRisk(riskId), 1, "unexpected policy count");
        assertEq(instanceReader.getPolicyForRisk(riskId, 0).toInt(), policyNftId.toInt(), "unexpected policy nft id");

        (, CropProduct.CropRisk memory cropRisk) = cropProduct.getRisk(riskId);
        _printRisk(riskId, cropRisk);
        _printPolicy(policyNftId, instanceReader.getPolicyInfo(policyNftId));

        // TODO add creation checks for this specific policy
        assertEq(instanceReader.getPolicyState(policyNftId).toInt(), COLLATERALIZED().toInt(), "unexpected policy state (not underwritten)");
        IPolicy.PolicyInfo memory info = instanceReader.getPolicyInfo(policyNftId);
        assertEq(info.productNftId.toInt(), cropProductNftId.toInt(), "unexpected product nft id");
        assertEq(info.riskId.toInt(), riskId.toInt(), "unexpected policy risk id");
        assertTrue(info.expiredAt.gtz(), "unexpected policy expired at (is 0)");
    }


    function test_cropProductPolicyClose() public {
        // GIVEN
        NftId policyNftId = _createPolicy(customer);

        IPolicy.PolicyInfo memory info = instanceReader.getPolicyInfo(policyNftId);
        RiskId riskId = info.riskId;
        assertEq(instanceReader.policiesForRisk(riskId), 1, "unexpected policy count");
        assertEq(instanceReader.getPolicyForRisk(riskId, 0).toInt(), policyNftId.toInt(), "unexpected policy nft id");
        assertEq(instanceReader.claims(policyNftId), 0, "unexpected claim count (before)");

        _printPolicy(policyNftId, info);

        uint256 expiryAt = info.expiredAt.toInt();
        vm.warp(expiryAt - 1);

        (, CropProduct.CropRisk memory riskBefore) = cropProduct.getRisk(riskId);
        UFixed payoutFactor = UFixedLib.toUFixed(35, -2); // 35%
        uint256 customerBalanceBefore = accountingToken.balanceOf(customer);

        // WHEN
        vm.startPrank(productOperator);
        cropProduct.updatePayoutFactor(riskId, payoutFactor);
        cropProduct.processPolicy(policyNftId);
        vm.stopPrank();

        // THEN
        info = instanceReader.getPolicyInfo(policyNftId);
        _printPolicy(policyNftId, info);

        assertEq(instanceReader.getPolicyState(policyNftId).toInt(), CLOSED().toInt(), "unexpected policy state (not closed)");
        assertEq(instanceReader.policiesForRisk(riskId), 0, "unexpected policy count");

        // check claim
        assertEq(instanceReader.claims(policyNftId), 1, "unexpected claim count (after)");
        ClaimId claimId = instanceReader.getClaimId(0);
        assertEq(instanceReader.getClaimState(policyNftId, claimId).toInt(), CLOSED().toInt(), "unexpected claim state (not closed)");
        IPolicy.ClaimInfo memory claimInfo = instanceReader.getClaimInfo(policyNftId, claimId);
        assertEq(claimInfo.payoutsCount, 1, "unexpected payouts count");
        assertEq(claimInfo.claimAmount.toInt(), claimInfo.paidAmount.toInt(), "claim and paid amount mismatch");
        Amount payoutAmount = claimInfo.paidAmount;

        // check payout
        assertEq(instanceReader.payouts(policyNftId, claimId), 1, "unexpected payout count");
        PayoutId payoutId = instanceReader.getPayoutId(claimId, 0);
        assertEq(instanceReader.getPayoutState(policyNftId, payoutId).toInt(), PAID().toInt(), "unexpected payout state (not paid)");
        IPolicy.PayoutInfo memory payoutInfo = instanceReader.getPayoutInfo(policyNftId, payoutId);
        assertEq(payoutInfo.claimId.toInt(), claimId.toInt(), "unexpected claim id for payout");
        assertEq(payoutInfo.amount.toInt(), payoutAmount.toInt(), "unexpected payout amount");
        assertTrue(payoutAmount.gtz(), "payout amount is 0");

        // check token balance after payout
        assertEq(accountingToken.balanceOf(customer), customerBalanceBefore + payoutAmount.toInt(), "unexpected customer balance after payout");
    }


    function _createSeason(string memory nanoId) internal returns (Str seasonId) {
        seasonId = StrLib.toStr(nanoId);
        uint16 year = 2025;
        Str name = StrLib.toStr("MainSeasons 2025");
        Str seasonStart = StrLib.toStr("2025-03-25");
        Str seasonEnd = StrLib.toStr("2025-06-30");
        uint16 seasonDays = 110;

        vm.startPrank(productOperator);
        cropProduct.createSeason(seasonId, year, name, seasonStart, seasonEnd, seasonDays);
        vm.stopPrank();
    }


    function _createLocation(string memory nanoId) internal returns (Str locationId) {
        locationId = StrLib.toStr(nanoId);
        int32 latitude = -436500;
        int32 longitude = 31678000;

        vm.startPrank(productOperator);
        cropProduct.createLocation(locationId, latitude, longitude);
        vm.stopPrank();
    }


    function _createCrop(string memory cropName) internal returns (Str crop) {
        crop = StrLib.toStr(cropName);
        vm.startPrank(productOperator);
        cropProduct.createCrop(crop);
        vm.stopPrank();
    }


    function _createRisk(string memory nanoId) internal returns (RiskId riskId) {
        Str riskIdStr = StrLib.toStr(nanoId);
        Str seasonId = _createSeason("7Zv4TZoBLxUi");
        Str locationId = _createLocation("kDho7606IRdr");
        Str crop = _createCrop("maize");
        Timestamp seasonEndAt = TimestampLib.current().addSeconds(SecondsLib.toSeconds(120 days));

        vm.startPrank(productOperator);
        riskId = cropProduct.createRisk(riskIdStr, seasonId, locationId, crop, seasonEndAt);
        vm.stopPrank();
    }


    function _createPolicy(address policyHolder) internal returns (NftId policyNftId) {
        string memory nanoId = "kDho7606IRdr";
        RiskId riskId = _createRisk(nanoId);
        Timestamp activateAt = TimestampLib.current();
        Amount sumInsuredAmount = AmountLib.toAmount(400 * 10 ** accountingToken.decimals());
        Amount premiumAmount = AmountLib.toAmount(25 * 10 ** accountingToken.decimals());

        // WHEN
        vm.startPrank(productOperator);
        policyNftId = cropProduct.createPolicy(
            policyHolder,
            riskId, 
            activateAt,
            sumInsuredAmount,
            premiumAmount);
        vm.stopPrank();
    }
}