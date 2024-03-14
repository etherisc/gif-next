// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../../../lib/forge-std/src/Test.sol";
import {TestGifBase} from "../../base/TestGifBase.sol";

import {NftId} from "../../../contracts/types/NftId.sol";
import {DistributorType} from "../../../contracts/types/DistributorType.sol";
import {IDistribution} from "../../../contracts/instance/module/IDistribution.sol";
import {ReferralId, ReferralStatus, REFERRAL_OK, REFERRAL_ERROR_UNKNOWN} from "../../../contracts/types/Referral.sol";
import {Timestamp, toTimestamp} from "../../../contracts/types/Timestamp.sol";
import {UFixed, UFixedLib} from "../../../contracts/types/UFixed.sol";
import {SimpleDistribution} from "../../mock/SimpleDistribution.sol";
import {FeeLib} from "../../../contracts/types/Fee.sol";
import {DISTRIBUTION_OWNER_ROLE} from "../../../contracts/types/RoleId.sol";

contract DistributorTest is TestGifBase {

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


    function testGifSetupReferralUnknown() public {
        _prepareDistribution();

        string memory invalidCode = "some_invalid_referral_code";
        // solhint-disable-next-line 
        console.log("invalid referral code", invalidCode);

        (
            UFixed discountFromCode,
            ReferralStatus statusFromCode
        ) = distribution.getDiscountPercentage(invalidCode);

        assertEq(UFixed.unwrap(discountFromCode), 0, "unexpected discount for invalid code");
        assertEq(
            uint(ReferralStatus.unwrap(statusFromCode)), 
            uint(ReferralStatus.unwrap(REFERRAL_ERROR_UNKNOWN())),
            "invalid referral code not unknown");
    }

    function testGifSetupReferralCreate() public {
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

        // solhint-disable-next-line 
        console.log("referral id", vm.toString(ReferralId.unwrap(referralId)));        

        (
            UFixed discountFromCode,
            ReferralStatus statusFromCode
        ) = distribution.getDiscountPercentage(referralCode);
        assertTrue(discountFromCode == discountPercentage, "unexpected referral discount");
        // solhint-disable-next-line 
        console.log("referral discount", UFixed.unwrap(discountFromCode));        
        assertTrue(statusFromCode == REFERRAL_OK(), "unexpected referral status");
        // solhint-disable-next-line 
        console.log("referral status", uint(ReferralStatus.unwrap(statusFromCode)));        

        IDistribution.ReferralInfo memory info = instanceReader.getReferralInfo(referralId);

        // solhint-disable-next-line 
        console.log("info distributor nft id", info.distributorNftId.toInt());
        assertTrue(info.distributorNftId == distributorNftId, "unexpected distributor nft id");
        assertEq(registry.ownerOf(info.distributorNftId), customer, "unexpected referral owner");

        // solhint-disable-next-line 
        console.log("referral code", info.referralCode);
        assertTrue(
            equalStrings(info.referralCode, referralCode),
            "unexpected referral code");

        assertTrue(info.discountPercentage == discountPercentage, "unexpected discount percentage");
        // solhint-disable-next-line 
        console.log("referral discount percentage", UFixed.unwrap(info.discountPercentage));        

        assertTrue(info.maxReferrals == maxReferrals, "unexpected max referrals");
        assertTrue(info.usedReferrals == 0, "used referrals not 0");
        // solhint-disable-next-line 
        console.log("max referrals", info.maxReferrals);        

        assertTrue(info.expiryAt == expiryAt, "unexpected expiry at");
        assertTrue(
            equalBytes(info.data, referralData), 
            "unexpected data for referral");
    }


    function testGifSetupDistributorCreateTwice() public {
        _prepareDistribution();
        assertTrue(!distribution.isDistributor(customer), "customer is already distributor");
        _setupTestData(true);
        assertTrue(distribution.isDistributor(customer), "customer still not distributor");

        vm.expectRevert("ERROR:DST-030:ALREADY_DISTRIBUTOR");
        distributorNftId = distribution.createDistributor(
            customer,
            distributorType,
            distributorData);
    }


    function testGifSetupDistributorCreateTransfer() public {
        _prepareDistribution();

        assertTrue(!distribution.isDistributor(customer), "customer is already distributor");
        _setupTestData(true);

        assertTrue(distribution.isDistributor(customer), "customer still not distributor");
        assertEq(registry.ownerOf(distributorNftId), customer, "unexpected distributor nft owner");
        assertTrue(distribution.getDistributorNftId(customer) == distributorNftId, "unexpected distributor nft id for customer");
        assertTrue(!distribution.isDistributor(customer2), "customer2 not yet distributor");

        vm.startPrank(customer);
        // chainNft.approve(customer2, distributorNftId.toInt());
        chainNft.safeTransferFrom(customer, customer2, distributorNftId.toInt());
        vm.stopPrank();

        assertEq(registry.ownerOf(distributorNftId), customer2, "customer2 not owner of distributor nft after token transfer");
        assertTrue(!distribution.isDistributor(customer), "customer is still distributor after token transfer");
        assertTrue(distribution.isDistributor(customer2), "customer2 is not yet distributor after token transfer");
        assertTrue(distribution.getDistributorNftId(customer2) == distributorNftId, "unexpected distributor nft id for customer2");
    }


    function testGifSetupDistributorCreate() public {
        _setupTestData(false);

        distributorNftId = distribution.createDistributor(
            customer,
            distributorType,
            distributorData);

        assertEq(registry.ownerOf(distributorNftId), customer, "unexpected distributor nft owner");

        IDistribution.DistributorInfo memory info = instanceReader.getDistributorInfo(distributorNftId);
        assertTrue(info.active, "distributor info not active");
        assertTrue(info.distributorType == distributorType, "unexpected distributor type");
        assertTrue(
            equalBytes(info.data, distributorData), 
            "unexpected distributor data");
    }

    function _prepareDistribution() internal {
        vm.startPrank(instanceOwner);
        instanceAccessManager.grantRole(DISTRIBUTION_OWNER_ROLE(), distributionOwner);
        vm.stopPrank();

        vm.startPrank(distributionOwner);
        distribution = new SimpleDistribution(
            address(registry),
            instanceNftId,
            address(token),
            FeeLib.toFee(UFixedLib.toUFixed(1,-1), 0),
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
        discountPercentage = instanceReader.toUFixed(55, -3);
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
