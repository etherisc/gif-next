// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {TestGifBase} from "../../base/TestGifBase.sol";
import {NftId, NftIdLib} from "../../../contracts/types/NftId.sol";
import {DISTRIBUTION_OWNER_ROLE} from "../../../contracts/types/RoleId.sol";
import {ComponentServiceBase} from "../../../contracts/instance/base/ComponentServiceBase.sol";
import {FeeLib} from "../../../contracts/types/Fee.sol";
import {SimpleDistribution} from "../../mock/SimpleDistribution.sol";

contract TestDistributionService is TestGifBase {
    using NftIdLib for NftId;

    function test_DistributionService_register_missingDistributionOwnerRole() public {
        vm.startPrank(distributionOwner);
        distribution = new SimpleDistribution(
            address(registry),
            instanceNftId,
            address(token),
            false,
            FeeLib.zeroFee(),
            distributionOwner
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                ComponentServiceBase.ErrorComponentServiceExpectedRoleMissing.selector, 
                instanceNftId,
                DISTRIBUTION_OWNER_ROLE(), 
                distributionOwner));

        distributionService.register(address(distribution));
    }

    function test_DistributionService_register() public {
        vm.startPrank(instanceOwner);
        instanceAccessManager.grantRole(DISTRIBUTION_OWNER_ROLE(), distributionOwner);
        vm.stopPrank();

        vm.startPrank(distributionOwner);
        distribution = new SimpleDistribution(
            address(registry),
            instanceNftId,
            address(token),
            false,
            FeeLib.zeroFee(),
            distributionOwner
        );

        NftId nftId = distributionService.register(address(distribution));
        assertTrue(nftId.gtz(), "nftId is zero");
    }

}
