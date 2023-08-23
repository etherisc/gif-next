// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import "../lib/forge-std/src/Test.sol";
import {console} from "../lib/forge-std/src/Script.sol";

import {DeployAll} from "../scripts/DeployAll.s.sol";

import {Registry} from "../contracts/registry/Registry.sol";
import {Instance} from "../contracts/instance/Instance.sol";
import {IComponent, IComponentOwnerService} from "../contracts/instance/component/IComponent.sol";
import {TestProduct} from "./mock/TestProduct.sol";
import {TestPool} from "./mock/TestPool.sol";

contract TestComponentLockUnlock is Test {

    Registry registry;
    Instance instance;
    TestProduct product;
    TestPool pool;

    address instanceOwner = makeAddr("instanceOwner");
    address productOwner = makeAddr("productOwner");
    address poolOwner = makeAddr("poolOwner");
    address outsider = makeAddr("outsider");
    
    IComponentOwnerService componentOwnerService;

    function setUp() external {
        DeployAll deployer = new DeployAll();
        (
            registry, 
            instance, 
            product,
            pool
        ) = deployer.run(
            instanceOwner,
            productOwner,
            poolOwner);

        componentOwnerService = instance.getComponentOwnerService();
    }

    function testComponentLockNotOwner() public {
        vm.prank(outsider);
        vm.expectRevert("ERROR:COS-002:NOT_OWNER");
        componentOwnerService.lock(product);
    }

    function testComponentLockOwner() public {
        IComponent.ComponentInfo memory info_before = instance.getComponentInfo(product.getNftId());

        vm.prank(productOwner);
        componentOwnerService.lock(product);

        IComponent.ComponentInfo memory info_after = instance.getComponentInfo(product.getNftId());
        assertEq(info_before.nftId, info_after.nftId, "product id not same");
        assertEq(uint256(uint256(info_after.state)), uint256(IComponent.CState.Locked), "component state not locked");
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

        assertEq(info_before.nftId, info_after.nftId, "product id not same");
        assertEq(uint256(uint256(info_before.state)), uint256(IComponent.CState.Locked), "component state not locked");
        assertEq(uint256(uint256(info_after.state)), uint256(IComponent.CState.Active), "component state not active");
    }
}
