// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {ILifecycle} from "../contracts/instance/lifecycle/ILifecycle.sol";
import {NftId} from "../contracts/types/NftId.sol";
import {PRODUCT} from "../contracts/types/ObjectType.sol";
import {ACTIVE, PAUSED} from "../contracts/types/StateId.sol";
import {TestGifBase} from "./TestGifBase.sol";
import {IComponent, IComponentOwnerService} from "../contracts/instance/component/IComponent.sol";

contract TestComponentLockUnlock is
    ILifecycle,
    TestGifBase
{
    
    IComponentOwnerService componentOwnerService;

    function setUp() public override {
        super.setUp();
        componentOwnerService = instance.getComponentOwnerService();
    }

    function testComponentLockNotOwner() public {
        vm.prank(outsider);
        vm.expectRevert("ERROR:COS-002:NOT_OWNER");
        componentOwnerService.lock(product);
    }

    function testComponentLockOwner() public {
        NftId nftId = product.getNftId();
        IComponent.ComponentInfo memory info_before = instance.getComponentInfo(nftId);

        vm.expectEmit();
        emit LogComponentStateChanged(nftId, PRODUCT(), ACTIVE(), PAUSED());

        vm.prank(productOwner);
        componentOwnerService.lock(product);

        IComponent.ComponentInfo memory info_after = instance.getComponentInfo(product.getNftId());
        assertNftId(info_before.nftId, info_after.nftId, "product id not same");
        assertEq(info_after.state.toInt(), PAUSED().toInt(), "component state not paused");
    }

    function testComponentUnlockNotOwner() public {
        vm.prank(outsider);
        vm.expectRevert("ERROR:COS-002:NOT_OWNER");
        componentOwnerService.unlock(product);
    }

    function testComponentUnlockOwner() public {

        vm.startPrank(productOwner);
        componentOwnerService.lock(product);
        IComponent.ComponentInfo memory info_before = instance.getComponentInfo(product.getNftId());

        componentOwnerService.unlock(product);
        IComponent.ComponentInfo memory info_after = instance.getComponentInfo(product.getNftId());
        vm.stopPrank();

        assertNftId(info_before.nftId, info_after.nftId, "product id not same");
        assertEq(info_before.state.toInt(), PAUSED().toInt(), "component state not paused");
        assertEq(info_after.state.toInt(), ACTIVE().toInt(), "component state not active");
    }
}
