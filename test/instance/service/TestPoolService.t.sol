// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {BasicPoolAuthorization} from "../../../contracts/pool/BasicPoolAuthorization.sol";
import {GifTest} from "../../base/GifTest.sol";
import {NftId, NftIdLib} from "../../../contracts/type/NftId.sol";
import {POOL_OWNER_ROLE} from "../../../contracts/type/RoleId.sol";
import {FeeLib} from "../../../contracts/type/Fee.sol";
import {UFixedLib} from "../../../contracts/type/UFixed.sol";
import {ComponentService} from "../../../contracts/shared/ComponentService.sol";
import {SimplePool} from "../../../contracts/examples/unpermissioned/SimplePool.sol";

contract TestPoolService is GifTest {
    using NftIdLib for NftId;

    function test_PoolServiceRegisterWithMissingOwnerRole() public {
        vm.startPrank(poolOwner);
        pool = new SimplePool(
            address(registry),
            instanceNftId,
            address(token),
            new BasicPoolAuthorization("SimplePool"),
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

    function test_PoolServiceRegisterWithOwnerRole() public {
        vm.startPrank(instanceOwner);
        instance.grantRole(POOL_OWNER_ROLE(), outsider);
        vm.stopPrank();

        vm.startPrank(outsider);
        pool = new SimplePool(
            address(registry),
            instanceNftId,
            address(token),
            new BasicPoolAuthorization("SimplePool"),
            outsider
        );
        
        pool.register();
        NftId nftId = pool.getNftId();
        assertTrue(nftId.gtz(), "nftId is zero");
    }
}
