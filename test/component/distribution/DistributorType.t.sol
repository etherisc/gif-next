// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Test, Vm, console} from "../../../lib/forge-std/src/Test.sol";
import {TestGifBase} from "../../base/TestGifBase.sol";

import {NftId} from "../../../contracts/type/NftId.sol";
import {Key32} from "../../../contracts/type/Key32.sol";
import {DistributorType, DistributorTypeLib} from "../../../contracts/type/DistributorType.sol";
import {IDistribution} from "../../../contracts/instance/module/IDistribution.sol";
import {UFixed} from "../../../contracts/type/UFixed.sol";
import {SimpleDistribution} from "../../mock/SimpleDistribution.sol";
import {FeeLib} from "../../../contracts/type/Fee.sol";
import {DISTRIBUTION_OWNER_ROLE} from "../../../contracts/type/RoleId.sol";

contract DistributorTypeTest is TestGifBase {

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
    bytes public distributorData;


    function _prepareDistribution() internal {
        vm.startPrank(instanceOwner);
        instanceOzAccessManager.grantRole(DISTRIBUTION_OWNER_ROLE().toInt(), distributionOwner, 0);
        vm.stopPrank();

        vm.startPrank(distributionOwner);
        distribution = new SimpleDistribution(
            address(registry),
            instanceNftId,
            address(token),
            FeeLib.zeroFee(),
            FeeLib.zeroFee(),
            distributionOwner
        );
        distributionNftId = distributionService.register(address(distribution));
    }

    function testGifSetupDistributorTypeCreate() public {
        _prepareDistribution();

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

        // solhint-disable-next-line 
        console.log("distributor type", vm.toString(DistributorType.unwrap(distributorType)));        

        IDistribution.DistributorTypeInfo memory info = instanceReader.getDistributorTypeInfo(distributorType);
        // solhint-disable-next-line 
        console.log("distributor type name", info.name);
        assertTrue(equalStrings(info.name, name), "unexpected distributor type name");

        assertTrue(info.minDiscountPercentage == minDiscountPercentage, "unexpected min discount percentage");
        assertTrue(info.maxDiscountPercentage == maxDiscountPercentage, "unexpected max discount percentage");
        // solhint-disable-next-line 
        console.log("distributor type minDiscountPercentage", UFixed.unwrap(info.minDiscountPercentage));        
        // solhint-disable-next-line 
        console.log("distributor type maxDiscountPercentage", UFixed.unwrap(info.maxDiscountPercentage));        

        assertTrue(info.commissionPercentage == commissionPercentage, "unexpected commission percentage");
        // solhint-disable-next-line 
        console.log("commission percentage", UFixed.unwrap(info.commissionPercentage));        

        assertEq(info.maxReferralCount, maxReferralCount, "unexpected referral count");
        assertEq(info.maxReferralLifetime, maxReferralLifetime, "unexpected referral count");
        assertEq(info.allowSelfReferrals, allowSelfReferrals, "unexpected allow self referrals");
        assertEq(info.allowRenewals, allowRenewals, "unexpected allow renewals");
        assertTrue(equalBytes(info.data, data), "unexpected data for referral type");
    }


    function _setupTestData(bool createDistributorType) internal {
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

        if (createDistributorType) {    
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
        }
    }
}
