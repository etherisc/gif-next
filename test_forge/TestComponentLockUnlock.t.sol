// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {Blocknumber} from "../contracts/types/Blocknumber.sol";
import {Key32, KeyId} from "../contracts/types/Key32.sol";
import {NftId} from "../contracts/types/NftId.sol";
import {COMPONENT} from "../contracts/types/ObjectType.sol";
import {StateId, ACTIVE, PAUSED} from "../contracts/types/StateId.sol";

import {IKeyValueStore} from "../contracts/instance/base/IKeyValueStore.sol";
import {TestGifBase} from "./base/TestGifBase.sol";
import {IComponent} from "../contracts/instance/module/component/IComponent.sol";
import {IComponentOwnerService} from "../contracts/instance/service/IComponentOwnerService.sol";

contract TestComponentLockUnlock is TestGifBase {

    function testComponentLockNotOwner() public {
        vm.prank(outsider);
        vm.expectRevert("ERROR:RGB-001:NOT_OWNER");
        product.lock();
    }

    function testComponentLockOwner() public {
        NftId nftId = product.getNftId();
        Key32 key = nftId.toKey32(COMPONENT());

        assertEq(
            keyValueStore.getState(key).toInt(),
            ACTIVE().toInt(),
            "component state not active"
        );

        vm.prank(productOwner);
        product.lock();

        assertEq(
            keyValueStore.getState(key).toInt(),
            PAUSED().toInt(),
            "component state not paused"
        );
    }

    function testComponentUnlockNotOwner() public {
        NftId nftId = product.getNftId();
        Key32 key = nftId.toKey32(COMPONENT());

        assertEq(
            keyValueStore.getState(key).toInt(),
            ACTIVE().toInt(),
            "component state not active"
        );

        vm.prank(outsider);
        vm.expectRevert("ERROR:RGB-001:NOT_OWNER");
        product.unlock();
    }


    function testComponentUnlockOwner() public {
        NftId nftId = product.getNftId();
        Key32 key = nftId.toKey32(COMPONENT());

        assertEq(
            keyValueStore.getState(key).toInt(),
            ACTIVE().toInt(),
            "component state not active"
        );

        vm.startPrank(productOwner);
        product.lock();

        assertEq(
            keyValueStore.getState(key).toInt(),
            PAUSED().toInt(),
            "component state not paused"
        );

        product.unlock();
        vm.stopPrank();

        assertEq(
            keyValueStore.getState(key).toInt(),
            ACTIVE().toInt(),
            "component state not active"
        );
    }
}
