// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {GifClusterTest} from "../../base/GifClusterTest.sol";
import {NftId} from "../../../contracts/type/NftId.sol";
import {Amount, AmountLib} from "../../../contracts/type/Amount.sol";
import {FeeLib} from "../../../contracts/type/Fee.sol";
import {UFixedLib} from "../../../contracts/type/UFixed.sol";
import {DistributorType} from "../../../contracts/type/DistributorType.sol";
import {ReferralId} from "../../../contracts/type/Referral.sol";
import {RiskId, RiskIdLib} from "../../../contracts/type/RiskId.sol";
import {Seconds, SecondsLib} from "../../../contracts/type/Seconds.sol";
import {TimestampLib} from "../../../contracts/type/Timestamp.sol";
import {IDistributionService} from "../../../contracts/distribution/IDistributionService.sol";

// solhint-disable func-name-mixedcase
contract PricingServiceClusterTest is GifClusterTest {

    function setUp() public virtual override {
        super.setUp();

        INSTANCE_OWNER_FUNDING = 1000000 * 10 ** token.decimals();
        _setupProductClusters1and2();

        vm.startPrank(instanceOwner);
        token.approve(address(myPool2.getTokenHandler()), 1000000);
        (bundleNftId,) = myPool2.createBundle(
            FeeLib.zero(), 
            1000000, 
            SecondsLib.toSeconds(30 * 24 * 3600), 
            "");
        vm.stopPrank();
    }

    function test_pricingServiceCalculatePremium_referralFromOtherProductCluster() public {
        // GIVEN
        vm.startPrank(instanceOwner);
        DistributorType distributorType = myDistribution1.createDistributorType(
            "Gold",
            UFixedLib.zero(),
            UFixedLib.toUFixed(10, -2),
            UFixedLib.toUFixed(5, -2),
            10,
            SecondsLib.toSeconds(14 * 24 * 3600),
            false,
            false,
            "");

        NftId distributorNftId = myDistribution1.createDistributor(
            customer,
            distributorType,
            "");
        vm.stopPrank();

        vm.startPrank(customer);
        ReferralId referralId = myDistribution1.createReferral(
            "GET_A_DISCOUNT",
            UFixedLib.toUFixed(10, -2),
            5,
            TimestampLib.blockTimestamp().addSeconds(SecondsLib.toSeconds(604800)),
            "");
        vm.stopPrank();

        RiskId riskId2 = myProduct2.createRisk("42x4711", "");
        Amount sumInsured = AmountLib.toAmount(1000);
        Seconds lifetime = SecondsLib.toSeconds(300);

        // THEN
        vm.expectRevert(abi.encodeWithSelector(
            IDistributionService.ErrorDistributionServiceReferralDistributionMismatch.selector, 
            referralId,
            myDistributionNftId1,
            myDistributionNftId2));

        // WHEN
        pricingService.calculatePremium(
            myProductNftId2, 
            riskId2, 
            sumInsured, 
            lifetime, 
            "",
            bundleNftId,
            referralId);
    }


}