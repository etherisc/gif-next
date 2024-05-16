// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {GifTest} from "../../base/GifTest.sol";
import {NftId, NftIdLib} from "../../../contracts/type/NftId.sol";
import {DISTRIBUTION_OWNER_ROLE} from "../../../contracts/type/RoleId.sol";
import {ComponentService} from "../../../contracts/shared/ComponentService.sol";
import {FeeLib} from "../../../contracts/type/Fee.sol";
import {SimpleDistribution} from "../../mock/SimpleDistribution.sol";

contract TestDistributionService is GifTest {
    using NftIdLib for NftId;

    function test_DistributionService_register_missingDistributionOwnerRole() public {
        vm.startPrank(distributionOwner);
        distribution = new SimpleDistribution(
            address(registry),
            instanceNftId,
            distributionOwner,
            address(token));
        
        vm.expectRevert(
            abi.encodeWithSelector(
                ComponentService.ErrorComponentServiceExpectedRoleMissing.selector, 
                instanceNftId,
                DISTRIBUTION_OWNER_ROLE(), 
                distributionOwner));

        distribution.register();
    }

    function test_DistributionService_register() public {
        vm.startPrank(instanceOwner);
        instanceAccessManager.grantRole(DISTRIBUTION_OWNER_ROLE().toInt(), distributionOwner, 0);
        vm.stopPrank();

        vm.startPrank(distributionOwner);
        distribution = new SimpleDistribution(
            address(registry),
            instanceNftId,
            distributionOwner,
            address(token)
        );
        
        distribution.register();
        NftId nftId = distribution.getNftId();
        assertTrue(nftId.gtz(), "nftId is zero");
    }

}
