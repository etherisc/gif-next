// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {console} from "../../../lib/forge-std/src/Script.sol";
import {TestGifBase} from "../../base/TestGifBase.sol";
import {NftId, toNftId, NftIdLib} from "../../../contracts/types/NftId.sol";
import {PRODUCT_OWNER_ROLE, POOL_OWNER_ROLE, DISTRIBUTION_OWNER_ROLE} from "../../../contracts/types/RoleId.sol";
import {Distribution} from "../../../contracts/components/Distribution.sol";
import {IRegistry} from "../../../contracts/registry/IRegistry.sol";
import {ISetup} from "../../../contracts/instance/module/ISetup.sol";
import {Fee, FeeLib} from "../../../contracts/types/Fee.sol";
import {UFixedLib} from "../../../contracts/types/UFixed.sol";

contract TestDistributionService is TestGifBase {
    using NftIdLib for NftId;

    function test_register_missingDistributionOwnerRole() public {
        vm.startPrank(distributionOwner);
        distribution = new Distribution(
            address(registry),
            instanceNftId,
            address(token),
            false,
            FeeLib.zeroFee(),
            distributionOwner
        );

        vm.expectRevert("ERROR:DIS-001:NOT_DISTRIBUTION_OWNER_ROLE");
        NftId distributionNftId = distributionService.register(address(distribution));
    }

}
