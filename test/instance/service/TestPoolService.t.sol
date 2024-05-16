// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {GifTest} from "../../base/GifTest.sol";
import {NftId, NftIdLib} from "../../../contracts/type/NftId.sol";
import {POOL_OWNER_ROLE} from "../../../contracts/type/RoleId.sol";
import {FeeLib} from "../../../contracts/type/Fee.sol";
import {UFixedLib} from "../../../contracts/type/UFixed.sol";
import {ComponentService} from "../../../contracts/shared/ComponentService.sol";
import {SimplePool} from "../../mock/SimplePool.sol";

contract TestPoolService is GifTest {
    using NftIdLib for NftId;

    function test_PoolService_register_missingPoolOwnerRole() public {
        vm.startPrank(poolOwner);
        pool = new SimplePool(
            address(registry),
            instanceNftId,
            address(token),
            false,
            false,
            UFixedLib.toUFixed(1),
            UFixedLib.toUFixed(1),
            poolOwner
        );
        
        vm.expectRevert(
            abi.encodeWithSelector(
                ComponentService.ErrorComponentServiceExpectedRoleMissing.selector, 
                instanceNftId,
                POOL_OWNER_ROLE(), 
                poolOwner));

        pool.register();
    }

    function test_PoolService_register() public {
        vm.startPrank(instanceOwner);
        instanceAccessManager.grantRole(POOL_OWNER_ROLE().toInt(), poolOwner, 0);
        vm.stopPrank();

        vm.startPrank(poolOwner);
        pool = new SimplePool(
            address(registry),
            instanceNftId,
            address(token),
            false,
            false,
            UFixedLib.toUFixed(1),
            UFixedLib.toUFixed(1),
            poolOwner
        );
        
        pool.register();
        NftId nftId = pool.getNftId();
        assertTrue(nftId.gtz(), "nftId is zero");
    }
}
