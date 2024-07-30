// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../lib/forge-std/src/Test.sol";

import {BasicDistributionAuthorization} from "../contracts/distribution/BasicDistributionAuthorization.sol";
import {Fee, FeeLib} from "../contracts/type/Fee.sol";
import {GifTest} from "./base/GifTest.sol";
import {IAccess} from "../contracts/instance/module/IAccess.sol";
import {IComponent} from "../contracts/shared/IComponent.sol";
import {IComponents} from "../contracts/instance/module/IComponents.sol";
import {IComponentService} from "../contracts/shared/IComponentService.sol";
import {NftId, NftIdLib} from "../contracts/type/NftId.sol";
import {SimpleDistribution} from "../contracts/examples/unpermissioned/SimpleDistribution.sol";
import {TokenHandler} from "../contracts/shared/TokenHandler.sol";
import {UFixedLib} from "../contracts/type/UFixed.sol";


contract TestComponent is GifTest {

    uint256 public constant INITIAL_BALANCE = 100000;

    function setUp() public override {
        super.setUp();
        _prepareProduct(); // also deploys and registers distribution
    }

    function test_componentGetComponentInfo() public {

        // GIVEN - just setUp
        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(distributionNftId);

        // check wallet
        assertEq(componentInfo.wallet, address(distribution), "unexpected wallet address");

        // check token handler
        assertTrue(address(componentInfo.tokenHandler) != address(0), "token handler zero");
        assertEq(address(componentInfo.tokenHandler.getToken()), address(distribution.getToken()), "unexpected token for token handler");
    }

    function test_componentSetWalletToExtowned() public {
        // GIVEN - just setUp

        address externallyOwnerWallet = makeAddr("externallyOwnerWallet");

        // WHEN
        vm.startPrank(distributionOwner);
        distribution.setWallet(externallyOwnerWallet);
        vm.stopPrank();

        // THEN
        assertEq(distribution.getWallet(), externallyOwnerWallet, "wallet not changed to externallyOwnerWallet");
    }

    function test_componentSetWalletToComponent() public {
        // GIVEN - just setUp

        address externallyOwnerWallet = makeAddr("externallyOwnerWallet");

        vm.startPrank(distributionOwner);
        distribution.setWallet(externallyOwnerWallet);
        vm.stopPrank();

        assertEq(distribution.getWallet(), externallyOwnerWallet, "wallet not externallyOwnerWallet");

        // WHEN
        vm.startPrank(distributionOwner);
        distribution.setWallet(address(distribution));
        vm.stopPrank();

        // THEN
        assertEq(distribution.getWallet(), address(distribution), "wallet not changed to distribution component");
    }

    function test_componentSetWalletSameAddress() public {
        // GIVEN - just setUp

        address externallyOwnerWallet = makeAddr("externallyOwnerWallet");

        // WHEN (1)
        vm.startPrank(distributionOwner);
        distribution.setWallet(externallyOwnerWallet);
        vm.stopPrank();

        // THEN (1)
        assertEq(distribution.getWallet(), externallyOwnerWallet, "wallet not externallyOwnerWallet (1)");
        assertEq(instanceReader.getComponentInfo(distributionNftId).wallet, externallyOwnerWallet, "wallet not externallyOwnerWallet (2)");

        // THEN (2)
        vm.expectRevert(abi.encodeWithSelector(IComponentService.ErrorComponentServiceWalletAddressIsSameAsCurrent.selector));

        // WHEN (2)
        vm.startPrank(distributionOwner);
        distribution.setWallet(externallyOwnerWallet);
        vm.stopPrank();

        vm.stopPrank();
    }

    function test_componentSetWalletToAnotherExtowned() public {
        // GIVEN - just setUp

        address externallyOwnerWallet = makeAddr("externallyOwnerWallet");

        vm.startPrank(distributionOwner);
        distribution.setWallet(externallyOwnerWallet);
        vm.stopPrank();

        assertEq(distribution.getWallet(), externallyOwnerWallet, "wallet not externallyOwnerWallet");

        address externallyOwnedWallet2 = makeAddr("externallyOwnerWallet2");

        // WHEN
        vm.startPrank(distributionOwner);
        distribution.setWallet(externallyOwnedWallet2);
        vm.stopPrank();

        // THEN
        assertEq(distribution.getWallet(), externallyOwnedWallet2, "wallet not changed to other externally owned wallet");
    }
    
    function test_componentSetWalletToExternallyOwnedWithBalance() public {
        // GIVEN - just setUp

        address externallyOwnedWallet = makeAddr("externallyOwnedWallet");
        
        // put some tokens in the distribution component
        vm.startPrank(registryOwner);
        token.transfer(address(distribution), INITIAL_BALANCE);
        vm.stopPrank();

        // WHEN
        vm.startPrank(distributionOwner);
        distribution.setWallet(externallyOwnedWallet);
        vm.stopPrank();

        // THEN
        assertEq(distribution.getWallet(), externallyOwnedWallet, "wallet not changed to externally owned wallet");
        assertEq(token.balanceOf(address(distribution)), 0, "balance of distribution component not 0");
        assertEq(token.balanceOf(externallyOwnedWallet), INITIAL_BALANCE, "exeternally owned wallet balance not 100000");
    }

    function test_componentSetWalletToComponentWithWalance() public {
        // GIVEN - just setUp

        address externallyOwnedWallet = makeAddr("externallyOwnedWallet");

        vm.startPrank(distributionOwner);
        distribution.setWallet(externallyOwnedWallet);
        vm.stopPrank();

        assertEq(distribution.getWallet(), externallyOwnedWallet, "wallet not externallyOwnedWallet");
        
        // put some tokens in the externally owned wallet
        vm.startPrank(registryOwner);
        token.transfer(address(externallyOwnedWallet), INITIAL_BALANCE);
        vm.stopPrank();

        // allowance from externally owned wallet to distribution component
        vm.startPrank(externallyOwnedWallet);
        token.approve(address(distribution.getTokenHandler()), INITIAL_BALANCE);
        vm.stopPrank();
        
        // WHEN
        vm.startPrank(distributionOwner);
        distribution.setWallet(address(distribution));
        vm.stopPrank();

        // THEN
        assertEq(distribution.getWallet(), address(distribution), "wallet not changed to distribution component");
        assertEq(token.balanceOf(address(distribution)), INITIAL_BALANCE, "balance of distribution component not 100000");
        assertEq(token.balanceOf(externallyOwnedWallet), 0, "exeternally owned wallet balance not 0");
    }

    function test_componentSetWalletToComponentWithoutAllowance() public {
        // GIVEN - just setUp

        address externallyOwnedWallet = makeAddr("externallyOwnedWallet");

        vm.startPrank(distributionOwner);
        distribution.setWallet(externallyOwnedWallet);
        vm.stopPrank();

        assertEq(distribution.getWallet(), externallyOwnedWallet, "wallet not externallyOwnedWallet");
        
        // put some tokens in the externally owned wallet
        vm.startPrank(registryOwner);
        token.transfer(address(externallyOwnedWallet), INITIAL_BALANCE);
        vm.stopPrank();

        vm.startPrank(distributionOwner);
        
        // THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                TokenHandler.ErrorTokenHandlerAllowanceTooSmall.selector, 
                address(token),
                externallyOwnedWallet, 
                address(distribution.getTokenHandler()), 
                0, 
                INITIAL_BALANCE));

        // WHEN
        distribution.setWallet(address(distribution));
    }

    function test_componentSetWalletToAnotherExternallyOwnedWithBalance() public {
        // GIVEN - just setUp

        address externallyOwnedWallet = makeAddr("externallyOwnedWallet");
        address externallyOwnedWallet2 = makeAddr("externallyOwnedWallet2");

        vm.startPrank(distributionOwner);
        distribution.setWallet(externallyOwnedWallet);
        vm.stopPrank();

        assertEq(distribution.getWallet(), externallyOwnedWallet, "wallet not externallyOwnedWallet");
        
        // put some tokens in the externally owned wallet
        vm.startPrank(registryOwner);
        token.transfer(address(externallyOwnedWallet), INITIAL_BALANCE);
        vm.stopPrank();

        // allowance from externally owned wallet to distribution component
        vm.startPrank(externallyOwnedWallet);
        token.approve(address(distribution.getTokenHandler()), INITIAL_BALANCE);
        vm.stopPrank();
        
        // WHEN 
        vm.startPrank(distributionOwner);
        distribution.setWallet(externallyOwnedWallet2);
        vm.stopPrank();

        // THEN
        assertEq(distribution.getWallet(), externallyOwnedWallet2, "wallet not changed to distribution component");
        assertEq(token.balanceOf(address(distribution)), 0, "balance of distribution component not 0");
        assertEq(token.balanceOf(externallyOwnedWallet), 0, "exeternally owned wallet balance not 0");
        assertEq(token.balanceOf(externallyOwnedWallet2), INITIAL_BALANCE, "exeternally owned wallet 2 balance not 100000");
    }

    // TODO re-enable
    function skip_test_component_lock() public {
        // GIVEN - just setUp

        Fee memory newDistributionFee = FeeLib.toFee(UFixedLib.toUFixed(123,0), 456);
        Fee memory newMinDistributionOwnerFee = FeeLib.toFee(UFixedLib.toUFixed(124,0), 457);

        // WHEN
        distribution.lock();

        // THEN
        vm.expectRevert(abi.encodeWithSelector(IAccess.ErrorIAccessTargetLocked.selector, address(distribution)));
        distribution.setFees(newMinDistributionOwnerFee, newDistributionFee);
    }

    // TODO re-enable
    function skip_test_component_unlock() public {
        // GIVEN - just setUp

        distribution.lock();
        
        // WHEN
        distribution.unlock();

        // THEN
        Fee memory newDistributionFee = FeeLib.toFee(UFixedLib.toUFixed(123,0), 456);
        Fee memory newMinDistributionOwnerFee = FeeLib.toFee(UFixedLib.toUFixed(124,0), 457);
        distribution.setFees(newMinDistributionOwnerFee, newDistributionFee);
    }

}