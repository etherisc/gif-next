// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../lib/forge-std/src/Test.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {BasicDistributionAuthorization} from "../contracts/distribution/BasicDistributionAuthorization.sol";
import {Fee, FeeLib} from "../contracts/type/Fee.sol";
import {GifTest} from "./base/GifTest.sol";
import {IAccess} from "../contracts/instance/module/IAccess.sol";
import {IComponent} from "../contracts/shared/IComponent.sol";
import {IComponents} from "../contracts/instance/module/IComponents.sol";
import {IComponentService} from "../contracts/shared/IComponentService.sol";
import {NftId, NftIdLib} from "../contracts/type/NftId.sol";
import {SimpleDistribution} from "../contracts/examples/unpermissioned/SimpleDistribution.sol";
import {TokenHandler, TokenHandlerBase} from "../contracts/shared/TokenHandler.sol";
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
        assertEq(componentInfo.tokenHandler.getWallet(), address(distribution.getTokenHandler()), "unexpected wallet address");

        // check token handler
        assertTrue(address(componentInfo.tokenHandler) != address(0), "token handler zero");
        assertEq(address(componentInfo.tokenHandler.TOKEN()), address(distribution.getToken()), "unexpected token for token handler");
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

        vm.startPrank(registryOwner);
        token.transfer(distribution.getWallet(), INITIAL_BALANCE);
        vm.stopPrank();

        assertEq(distribution.getWallet(), address(distribution.getTokenHandler()), "wallet not token handler");
        assertEq(token.balanceOf(address(distribution.getTokenHandler())), INITIAL_BALANCE, "unexpected balance for distribution token handler wallet (0)");
        assertEq(token.balanceOf(externallyOwnerWallet), 0, "unexpected balance for distribution external wallet (0)");

        vm.startPrank(externallyOwnerWallet);
        token.approve(address(distribution.getTokenHandler()), INITIAL_BALANCE);
        vm.stopPrank();

        vm.startPrank(distributionOwner);
        distribution.setWallet(externallyOwnerWallet);
        vm.stopPrank();

        assertEq(distribution.getWallet(), externallyOwnerWallet, "wallet not externallyOwnerWallet");
        assertEq(token.balanceOf(address(distribution.getTokenHandler())), 0, "unexpected balance for distribution token handler wallet (1)");
        assertEq(token.balanceOf(externallyOwnerWallet), INITIAL_BALANCE, "unexpected balance for distribution external wallet (1)");

        // WHEN
        vm.startPrank(distributionOwner);
        distribution.setWallet(address(0));
        vm.stopPrank();

        // THEN
        assertEq(distribution.getWallet(), address(distribution.getTokenHandler()), "wallet not changed back to distribution component");
        assertEq(token.balanceOf(address(distribution.getTokenHandler())), INITIAL_BALANCE, "unexpected balance for distribution token handler wallet (2)");
        assertEq(token.balanceOf(externallyOwnerWallet), 0, "unexpected balance for distribution external wallet (2)");
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
        assertEq(instanceReader.getComponentInfo(distributionNftId).tokenHandler.getWallet(), externallyOwnerWallet, "wallet not externallyOwnerWallet (2)");

        // THEN (2)
        vm.expectRevert(
            abi.encodeWithSelector(
                TokenHandlerBase.ErrorTokenHandlerAddressIsSameAsCurrent.selector));

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

        // put some tokens in the distribution wallet
        vm.startPrank(registryOwner);
        token.transfer(address(distribution.getTokenHandler()), INITIAL_BALANCE);
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
                TokenHandlerBase.ErrorTokenHandlerAllowanceTooSmall.selector, 
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

        // put some tokens in the externally owned wallet
        vm.startPrank(registryOwner);
        token.transfer(address(externallyOwnedWallet), INITIAL_BALANCE);
        vm.stopPrank();

        vm.startPrank(distributionOwner);
        distribution.setWallet(externallyOwnedWallet);
        vm.stopPrank();

        // check initial balance after funding
        assertEq(distribution.getWallet(), externallyOwnedWallet, "wallet not externallyOwnedWallet");
        assertEq(token.balanceOf(distribution.getWallet()), INITIAL_BALANCE, "unexpected balance for exeternally owned wallet (after funding)");

        // allowance from externally owned wallet to distribution component
        vm.startPrank(externallyOwnedWallet);
        token.approve(address(distribution.getTokenHandler()), INITIAL_BALANCE);
        vm.stopPrank();
        
        // WHEN 
        vm.startPrank(distributionOwner);
        distribution.setWallet(externallyOwnedWallet2);
        vm.stopPrank();

        // THEN
        assertEq(distribution.getWallet(), externallyOwnedWallet2, "wallet not changed to externallyOwnedWallet2");
        assertEq(token.balanceOf(address(distribution)), 0, "balance of distribution component not 0");
        assertEq(token.balanceOf(externallyOwnedWallet), 0, "externally owned wallet balance not 0");
        assertEq(token.balanceOf(externallyOwnedWallet2), INITIAL_BALANCE, "externally owned wallet 2 balance not 100000");
    }

    function test_componentSetLockedTrue() public {
        // GIVEN - just setUp
        Fee memory newDistributionFee = FeeLib.toFee(UFixedLib.toUFixed(123,0), 456);
        Fee memory newMinDistributionOwnerFee = FeeLib.toFee(UFixedLib.toUFixed(124,0), 457);

        assertFalse(instanceReader.isLocked(address(distribution)), "distribution locked");

        // WHEN
        vm.startPrank(distributionOwner);
        distribution.setLocked(true);

        assertTrue(instanceReader.isLocked(address(distribution)), "distribution not locked");

        // THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessManaged.AccessManagedUnauthorized.selector, 
                address(distributionOwner)));

        distribution.setFees(newMinDistributionOwnerFee, newDistributionFee);
    }

    function test_componentSetLockedFalse() public {
        // GIVEN - just setUp
        Fee memory newDistributionFee = FeeLib.toFee(UFixedLib.toUFixed(123,0), 456);
        Fee memory newMinDistributionOwnerFee = FeeLib.toFee(UFixedLib.toUFixed(124,0), 457);
        
        vm.startPrank(distributionOwner);
        distribution.setLocked(true);

        assertTrue(instanceReader.isLocked(address(distribution)), "distribution not locked");

        // WHEN
        distribution.setLocked(false);

        assertFalse(instanceReader.isLocked(address(distribution)), "distribution not locked");

        // THEN
        distribution.setFees(newMinDistributionOwnerFee, newDistributionFee);
    }

}
