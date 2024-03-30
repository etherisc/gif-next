// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {TestGifBase} from "../../base/TestGifBase.sol";

import {NftId} from "../../../contracts/types/NftId.sol";
import {DistributorType} from "../../../contracts/types/DistributorType.sol";
import {ReferralId} from "../../../contracts/types/Referral.sol";
import {Timestamp, toTimestamp} from "../../../contracts/types/Timestamp.sol";
import {UFixed, UFixedLib} from "../../../contracts/types/UFixed.sol";
import {SimpleDistribution} from "../../mock/SimpleDistribution.sol";
import {FeeLib} from "../../../contracts/types/Fee.sol";
import {DISTRIBUTION_OWNER_ROLE} from "../../../contracts/types/RoleId.sol";

contract ReferralTestBase is TestGifBase {

    DistributorType public distributorType;
    string public name;
    UFixed public minDiscountPercentage;
    UFixed public maxDiscountPercentage;
    UFixed public commissionPercentage;
    uint32 public maxReferralCount;
    uint32 public maxReferralLifetime;
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

    function _prepareDistribution() internal {
        vm.startPrank(instanceOwner);
        instanceAccessManager.grantRole(DISTRIBUTION_OWNER_ROLE(), distributionOwner);
        vm.stopPrank();

        vm.startPrank(distributionOwner);
        distribution = new SimpleDistribution(
            address(registry),
            instanceNftId,
            address(token),
            FeeLib.toFee(UFixedLib.toUFixed(5,-2), 0),
            FeeLib.toFee(UFixedLib.toUFixed(2,-1), 0),
            distributionOwner
        );
        distributionNftId = distributionService.register(address(distribution));
    }

    function _setupTestData(bool createDistributor) internal {
        if (address(distribution) == address(0)) {
            _prepareDistribution();
        }

        name = "Basic";
        minDiscountPercentage = instanceReader.toUFixed(5, -2);
        maxDiscountPercentage = instanceReader.toUFixed(75, -3);
        commissionPercentage = instanceReader.toUFixed(3, -2);
        maxReferralCount = 20;
        maxReferralLifetime = 14 * 24 * 3600;
        allowSelfReferrals = true;
        allowRenewals = true;
        data = ".";
        distributorData = "..";

        referralCode = "SAVE!!!";
        discountPercentage = instanceReader.toUFixed(5, -2);
        maxReferrals = 10;
        expiryAt = toTimestamp(block.timestamp + 7 * 24 * 3600);
        referralData = "...";

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
    }
}