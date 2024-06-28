// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../lib/forge-std/src/Test.sol";

import {BasicDistributionAuthorization} from "../contracts/distribution/BasicDistributionAuthorization.sol";
import {GifTest} from "./base/GifTest.sol";
import {NftId, NftIdLib} from "../contracts/type/NftId.sol";
import {DISTRIBUTION_OWNER_ROLE} from "../contracts/type/RoleId.sol";
import {IComponent} from "../contracts/shared/IComponent.sol";
import {IComponentService} from "../contracts/shared/IComponentService.sol";
import {IComponents} from "../contracts/instance/module/IComponents.sol";
import {IAccess} from "../contracts/instance/module/IAccess.sol";
import {Fee, FeeLib} from "../contracts/type/Fee.sol";
import {UFixedLib} from "../contracts/type/UFixed.sol";
import {SimpleDistribution} from "./mock/SimpleDistribution.sol";
import {RiskId, RiskIdLib} from "../contracts/type/RiskId.sol";
import {ReferralId, ReferralLib} from "../contracts/type/Referral.sol";
import {Seconds, SecondsLib} from "../contracts/type/Seconds.sol";
import {ACTIVE} from "../contracts/type/StateId.sol";
import {TimestampLib} from "../contracts/type/Timestamp.sol";
import {Amount, AmountLib} from "../contracts/type/Amount.sol";

contract TestDistribution is GifTest {
    using NftIdLib for NftId;

    uint256 public constant INITIAL_BALANCE = 100000;

    function test_DistributionComponentInfo() public {
        // GIVEN
        _prepareDistribution();
        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(distributionNftId);

        // check nft id
        assertTrue(componentInfo.productNftId.eqz(), "product nft not zero");

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
                IComponent.ErrorComponentWalletAllowanceTooSmall.selector, 
                externallyOwnedWallet, 
                address(distribution), 
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

    /// @dev test withdraw fees from distribution component as distribution owner
    function test_Distribution_withdrawFee() public {
        // GIVEN
        _setupWithActivePolicy();

        // solhint-disable-next-line 
        Amount distributionFee = instanceReader.getFeeAmount(distributionNftId);
        assertEq(distributionFee.toInt(), 20, "distribution fee not 20"); // 20% of the 10% premium -> 20

        uint256 distributionOwnerBalanceBefore = token.balanceOf(distributionOwner);
        uint256 distributionBalanceBefore = token.balanceOf(address(distribution));
        vm.stopPrank();

        // WHEN
        vm.startPrank(distributionOwner);
        distribution.withdrawFees(AmountLib.toAmount(15));

        // THEN
        uint256 distributionOwnerBalanceAfter = token.balanceOf(distributionOwner);
        assertEq(distributionOwnerBalanceAfter, distributionOwnerBalanceBefore + 15, "distribution owner balance not 15 higher");
        uint256 distributionBalanceAfter = token.balanceOf(address(distribution));
        assertEq(distributionBalanceAfter, distributionBalanceBefore - 15, "distribution balance not 15 lower");

        Amount distributionFeeAfter = instanceReader.getFeeAmount(distributionNftId);
        assertEq(distributionFeeAfter.toInt(), 5, "distribution fee not 5");
    }

    function _setupWithActivePolicy() internal returns (NftId policyNftId) {
        vm.startPrank(registryOwner);
        token.transfer(customer, 1000);
        vm.stopPrank();

        _prepareProduct();  

        vm.startPrank(productOwner);
        
        RiskId riskId = RiskIdLib.toRiskId("42x4711");
        bytes memory data = "bla di blubb";
        product.createRisk(riskId, data);
        vm.stopPrank();

        vm.startPrank(customer);

        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(productNftId);
        token.approve(address(componentInfo.tokenHandler), 1000);
        // revert("checkApprove");

        // crete application
        // solhint-disable-next-line 
        console.log("before application creation");

        uint sumInsuredAmount = 1000;
        Seconds lifetime = SecondsLib.toSeconds(30);
        bytes memory applicationData = "";
        ReferralId referralId = ReferralLib.zero();
        policyNftId = product.createApplication(
            customer,
            riskId,
            sumInsuredAmount,
            lifetime,
            applicationData,
            bundleNftId,
            referralId
        );

        vm.stopPrank();

        assertTrue(policyNftId.gtz(), "policyNftId was zero");

        vm.startPrank(productOwner);

        // solhint-disable-next-line 
        console.log("before collateralization of", policyNftId.toInt());
        product.collateralize(policyNftId, true, TimestampLib.blockTimestamp()); 

        assertTrue(instanceReader.getPolicyState(policyNftId) == ACTIVE(), "policy state not COLLATERALIZED");
    }

    function _prepareDistribution() internal {
        vm.startPrank(instanceOwner);
        instance.grantRole(DISTRIBUTION_OWNER_ROLE(), distributionOwner);
        vm.stopPrank();

        vm.startPrank(distributionOwner);
        distribution = new SimpleDistribution(
            address(registry),
            instanceNftId,
            new BasicDistributionAuthorization("SimpleDistribution"),
            distributionOwner,
            address(token));

        // solhint-disable
        console.log("distribution deployed at: ", address(distribution));
        // solhint-disable
        
        distribution.register();
        distributionNftId = distribution.getNftId();

        // solhint-disable
        console.log("distribution nft id: ", distribution.getNftId().toInt());
        // solhint-disable
    }

}
