// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {console} from "../lib/forge-std/src/Script.sol";
import {TestGifBase} from "./base/TestGifBase.sol";
import {NftId, toNftId, NftIdLib} from "../contracts/types/NftId.sol";
import {PRODUCT_OWNER_ROLE, POOL_OWNER_ROLE, DISTRIBUTION_OWNER_ROLE} from "../contracts/types/RoleId.sol";
import {Distribution} from "../contracts/components/Distribution.sol";
import {IBaseComponent} from "../contracts/components/IBaseComponent.sol";
import {IRegistry} from "../contracts/registry/IRegistry.sol";
import {ISetup} from "../contracts/instance/module/ISetup.sol";
import {Fee, FeeLib} from "../contracts/types/Fee.sol";
import {UFixedLib} from "../contracts/types/UFixed.sol";

contract TestDistribution is TestGifBase {
    using NftIdLib for NftId;

    uint256 public constant INITIAL_BALANCE = 100000;

    function test_DistributionSetFees() public {
        // GIVEN
        _prepareDistribution();

        ISetup.DistributionSetupInfo memory distributionSetupInfo = instanceReader.getDistributionSetupInfo(distributionNftId);
        Fee memory distributionFee = distributionSetupInfo.distributionFee;
        assertEq(distributionFee.fractionalFee.toInt(), 0, "distribution fee not 0");
        assertEq(distributionFee.fixedFee, 0, "distribution fee not 0");
        
        Fee memory newDistributionFee = FeeLib.toFee(UFixedLib.toUFixed(123,0), 456);

        // WHEN
        distribution.setFees(newDistributionFee);

        // THEN
        distributionSetupInfo = instanceReader.getDistributionSetupInfo(distributionNftId);
        distributionFee = distributionSetupInfo.distributionFee;
        assertEq(distributionFee.fractionalFee.toInt(), 123, "distribution fee not 123");
        assertEq(distributionFee.fixedFee, 456, "distribution fee not 456");
    }

    function test_BaseComponent_setWallet_to_extowned() public {
        // GIVEN
        _prepareDistribution();

        address externallyOwnerWallet = makeAddr("externallyOwnerWallet");

        // WHEN
        distribution.setWallet(externallyOwnerWallet);

        // THEN
        assertEq(distribution.getWallet(), externallyOwnerWallet, "wallet not changed to externallyOwnerWallet");
    }

    function test_BaseComponent_setWallet_to_component() public {
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

    function test_BaseComponent_setWallet_same_address() public {
        // GIVEN
        _prepareDistribution();

        address externallyOwnerWallet = makeAddr("externallyOwnerWallet");
        distribution.setWallet(externallyOwnerWallet);
        assertEq(distribution.getWallet(), externallyOwnerWallet, "wallet not externallyOwnerWallet");

        // THEN
        vm.expectRevert(abi.encodeWithSelector(IBaseComponent.ErrorBaseComponentWalletAddressIsSameAsCurrent.selector, externallyOwnerWallet));

        // WHEN
        distribution.setWallet(externallyOwnerWallet);
    }

    function test_BaseComponent_setWallet_to_another_extowned() public {
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
    
    function test_BaseComponent_setWallet_to_externally_owned_with_balance() public {
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

    function test_BaseComponent_setWallet_to_component_with_balance() public {
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
        token.approve(address(distribution), INITIAL_BALANCE);
        vm.stopPrank();

        vm.startPrank(distributionOwner);
        
        // WHEN
        distribution.setWallet(address(distribution));

        // THEN
        assertEq(distribution.getWallet(), address(distribution), "wallet not changed to distribution component");
        assertEq(token.balanceOf(address(distribution)), INITIAL_BALANCE, "balance of distribution component not 100000");
        assertEq(token.balanceOf(externallyOwnedWallet), 0, "exeternally owned wallet balance not 0");
    }

    function test_BaseComponent_setWallet_to_component_without_allowance() public {
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
                IBaseComponent.ErrorBaseComponentWalletAllowanceTooSmall.selector, 
                externallyOwnedWallet, 
                address(distribution), 
                0, 
                INITIAL_BALANCE));

        // WHEN
        distribution.setWallet(address(distribution));
    }

    function test_BaseComponent_setWallet_to_another_externally_owned_with_balance() public {
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
        token.approve(address(distribution), INITIAL_BALANCE);
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

    function _prepareDistribution() internal {
        vm.startPrank(instanceOwner);
        instanceAccessManager.grantRole(DISTRIBUTION_OWNER_ROLE().toInt(), distributionOwner, 0);
        vm.stopPrank();

        vm.startPrank(distributionOwner);
        distribution = new Distribution(
            address(registry),
            instanceNftId,
            address(token),
            false,
            FeeLib.zeroFee(),
            distributionOwner
        );

        distributionNftId = distributionService.register(address(distribution));
    }

}
