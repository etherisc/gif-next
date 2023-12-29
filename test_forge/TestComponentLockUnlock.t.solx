// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {Blocknumber} from "../contracts/types/Blocknumber.sol";
import {NftId} from "../contracts/types/NftId.sol";
import {INftOwnable} from "../contracts/shared/INftOwnable.sol";
import {COMPONENT} from "../contracts/types/ObjectType.sol";
import {StateId, ACTIVE, PAUSED} from "../contracts/types/StateId.sol";

import {TestGifBase} from "./base/TestGifBase.sol";
import {IComponent} from "../contracts/instance/module/component/IComponent.sol";
import {IComponentOwnerService} from "../contracts/instance/service/IComponentOwnerService.sol";

contract TestComponentLockUnlock is TestGifBase {

    function testComponentLockNotOwner() public {
        vm.prank(outsider);
        vm.expectRevert(
            abi.encodeWithSelector(
                INftOwnable.ErrorNotOwner.selector,
                outsider));
        product.lock();
    }

    function testComponentLockOwner() public {
        NftId nftId = product.getNftId();

        assertEq(
            instance.getState(nftId.toKey32(COMPONENT())).toInt(),
            ACTIVE().toInt(),
            "component state not active"
        );

        vm.prank(productOwner);
        product.lock();

        assertEq(
            instance.getState(nftId.toKey32(COMPONENT())).toInt(),
            PAUSED().toInt(),
            "component state not paused"
        );
    }

    function testComponentUnlockNotOwner() public {
        NftId nftId = product.getNftId();

        assertEq(
            instance.getState(nftId.toKey32(COMPONENT())).toInt(),
            ACTIVE().toInt(),
            "component state not active"
        );

        vm.prank(outsider);
        vm.expectRevert(
            abi.encodeWithSelector(
                INftOwnable.ErrorNotOwner.selector,
                outsider));
        product.unlock();
    }


    function testComponentUnlockOwner() public {
        NftId nftId = product.getNftId();

        assertEq(
            instance.getState(nftId.toKey32(COMPONENT())).toInt(),
            ACTIVE().toInt(),
            "component state not active"
        );

        vm.startPrank(productOwner);
        product.lock();

        assertEq(
            instance.getState(nftId.toKey32(COMPONENT())).toInt(),
            PAUSED().toInt(),
            "component state not paused"
        );

        product.unlock();
        vm.stopPrank();

        assertEq(
            instance.getState(nftId.toKey32(COMPONENT())).toInt(),
            ACTIVE().toInt(),
            "component state not active"
        );
    }
}
