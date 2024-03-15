// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../../../lib/forge-std/src/Test.sol";
import {FeeLib} from "../../../contracts/types/Fee.sol";
import {IPolicy} from "../../../contracts/instance/module/IPolicy.sol";
import {ReferralLib} from "../../../contracts/types/Referral.sol";
import {ReferralTestBase} from "./ReferralTestBase.sol";

contract ReferralTest is ReferralTestBase {

    function test_Distribution_referralIsValid_true() public {
        _setupTestData(true);

        // solhint-disable-next-line 
        console.log("distributor nft id", distributorNftId.toInt());

        referralId = distribution.createReferral(
            distributorNftId,
            referralCode,
            discountPercentage,
            maxReferrals,
            expiryAt,
            referralData);

        assertTrue(distributionService.referralIsValid(distributionNftId, referralId), "referral is not valid");
    }

    function test_Distribution_referralIsValid_false() public {
        _setupTestData(true);

        // solhint-disable-next-line 
        console.log("distributor nft id", distributorNftId.toInt());

        referralId = distribution.createReferral(
            distributorNftId,
            referralCode,
            discountPercentage,
            maxReferrals,
            expiryAt,
            referralData);

        assertFalse(distributionService.referralIsValid(distributionNftId, ReferralLib.toReferralId(distributionNftId, "UNKNOWN")), "referral is valid");
    }

    // FIXME: fix this
    // function test_Distribution_calculateFeeAmount_distributionFeeOnly() public {
    //     _setupTestData(true);

    //     // solhint-disable-next-line 
    //     console.log("distributor nft id", distributorNftId.toInt());

    //     referralId = distribution.createReferral(
    //         distributorNftId,
    //         referralCode,
    //         discountPercentage,
    //         maxReferrals,
    //         expiryAt,
    //         referralData);

    //     IPolicy.Premium memory premium = IPolicy.Premium(
    //         1000, 
    //         1000,
    //         0,
    //         0, 0, 0, 0,
    //         0, 0, 0, 0, 
    //         0, 0, 0, 0);

    //     premium = distributionService.calculateFeeAmount(distributionNftId, ReferralLib.zero(), premium);
    //     assertEq(premium.distributionOwnerFeeFixAmount + premium.distributionOwnerFeeVarAmount, 50, "distributionOwnerFeeAmount amount is not correct");
    //     assertEq(premium.commissionAmount, 0, "commissionAmount amount is not correct");
    //     assertEq(premium.discountAmount, 0, "discountAmount amount is not correct");
    //     assertEq(premium.fullPremiumAmount, 1050, "fullPremium amount is not correct");
    //     assertEq(premium.premiumAmount, 1050, "premium amount is not correct");
    // }

    // FIXME: fix this
    // function test_Distribution_calculateFeeAmount_withReferral() public {
    //     _setupTestData(true);

    //     // solhint-disable-next-line 
    //     console.log("distributor nft id", distributorNftId.toInt());

    //     referralId = distribution.createReferral(
    //         distributorNftId,
    //         referralCode,
    //         discountPercentage,
    //         maxReferrals,
    //         expiryAt,
    //         referralData);

    //     IPolicy.Premium memory premium = IPolicy.Premium(
    //         1000, 
    //         1000, 
    //         0,
    //         0, 0, 0, 0,
    //         0, 0, 0, 0, 
    //         0, 0, 0, 0);

    //     premium = distributionService.calculateFeeAmount(distributionNftId, referralId, premium);
    //     assertEq(premium.distributionOwnerFeeFixAmount + premium.distributionOwnerFeeVarAmount, 100, "distributionOwnerFeeAmount amount is not correct");
    //     assertEq(premium.commissionAmount, 30, "commissionAmount amount is not correct");
    //     assertEq(premium.discountAmount, 57, "discountAmount amount is not correct");
    //     assertEq(premium.fullPremiumAmount, 1130, "fullPremium amount is not correct");
    //     assertEq(premium.premiumAmount, 1073, "premium amount is not correct");
    //     // assertEq(feeAmount, 100, "fee amount is not correct");
    //     // assertEq(commissionAmount, 30, "commission amount is not correct");
    // }

}