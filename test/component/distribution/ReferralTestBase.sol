// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {GifTest} from "../../base/GifTest.sol";

import {NftId} from "../../../contracts/type/NftId.sol";
import {DistributorType} from "../../../contracts/type/DistributorType.sol";
import {FeeLib} from "../../../contracts/type/Fee.sol";
import {ReferralId} from "../../../contracts/type/Referral.sol";
import {SimpleDistribution} from "../../../contracts/examples/unpermissioned/SimpleDistribution.sol";
import {Seconds, SecondsLib} from "../../../contracts/type/Seconds.sol";
import {Timestamp, TimestampLib} from "../../../contracts/type/Timestamp.sol";
import {UFixed, UFixedLib} from "../../../contracts/type/UFixed.sol";

contract ReferralTestBase is GifTest {

    DistributorType public distributorType;
    string public name;
    UFixed public minDiscountPercentage;
    UFixed public maxDiscountPercentage;
    UFixed public commissionPercentage;
    uint32 public maxReferralCount;
    Seconds public maxReferralLifetime;
    bool public allowSelfReferrals;
    bool public allowRenewals;
    bytes public data;

    NftId public distributorNftId;
    bytes public distributorData;

    ReferralId public referralId;
    string public referralCode;
    UFixed public discountPercentage;
    uint32 public maxReferrals;
    Timestamp public expiryAt;
    bytes public referralData;

    function _setupTestData(bool createDistributor) internal {

        vm.startPrank(distributionOwner);
        distribution.setFees(
            FeeLib.toFee(UFixedLib.toUFixed(2,-1), 0), 
            FeeLib.toFee(UFixedLib.toUFixed(5,-2), 0));
        vm.stopPrank();

        name = "Basic";
        minDiscountPercentage = instanceReader.toUFixed(5, -2);
        maxDiscountPercentage = instanceReader.toUFixed(75, -3);
        commissionPercentage = instanceReader.toUFixed(3, -2);
        maxReferralCount = 20;
        maxReferralLifetime = SecondsLib.toSeconds(14 * 24 * 3600);
        allowSelfReferrals = true;
        allowRenewals = true;
        data = ".";
        distributorData = "..";

        referralCode = "SAVE!!!";
        discountPercentage = instanceReader.toUFixed(5, -2);
        maxReferrals = 10;
        expiryAt = TimestampLib.toTimestamp(block.timestamp + 7 * 24 * 3600);
        referralData = "...";

        vm.startPrank(distributionOwner);
        distributorType = distribution.createDistributorType(
            name,
            minDiscountPercentage,
            maxDiscountPercentage,
            commissionPercentage,
            maxReferralCount,
            maxReferralLifetime,
            allowSelfReferrals,
            allowRenewals,
            data);

        if (createDistributor) {
            distributorNftId = distribution.createDistributor(
                customer,
                distributorType,
                distributorData);
        }
        vm.stopPrank();
    }
}
