// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {TestGifBase} from "../../base/TestGifBase.sol";
import {NftId, NftIdLib} from "../../../contracts/types/NftId.sol";
import {POOL_OWNER_ROLE} from "../../../contracts/types/RoleId.sol";
import {FeeLib} from "../../../contracts/types/Fee.sol";
import {UFixedLib} from "../../../contracts/types/UFixed.sol";
import {ComponentService} from "../../../contracts/instance/base/ComponentService.sol";
import {SimplePool} from "../../mock/SimplePool.sol";

contract TestPoolService is TestGifBase {
    using NftIdLib for NftId;

    function test_PoolService_register_missingPoolOwnerRole() public {
        vm.startPrank(poolOwner);
        SimplePool spool = new SimplePool();
        spool.initialize(
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
        pool = spool;

        vm.expectRevert(
            abi.encodeWithSelector(
                ComponentService.ErrorComponentServiceExpectedRoleMissing.selector, 
                instanceNftId,
                POOL_OWNER_ROLE(), 
                poolOwner));

        poolService.register(address(pool));
    }

    function test_PoolService_register() public {
        vm.startPrank(instanceOwner);
        instanceAccessManager.grantRole(POOL_OWNER_ROLE(), poolOwner);
        vm.stopPrank();

        vm.startPrank(poolOwner);
        SimplePool spool = new SimplePool();
        spool.initialize(
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
        pool = spool;

        NftId nftId = poolService.register(address(pool));
        assertTrue(nftId.gtz(), "nftId is zero");
    }
}
