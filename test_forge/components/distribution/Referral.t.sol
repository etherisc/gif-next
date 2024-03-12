// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../../../lib/forge-std/src/Test.sol";
import {FeeLib} from "../../../contracts/types/Fee.sol";
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

    function test_Distribution_calculateFeeAmount_distributionFeeOnly() public {
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

        uint256 feeAmount = distributionService.calculateFeeAmount(distributionNftId, ReferralLib.zero(), 1000);
        assertEq(feeAmount, 100, "fee amount is not correct");
    }

    function test_Distribution_calculateFeeAmount_referralDiscount() public {
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

        uint256 feeAmount = distributionService.calculateFeeAmount(distributionNftId, referralId, 1000);
        assertEq(feeAmount, 50, "fee amount is not correct");
    }

}