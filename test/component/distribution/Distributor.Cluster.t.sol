// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {GifClusterTest} from "../../base/GifClusterTest.sol";

import {DistributorType} from "../../../contracts/type/DistributorType.sol";
import {IDistributionService} from "../../../contracts/distribution/IDistributionService.sol";
import {NftId} from "../../../contracts/type/NftId.sol";
import {ReferralId} from "../../../contracts/type/Referral.sol";
import {Seconds, SecondsLib} from "../../../contracts/type/Seconds.sol";
import {SimpleDistribution} from "../../../contracts/examples/unpermissioned/SimpleDistribution.sol";
import {Timestamp, TimestampLib} from "../../../contracts/type/Timestamp.sol";
import {UFixed, UFixedLib} from "../../../contracts/type/UFixed.sol";


contract DistributorClusterTest is GifClusterTest {

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

        _setupProductClusters1and2();
    }

    function test_createDistributorType_typeFromOtherProductCluster() public {
        // GIVEN
        DistributorType type2 = _createDistributorType(myDistribution2, instanceOwner);

        // THEN
        vm.expectRevert(abi.encodeWithSelector(
            IDistributionService.ErrorDistributionServiceDistributorTypeDistributionMismatch.selector, 
            type2,
            myDistributionNftId2,
            myDistributionNftId1));

        // WHEN
        myDistribution1.createDistributor(makeAddr("distributor"), type2, "");
    }

    function test_changeDistributorType_typeFromOtherProductCluster() public {
        // GIVEN
        address theDistributor = makeAddr("theDistributor");

        DistributorType type1 = _createDistributorType(myDistribution1, instanceOwner);
        DistributorType type2 = _createDistributorType(myDistribution2, instanceOwner);
        
        vm.startPrank(instanceOwner);
        distributorNftId = myDistribution1.createDistributor(distributor, type1, "");
        
        // THEN
        vm.expectRevert(abi.encodeWithSelector(
            IDistributionService.ErrorDistributionServiceDistributorTypeDistributionMismatch.selector, 
            type2,
            myDistributionNftId2,
            myDistributionNftId1));

        // WHEN
        myDistribution1.changeDistributorType(distributorNftId, type2, "");
    }

    function test_createReferral_distributorFromOtherProductCluster() public {
        // GIVEN
        address theDistributor = makeAddr("theDistributor");

        DistributorType type2 = _createDistributorType(myDistribution2, instanceOwner);
        
        vm.startPrank(instanceOwner);
        distributorNftId = myDistribution2.createDistributor(distributor, type2, "");

        Timestamp referralLifetime = TimestampLib.blockTimestamp().addSeconds(SecondsLib.toSeconds(3600));
        UFixed discount = UFixedLib.toUFixed(1, -1);
        
        // THEN
        vm.expectRevert(abi.encodeWithSelector(
            IDistributionService.ErrorDistributionServiceDistributorDistributionMismatch.selector, 
            distributorNftId,
            myDistributionNftId2,
            myDistributionNftId1));

        // WHEN
        myDistribution1.createReferral2(
            distributorNftId, 
            "BESTPRODUCT", 
            discount, 
            1, 
            referralLifetime, 
            "");
    }


    function _createDistributorType(SimpleDistribution dist, address distOwner) internal returns (DistributorType) {
        name = "Basic";
        minDiscountPercentage = instanceReader.toUFixed(5, -2);
        maxDiscountPercentage = instanceReader.toUFixed(75, -3);
        commissionPercentage = instanceReader.toUFixed(3, -2);
        maxReferralCount = 20;
        maxReferralLifetime = SecondsLib.toSeconds(14 * 24 * 3600);
        allowSelfReferrals = true;
        allowRenewals = true;
        data = ".";

        vm.startPrank(distOwner);
        return dist.createDistributorType(
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

}
