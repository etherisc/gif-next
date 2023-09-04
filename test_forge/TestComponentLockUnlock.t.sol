// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {TestGifBase} from "./TestGifBase.sol";
import {IComponent, IComponentOwnerService} from "../contracts/instance/component/IComponent.sol";

contract TestComponentLockUnlock is TestGifBase {
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
        IComponent.ComponentInfo memory info_before = instance.getComponentInfo(
            product.getNftId()
        );

        vm.prank(productOwner);
        componentOwnerService.lock(product);

        IComponent.ComponentInfo memory info_after = instance.getComponentInfo(
            product.getNftId()
        );
        assertNftId(info_before.nftId, info_after.nftId, "product id not same");
        assertEq(
            uint256(uint256(info_after.state)),
            uint256(IComponent.CState.Locked),
            "component state not locked"
        );
    }

    function testComponentUnlockNotOwner() public {
        vm.prank(outsider);
        vm.expectRevert("ERROR:COS-002:NOT_OWNER");
        componentOwnerService.unlock(product);
    }

    function testComponentUnlockOwner() public {
        vm.startPrank(productOwner);
        componentOwnerService.lock(product);
        IComponent.ComponentInfo memory info_before = instance.getComponentInfo(
            product.getNftId()
        );

        componentOwnerService.unlock(product);
        IComponent.ComponentInfo memory info_after = instance.getComponentInfo(
            product.getNftId()
        );
        vm.stopPrank();

        assertNftId(info_before.nftId, info_after.nftId, "product id not same");
        assertEq(
            uint256(uint256(info_before.state)),
            uint256(IComponent.CState.Locked),
            "component state not locked"
        );
        assertEq(
            uint256(uint256(info_after.state)),
            uint256(IComponent.CState.Active),
            "component state not active"
        );
    }
}
