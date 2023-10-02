// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {Blocknumber} from "../contracts/types/Blocknumber.sol";
import {Key32, KeyId} from "../contracts/types/Key32.sol";
import {NftId} from "../contracts/types/NftId.sol";
import {PRODUCT} from "../contracts/types/ObjectType.sol";
import {ACTIVE, PAUSED} from "../contracts/types/StateId.sol";

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
        IComponent.ComponentInfo memory infoBefore = instance.getComponentInfo(
            nftId
        );

        // vm.expectEmit();
        // Key32 key = nftId.toKey32(PRODUCT());
        // KeyId keyId = nftId.toKeyId();
        // IKeyValueStore.Metadata memory metadata = keyValueStore.getMetadata(key);
        // TODO fix this
        // emit IKeyValueStore.LogStateUpdated(
        //     IKeyValueStore.Key(PRODUCT(), keyId), 
        //     ACTIVE(), 
        //     PAUSED(), 
        //     productOwner, // updatedBy
        //     metadata.updatedIn); // lastUpdatedIn

        vm.prank(productOwner);
        product.lock();

        IComponent.ComponentInfo memory infoAfter = instance.getComponentInfo(
            product.getNftId()
        );
        assertNftId(infoBefore.nftId, infoAfter.nftId, "product id not same");
        assertEq(
            infoAfter.state.toInt(),
            PAUSED().toInt(),
            "component state not paused"
        );
    }

    function testComponentUnlockNotOwner() public {
        vm.prank(outsider);
        vm.expectRevert("ERROR:RGB-001:NOT_OWNER");
        product.unlock();
    }

    function testComponentUnlockOwner() public {
        vm.startPrank(productOwner);
        product.lock();
        IComponent.ComponentInfo memory infoBefore = instance.getComponentInfo(
            product.getNftId()
        );

        product.unlock();
        IComponent.ComponentInfo memory infoAfter = instance.getComponentInfo(
            product.getNftId()
        );
        vm.stopPrank();

        assertNftId(infoBefore.nftId, infoAfter.nftId, "product id not same");
        assertEq(
            infoBefore.state.toInt(),
            PAUSED().toInt(),
            "component state not paused"
        );
        assertEq(
            infoAfter.state.toInt(),
            ACTIVE().toInt(),
            "component state not active"
        );
    }
}
