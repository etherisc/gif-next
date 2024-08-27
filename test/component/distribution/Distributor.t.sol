// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../../../lib/forge-std/src/Test.sol";
import {GifTest} from "../../base/GifTest.sol";

import {DistributorType} from "../../../contracts/type/DistributorType.sol";
import {FeeLib} from "../../../contracts/type/Fee.sol";
import {IDistribution} from "../../../contracts/instance/module/IDistribution.sol";
import {IDistributionComponent} from "../../../contracts/distribution/IDistributionComponent.sol";
import {NftId} from "../../../contracts/type/NftId.sol";
import {ReferralId, ReferralStatus, ReferralLib, REFERRAL_OK, REFERRAL_ERROR_UNKNOWN} from "../../../contracts/type/Referral.sol";
import {Seconds, SecondsLib} from "../../../contracts/type/Seconds.sol";
import {SimpleDistribution} from "../../../contracts/examples/unpermissioned/SimpleDistribution.sol";
import {Timestamp, TimestampLib} from "../../../contracts/type/Timestamp.sol";
import {UFixed, UFixedLib} from "../../../contracts/type/UFixed.sol";

contract DistributorTest is GifTest {

    DistributorType public distributorType;
    DistributorType public distributorType2;
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

    function setUp() public virtual override {
        super.setUp();

        _prepareProduct();

        vm.startPrank(distributionOwner);
        distribution.setFees(
            FeeLib.toFee(UFixedLib.toUFixed(2,-1), 0), 
            FeeLib.toFee(UFixedLib.toUFixed(5,-2), 0));
        vm.stopPrank();
    }

    function test_distributionReferralUnknown() public {

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

    function test_distributionReferralCreate() public {
        _setupTestData(true);

        // solhint-disable-next-line 
        console.log("distributor nft id", distributorNftId.toInt());

        SimpleDistribution sdistribution = SimpleDistribution(address(distribution));

        vm.startPrank(customer);
        referralId = sdistribution.createReferral(
            referralCode,
            discountPercentage,
            maxReferrals,
            expiryAt,
            referralData);
        vm.stopPrank();

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

    function test_distributionDistributorCreateTransfer() public {

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


    function test_distributionDistributorCreateSingle() public {
        _setupTestData(false);

        vm.startPrank(distributionOwner);
        distributorNftId = distribution.createDistributor(
            customer,
            distributorType,
            distributorData);
        vm.stopPrank();

        assertEq(registry.ownerOf(distributorNftId), customer, "unexpected distributor nft owner");

        IDistribution.DistributorInfo memory info = instanceReader.getDistributorInfo(distributorNftId);
        assertTrue(info.active, "distributor info not active");
        assertTrue(info.distributorType == distributorType, "unexpected distributor type");
        assertTrue(
            equalBytes(info.data, distributorData), 
            "unexpected distributor data");
    }

    function test_DistributorTypeCreateHappyCase() public {

        _createDistributorType();

        IDistribution.DistributorTypeInfo memory distributorTypeInfo = instanceReader.getDistributorTypeInfo(distributorType);
        assertEq(keccak256(bytes(distributorTypeInfo.name)), keccak256(bytes(name)), "unexpected name");
        assertEq(distributorTypeInfo.minDiscountPercentage.toInt(), minDiscountPercentage.toInt(), "unexpected min discount percentage");
        assertEq(distributorTypeInfo.maxDiscountPercentage.toInt(), maxDiscountPercentage.toInt(), "unexpected max discount percentage");
        assertEq(distributorTypeInfo.commissionPercentage.toInt(), commissionPercentage.toInt(), "unexpected commission percentage");
        assertEq(distributorTypeInfo.maxReferralCount, maxReferralCount, "unexpected max referral count");
        assertEq(distributorTypeInfo.maxReferralLifetime.toInt(), maxReferralLifetime.toInt(), "unexpected max referral lifetime");
        assertEq(distributorTypeInfo.allowSelfReferrals, allowSelfReferrals, "unexpected allow self referrals");
        assertEq(distributorTypeInfo.allowRenewals, allowRenewals, "unexpected allow renewals");
        assertEq(keccak256(distributorTypeInfo.data), keccak256(data), "unexpected data");
    }

    function test_DistributorCreateHappyCase() public {
        // GIVEN
        _createDistributorType();
        _createDistributorType2();
        distributorNftId = _createDistributor(customer, distributorType);

        assertTrue(distributorNftId.gtz(), "distributor nft zero");

        IDistribution.DistributorInfo memory distributorInfo = instanceReader.getDistributorInfo(distributorNftId);
        assertEq(DistributorType.unwrap(distributorInfo.distributorType), DistributorType.unwrap(distributorType), "unexpected distributor type");
        assertEq(keccak256(distributorInfo.data), keccak256(distributorData), "unexpected distributor data");

        vm.startPrank(distributionOwner);

        // WHEN
        distribution.changeDistributorType(
            distributorNftId,
            distributorType2,
            "");
        
        // THEN
        IDistribution.DistributorInfo memory distributorInfoAfter = instanceReader.getDistributorInfo(distributorNftId);
        assertEq(DistributorType.unwrap(distributorInfoAfter.distributorType), DistributorType.unwrap(distributorType2), "unexpected distributor type after");
    }

    /// @dev test creation of two different distributor nfts (different types) with the same address
    function test_DistributorCreate_oneAddressTwoTypes() public {
        // GIVEN
        _createDistributorType();
        _createDistributorType2();
        
        // WHEN
        distributorNftId = _createDistributor(customer, distributorType);
        NftId distributorNftId2 = _createDistributor(customer, distributorType2);
        
        // THEN
        assertTrue(distributorNftId.gtz(), "distributor nft zero");
        assertTrue(distributorNftId2.gtz(), "distributor nft 2 zero");
        assertTrue(distributorNftId != distributorNftId2, "distributor nft ids are the same");

        IDistribution.DistributorInfo memory distributorInfo = instanceReader.getDistributorInfo(distributorNftId);
        IDistribution.DistributorInfo memory distributorInfo2 = instanceReader.getDistributorInfo(distributorNftId2);
        assertTrue(distributorInfo.distributorType != distributorInfo2.distributorType, "distributor types are the same");
    }

    function test_changeDistributorType() public {

        _createDistributorType();
        distributorNftId = _createDistributor(customer, distributorType);

        assertTrue(distributorNftId.gtz(), "distributor nft zero");

        IDistribution.DistributorInfo memory distributorInfo = instanceReader.getDistributorInfo(distributorNftId);
        assertEq(DistributorType.unwrap(distributorInfo.distributorType), DistributorType.unwrap(distributorType), "unexpected distributor type");
        assertEq(keccak256(distributorInfo.data), keccak256(distributorData), "unexpected distributor data");
    }

    function test_ReferralCreateHappyCase() public {
        // GIVEN

        _createDistributorType();
        distributorNftId = _createDistributor(customer, distributorType);

        referralCode = "saveNow";
        UFixed referralDiscount = UFixedLib.toUFixed(5, -2);
        maxReferralCount = 7;
        Seconds thirtySeconds = SecondsLib.toSeconds(30);
        Timestamp referralExpiresAt = TimestampLib.blockTimestamp().addSeconds(thirtySeconds);
        referralData = "refDat";

        // WHEN
        vm.startPrank(customer);
        referralId = SimpleDistribution(
            address(distribution)).createReferral(
                referralCode,
                referralDiscount,
                maxReferralCount,
                referralExpiresAt,
                referralData);
        vm.stopPrank();

        // THEN
        assertTrue(
            ReferralId.unwrap(referralId) != ReferralId.unwrap(
                ReferralLib.zero()), 
            "referral id zero");

        IDistribution.ReferralInfo memory referral = instanceReader.getReferralInfo(referralId);
        assertEq(referral.distributorNftId.toInt(), distributorNftId.toInt(), "unexpected distributor nft id");

        assertEq(
            keccak256(bytes(referral.referralCode)), 
            keccak256(bytes(referralCode)), 
            "unexpected code");

        assertEq(referral.discountPercentage.toInt(), referralDiscount.toInt(), "unexpected discount");
        assertEq(referral.maxReferrals, maxReferralCount, "unexpected max referral count");
        assertEq(referral.expiryAt.toInt(), referralExpiresAt.toInt(), "unexpected expiry at");
        assertEq(keccak256(referral.data), keccak256(referralData), "unexpected data");
    }

    function _createDistributorType() internal {
        name = "Basic";
        minDiscountPercentage = instanceReader.toUFixed(5, -2);
        maxDiscountPercentage = instanceReader.toUFixed(75, -3);
        commissionPercentage = instanceReader.toUFixed(3, -2);
        maxReferralCount = 20;
        maxReferralLifetime = SecondsLib.toSeconds(14 * 24 * 3600);
        allowSelfReferrals = true;
        allowRenewals = true;
        data = ".";

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
        vm.stopPrank();
    }

    function _createDistributorType2() internal {
        name = "Silver";
        minDiscountPercentage = instanceReader.toUFixed(5, -2);
        maxDiscountPercentage = instanceReader.toUFixed(75, -3);
        commissionPercentage = instanceReader.toUFixed(5, -2);
        maxReferralCount = 50;
        maxReferralLifetime = SecondsLib.toSeconds(30 * 24 * 3600);
        allowSelfReferrals = true;
        allowRenewals = true;
        data = ".";

        vm.startPrank(distributionOwner);
        distributorType2 = distribution.createDistributorType(
            name,
            minDiscountPercentage,
            maxDiscountPercentage,
            commissionPercentage,
            maxReferralCount,
            maxReferralLifetime,
            allowSelfReferrals,
            allowRenewals,
            data);
        vm.stopPrank();
    }

    function _createDistributor(address distAddr, DistributorType distType) internal returns (NftId) {
        vm.startPrank(distributionOwner);
        distributorData = "..";
        NftId nftId = distribution.createDistributor(
            distAddr,
            distType,
            distributorData);
        vm.stopPrank();
        return nftId;
    }

    function _setupTestData(bool createDistributor) internal {
        _createDistributorType();

        referralCode = "SAVE!!!";
        discountPercentage = instanceReader.toUFixed(55, -3);
        maxReferrals = 10;
        expiryAt = TimestampLib.toTimestamp(block.timestamp + 7 * 24 * 3600);
        referralData = "...";

        if (createDistributor) {
            distributorNftId = _createDistributor(customer, distributorType);
        }
    }
}
