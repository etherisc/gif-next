// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {console} from "../../../lib/forge-std/src/Script.sol";
import {TestGifBase} from "../../base/TestGifBase.sol";
import {NftId, toNftId, NftIdLib} from "../../../contracts/types/NftId.sol";
import {PRODUCT_OWNER_ROLE, POOL_OWNER_ROLE, DISTRIBUTION_OWNER_ROLE} from "../../../contracts/types/RoleId.sol";
import {Pool} from "../../../contracts/components/Pool.sol";
import {IRegistry} from "../../../contracts/registry/IRegistry.sol";
import {ISetup} from "../../../contracts/instance/module/ISetup.sol";
import {Fee, FeeLib} from "../../../contracts/types/Fee.sol";
import {UFixedLib} from "../../../contracts/types/UFixed.sol";
import {ComponentServiceBase} from "../../../contracts/instance/base/ComponentServiceBase.sol";

contract TestPoolService is TestGifBase {
    using NftIdLib for NftId;

    function test_PoolService_register_missingPoolOwnerRole() public {
        vm.startPrank(poolOwner);
        pool = new Pool(
            address(registry),
            instanceNftId,
            address(token),
            false,
            false,
            UFixedLib.toUFixed(1),
            FeeLib.zeroFee(),
            FeeLib.zeroFee(),
            FeeLib.zeroFee(),
            poolOwner
        );

        vm.expectRevert(abi.encodeWithSelector(ComponentServiceBase.ExpectedRoleMissing.selector, POOL_OWNER_ROLE(), poolOwner));
        poolService.register(address(pool));
    }

    function test_PoolService_register() public {
        vm.startPrank(instanceOwner);
        instanceAccessManager.grantRole(POOL_OWNER_ROLE(), poolOwner);
        vm.stopPrank();

        vm.startPrank(poolOwner);
        pool = new Pool(
            address(registry),
            instanceNftId,
            address(token),
            false,
            false,
            UFixedLib.toUFixed(1),
            FeeLib.zeroFee(),
            FeeLib.zeroFee(),
            FeeLib.zeroFee(),
            poolOwner
        );

        NftId nftId = poolService.register(address(pool));
        assertFalse(nftId.eqz(), "nftId is zero");
    }

}
