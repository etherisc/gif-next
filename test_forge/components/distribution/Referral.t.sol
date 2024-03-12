// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../../../lib/forge-std/src/Test.sol";
import {ReferralTestBase} from "./ReferralTestBase.sol";

import {ReferralLib} from "../../../contracts/types/Referral.sol";

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

        assertTrue(distribution.referralIsValid(referralId), "referral is not valid");
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

        assertFalse(distribution.referralIsValid(ReferralLib.toReferralId(distributionNftId, "UNKNOWN")), "referral is valid");
    }

}