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


contract TestDistribution is GifTest {
    using NftIdLib for NftId;

    uint256 public constant INITIAL_BALANCE = 100000;

    function test_DistributionComponentInfo() public {
        // GIVEN
        _prepareDistribution();
        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(distributionNftId);

        // check wallet
        assertEq(componentInfo.wallet, address(distribution), "unexpected wallet address");

        // check token handler
        assertTrue(address(componentInfo.tokenHandler) != address(0), "token handler zero");
        assertEq(address(componentInfo.tokenHandler.getToken()), address(distribution.getToken()), "unexpected token for token handler");
    }


    function test_DistributionSetFees() public {
        // GIVEN
        _prepareProduct(); // includes pool and product

        IComponents.ProductInfo memory productInfo = instanceReader.getProductInfo(productNftId);

        Fee memory distributionFee = productInfo.distributionFee;
        assertEq(distributionFee.fractionalFee.toInt(), 0, "distribution fee not 0 (fractional)");
        assertEq(distributionFee.fixedFee, 0, "distribution fee not 0 (fixed)");

        Fee memory minDistributionOwnerFee = productInfo.minDistributionOwnerFee;
        assertEq(minDistributionOwnerFee.fractionalFee.toInt(), 0, "min distribution owner fee not 0 (fractional)");
        assertEq(minDistributionOwnerFee.fixedFee, 0, "min distribution owner fee fee not 0 (fixed)");
        
        Fee memory newMinDistributionOwnerFee = FeeLib.toFee(UFixedLib.toUFixed(12,0), 34);
        Fee memory newDistributionFee = FeeLib.toFee(UFixedLib.toUFixed(123,0), 456);

        // WHEN
        vm.startPrank(distributionOwner);
        distribution.setFees(newDistributionFee, newMinDistributionOwnerFee);
        vm.stopPrank();

        // THEN
        productInfo = instanceReader.getProductInfo(productNftId);
        distributionFee = productInfo.distributionFee;
        assertEq(distributionFee.fractionalFee.toInt(), 123, "unexpected distribution fee (fractional))");
        assertEq(distributionFee.fixedFee, 456, "unexpected distribution fee not (fixed)");

        minDistributionOwnerFee = productInfo.minDistributionOwnerFee;
        assertEq(minDistributionOwnerFee.fractionalFee.toInt(), 12, "unexpected min distribution owner fee (fractional)");
        assertEq(minDistributionOwnerFee.fixedFee, 34, "unexpected min distribution owner fee not 0 (fixed)");
    }

    function test_Component_setWallet_to_extowned() public {
        // GIVEN
        _prepareDistribution();

        address externallyOwnerWallet = makeAddr("externallyOwnerWallet");

        // WHEN
        distribution.setWallet(externallyOwnerWallet);

        // THEN
        assertEq(distribution.getWallet(), externallyOwnerWallet, "wallet not changed to externallyOwnerWallet");
    }

    function test_Component_setWallet_to_component() public {
        // GIVEN
        _prepareDistribution();

        address externallyOwnerWallet = makeAddr("externallyOwnerWallet");
        distribution.setWallet(externallyOwnerWallet);
        assertEq(distribution.getWallet(), externallyOwnerWallet, "wallet not externallyOwnerWallet");

        // WHEN
        distribution.setWallet(address(distribution));

        // THEN
        assertEq(distribution.getWallet(), address(distribution), "wallet not changed to distribution component");
    }

    function test_Component_setWallet_same_address() public {
        // GIVEN
        _prepareProduct();

        vm.startPrank(distributionOwner);

        address externallyOwnerWallet = makeAddr("externallyOwnerWallet");

        // WHEN (1)
        distribution.setWallet(externallyOwnerWallet);

        // THEN (1)
        assertEq(distribution.getWallet(), externallyOwnerWallet, "wallet not externallyOwnerWallet (1)");
        assertEq(instanceReader.getComponentInfo(distributionNftId).wallet, externallyOwnerWallet, "wallet not externallyOwnerWallet (2)");

        // THEN (2)
        vm.expectRevert(abi.encodeWithSelector(IComponentService.ErrorComponentServiceWalletAddressIsSameAsCurrent.selector));

        // WHEN (2)
        distribution.setWallet(externallyOwnerWallet);

        vm.stopPrank();
    }

    function test_Component_setWallet_to_another_extowned() public {
        // GIVEN
        _prepareDistribution();

        address externallyOwnerWallet = makeAddr("externallyOwnerWallet");
        distribution.setWallet(externallyOwnerWallet);
        assertEq(distribution.getWallet(), externallyOwnerWallet, "wallet not externallyOwnerWallet");

        address externallyOwnedWallet2 = makeAddr("externallyOwnerWallet2");

        // WHEN
        distribution.setWallet(externallyOwnedWallet2);

        // THEN
        assertEq(distribution.getWallet(), externallyOwnedWallet2, "wallet not changed to other externally owned wallet");
    }
    
    function test_Component_setWallet_to_externally_owned_with_balance() public {
        // GIVEN        
        _prepareDistribution();

        address externallyOwnedWallet = makeAddr("externallyOwnedWallet");
        
        // put some tokens in the distribution component
        vm.stopPrank();
        vm.startPrank(registryOwner);
        token.transfer(address(distribution), INITIAL_BALANCE);
        vm.stopPrank();
        vm.startPrank(distributionOwner);

        // WHEN
        distribution.setWallet(externallyOwnedWallet);

        // THEN
        assertEq(distribution.getWallet(), externallyOwnedWallet, "wallet not changed to externally owned wallet");
        assertEq(token.balanceOf(address(distribution)), 0, "balance of distribution component not 0");
        assertEq(token.balanceOf(externallyOwnedWallet), INITIAL_BALANCE, "exeternally owned wallet balance not 100000");
    }

    function test_Component_setWallet_to_component_with_balance() public {
        // GIVEN        
        _prepareDistribution();

        address externallyOwnedWallet = makeAddr("externallyOwnedWallet");
        distribution.setWallet(externallyOwnedWallet);
        assertEq(distribution.getWallet(), externallyOwnedWallet, "wallet not externallyOwnedWallet");
        
        // put some tokens in the externally owned wallet
        vm.stopPrank();
        vm.startPrank(registryOwner);
        token.transfer(address(externallyOwnedWallet), INITIAL_BALANCE);
        vm.stopPrank();

        // allowance from externally owned wallet to distribution component
        vm.startPrank(externallyOwnedWallet);
        token.approve(address(distribution.getTokenHandler()), INITIAL_BALANCE);
        vm.stopPrank();

        vm.startPrank(distributionOwner);
        
        // WHEN
        distribution.setWallet(address(distribution));

        // THEN
        assertEq(distribution.getWallet(), address(distribution), "wallet not changed to distribution component");
        assertEq(token.balanceOf(address(distribution)), INITIAL_BALANCE, "balance of distribution component not 100000");
        assertEq(token.balanceOf(externallyOwnedWallet), 0, "exeternally owned wallet balance not 0");
    }

    function test_Component_setWallet_to_component_without_allowance() public {
        // GIVEN        
        _prepareDistribution();

        address externallyOwnedWallet = makeAddr("externallyOwnedWallet");
        distribution.setWallet(externallyOwnedWallet);
        assertEq(distribution.getWallet(), externallyOwnedWallet, "wallet not externallyOwnedWallet");
        
        // put some tokens in the externally owned wallet
        vm.stopPrank();
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

    function test_Component_setWallet_to_another_externally_owned_with_balance() public {
        // GIVEN        
        _prepareDistribution();

        address externallyOwnedWallet = makeAddr("externallyOwnedWallet");
        address externallyOwnedWallet2 = makeAddr("externallyOwnedWallet2");
        distribution.setWallet(externallyOwnedWallet);
        assertEq(distribution.getWallet(), externallyOwnedWallet, "wallet not externallyOwnedWallet");
        
        // put some tokens in the externally owned wallet
        vm.stopPrank();
        vm.startPrank(registryOwner);
        token.transfer(address(externallyOwnedWallet), INITIAL_BALANCE);
        vm.stopPrank();

        // allowance from externally owned wallet to distribution component
        vm.startPrank(externallyOwnedWallet);
        token.approve(address(distribution.getTokenHandler()), INITIAL_BALANCE);
        vm.stopPrank();

        vm.startPrank(distributionOwner);
        
        // WHEN 
        distribution.setWallet(externallyOwnedWallet2);

        // THEN
        assertEq(distribution.getWallet(), externallyOwnedWallet2, "wallet not changed to distribution component");
        assertEq(token.balanceOf(address(distribution)), 0, "balance of distribution component not 0");
        assertEq(token.balanceOf(externallyOwnedWallet), 0, "exeternally owned wallet balance not 0");
        assertEq(token.balanceOf(externallyOwnedWallet2), INITIAL_BALANCE, "exeternally owned wallet 2 balance not 100000");
    }

    function skip_test_Component_lock() public {
        // GIVEN
        _prepareDistribution();
        Fee memory newDistributionFee = FeeLib.toFee(UFixedLib.toUFixed(123,0), 456);
        Fee memory newMinDistributionOwnerFee = FeeLib.toFee(UFixedLib.toUFixed(124,0), 457);

        // WHEN
        distribution.lock();

        // THEN
        vm.expectRevert(abi.encodeWithSelector(IAccess.ErrorIAccessTargetLocked.selector, address(distribution)));
        distribution.setFees(newMinDistributionOwnerFee, newDistributionFee);
    }

    function skip_test_Component_unlock() public {
        // GIVEN
        _prepareDistribution();
        distribution.lock();
        
        // WHEN
        distribution.unlock();

        // THEN
        Fee memory newDistributionFee = FeeLib.toFee(UFixedLib.toUFixed(123,0), 456);
        Fee memory newMinDistributionOwnerFee = FeeLib.toFee(UFixedLib.toUFixed(124,0), 457);
        distribution.setFees(newMinDistributionOwnerFee, newDistributionFee);
    }

}
