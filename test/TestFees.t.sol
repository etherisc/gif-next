// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../lib/forge-std/src/Test.sol";

import {IBundleService} from "../contracts/pool/IBundleService.sol";
import {IComponentService} from "../contracts/shared/IComponentService.sol";
import {IComponents} from "../contracts/instance/module/IComponents.sol";
import {IDistributionService} from "../contracts/distribution/IDistributionService.sol";
import {IPolicy} from "../contracts/instance/module/IPolicy.sol";
import {IPoolComponent} from "../contracts/pool/IPoolComponent.sol";
import {IPoolService} from "../contracts/pool/IPoolService.sol";

import {COLLATERALIZED} from "../contracts/type/StateId.sol";
import {DistributorType} from "../contracts/type/DistributorType.sol";
import {GifTest} from "./base/GifTest.sol";
import {NftId} from "../contracts/type/NftId.sol";
import {FeeLib} from "../contracts/type/Fee.sol";
import {RiskId, RiskIdLib} from "../contracts/type/RiskId.sol";
import {ReferralId, ReferralLib} from "../contracts/type/Referral.sol";
import {Seconds, SecondsLib} from "../contracts/type/Seconds.sol";
import {Timestamp, TimestampLib} from "../contracts/type/Timestamp.sol";
import {TokenHandlerBase} from "../contracts/shared/TokenHandler.sol";
import {Amount, AmountLib} from "../contracts/type/Amount.sol";
import {INftOwnable} from "../contracts/shared/INftOwnable.sol";

contract TestFees is GifTest {

    DistributorType distributorType;
    NftId distributorNftId;
    ReferralId referralId;

    /// @dev test withdraw fees from distribution component as distribution owner
    function test_feesWithdrawDistributionFees() public {
        // GIVEN
        _setupWithActivePolicy(false);

        // solhint-disable-next-line 
        Amount distributionFee = instanceReader.getFeeAmount(distributionNftId);
        assertEq(distributionFee.toInt(), 20, "distribution fee not 20"); // 20% of the 10% premium -> 20
        Amount distributionBalance = instanceReader.getBalanceAmount(distributionNftId);

        uint256 distributionOwnerTokenBalanceBefore = token.balanceOf(distributionOwner);
        uint256 distributionTokenBalanceBefore = token.balanceOf(distribution.getWallet());
        vm.stopPrank();

        Amount withdrawAmount = AmountLib.toAmount(15);
        vm.startPrank(distributionOwner);

        vm.expectEmit();
        emit IComponentService.LogComponentServiceComponentFeesWithdrawn(
            distributionNftId,
            distributionOwner,
            address(token),
            withdrawAmount
        );
        
        // WHEN
        Amount amountWithdrawn = distribution.withdrawFees(withdrawAmount);

        // THEN
        assertEq(amountWithdrawn.toInt(), withdrawAmount.toInt(), "withdrawn amount not 15");
        uint256 distributionOwnerTokenBalanceAfter = token.balanceOf(distributionOwner);
        assertEq(distributionOwnerTokenBalanceAfter, distributionOwnerTokenBalanceBefore + withdrawAmount.toInt(), "distribution owner balance not 15 higher");
        uint256 distributionTokenBalanceAfter = token.balanceOf(distribution.getWallet());
        assertEq(distributionTokenBalanceAfter, distributionTokenBalanceBefore - withdrawAmount.toInt(), "distribution balance not 15 lower");

        Amount distributionFeeAfter = instanceReader.getFeeAmount(distributionNftId);
        assertEq(distributionFeeAfter.toInt(), 5, "distribution fee not 5");
        Amount distributionBalanceAfter = instanceReader.getBalanceAmount(distributionNftId);
        assertEq(distributionBalanceAfter.toInt(), distributionBalance.toInt() - withdrawAmount.toInt(), "distribution balance not 15 lower");
    }

    /// @dev test withdraw fees from distribution component as not the distribution owner
    function test_feesWithdrawDistributionFees_notOwner() public {
        // GIVEN
        _setupWithActivePolicy(false);

        vm.startPrank(poolOwner);
        Amount withdrawAmount = AmountLib.toAmount(15);

        // THEN
        vm.expectRevert(abi.encodeWithSelector(
            INftOwnable.ErrorNftOwnableNotOwner.selector, 
            poolOwner));
            
        // WHEN
        distribution.withdrawFees(withdrawAmount);
    }

    /// @dev try to withdraw all fees from distribution component
    function test_feesWithdrawDistributionFees_getMaxAmount() public {
        // GIVEN
        _setupWithActivePolicy(false);

        // solhint-disable-next-line 
        Amount distributionFee = instanceReader.getFeeAmount(distributionNftId);
        assertEq(distributionFee.toInt(), 20, "distribution fee not 20"); // 20% of the 10% premium -> 20

        uint256 distributionOwnerBalanceBefore = token.balanceOf(distributionOwner);
        uint256 distributionBalanceBefore = token.balanceOf(distribution.getWallet());
        vm.stopPrank();

        // WHEN
        vm.startPrank(distributionOwner);
        Amount withdrawnAmount = distribution.withdrawFees(AmountLib.max());

        // THEN
        assertEq(withdrawnAmount.toInt(), 20, "withdrawn amount not 20");
        uint256 distributionOwnerBalanceAfter = token.balanceOf(distributionOwner);
        assertEq(distributionOwnerBalanceAfter, distributionOwnerBalanceBefore + 20, "distribution owner balance not 20 higher");
        uint256 distributionBalanceAfter = token.balanceOf(distribution.getWallet());
        assertEq(distributionBalanceAfter, distributionBalanceBefore - 20, "distribution balance not 20 lower");

        Amount distributionFeeAfter = instanceReader.getFeeAmount(distributionNftId);
        assertEq(distributionFeeAfter.toInt(), 0, "distribution fee not 0");
    }

    /// @dev try to withdraw more fees than available from distribution component 
    function test_feesWithdrawDistributionFees_withdrawlAmountTooLarge() public {
        // GIVEN
        _setupWithActivePolicy(false);

        // solhint-disable-next-line 
        Amount distributionFee = instanceReader.getFeeAmount(distributionNftId);
        assertEq(distributionFee.toInt(), 20, "distribution fee not 20"); // 20% of the 10% premium -> 20

        uint256 distributionOwnerBalanceBefore = token.balanceOf(distributionOwner);
        uint256 distributionBalanceBefore = token.balanceOf(distribution.getWallet());
        vm.stopPrank();

        Amount withdrawalAmount = AmountLib.toAmount(30);
        vm.startPrank(distributionOwner);
        
        // THEN
        vm.expectRevert(abi.encodeWithSelector(
            IComponentService.ErrorComponentServiceWithdrawAmountExceedsLimit.selector, 
            withdrawalAmount, 
            20));
        
        // WHEN
        Amount withdrawnAmount = distribution.withdrawFees(withdrawalAmount);
    }

    /// @dev try to withdraw when allowance is too small
    function test_feesWithdrawDistributionFees_allowanceTooSmall() public {
        // GIVEN
        _setupWithActivePolicy(false);

        address externalWallet = makeAddr("externalWallet");
        vm.startPrank(distributionOwner);
        
        // use external wallet and set no allowance
        distribution.setWallet(externalWallet);

        Amount withdrawalAmount = AmountLib.toAmount(10);
        
        // THEN
        vm.expectRevert(abi.encodeWithSelector(
            TokenHandlerBase.ErrorTokenHandlerAllowanceTooSmall.selector, 
            address(token),
            externalWallet, 
            address(distribution.getTokenHandler()),
            0,
            10));
        
        // WHEN
        Amount withdrawnAmount = distribution.withdrawFees(withdrawalAmount);
    }

    /// @dev try to withdraw zero amount
    function test_feesWithdrawDistributionFees_withdrawalAmountZero() public {
        // GIVEN
        _setupWithActivePolicy(false);

        Amount withdrawalAmount = AmountLib.toAmount(0);
        vm.startPrank(distributionOwner);
        
        // THEN
        vm.expectRevert(abi.encodeWithSelector(
            IComponentService.ErrorComponentServiceWithdrawAmountIsZero.selector));
        
        // WHEN
        Amount withdrawnAmount = distribution.withdrawFees(withdrawalAmount);
    }

    /// @dev test withdraw fees from pool component as pool owner
    function test_feesWithdrawPoolFeesHappyCase() public {
        // GIVEN
        _setupWithActivePolicy(false);

        // solhint-disable-next-line 
        Amount poolFee = instanceReader.getFeeAmount(poolNftId);
        assertEq(poolFee.toInt(), 5, "pool fee not 5"); // 5% of the 10% premium -> 5
        Amount poolBalance = instanceReader.getBalanceAmount(poolNftId);

        uint256 poolOwnerTokenBalanceBefore = token.balanceOf(poolOwner);
        uint256 poolTokenBalanceBefore = token.balanceOf(pool.getWallet());
        vm.stopPrank();

        // WHEN
        vm.startPrank(poolOwner);
        Amount amountWithdrawn = pool.withdrawFees(AmountLib.toAmount(3));

        // THEN
        assertEq(amountWithdrawn.toInt(), 3, "withdrawn amount not 3");
        uint256 poolOwnerTokenBalanceAfter = token.balanceOf(poolOwner);
        assertEq(poolOwnerTokenBalanceAfter, poolOwnerTokenBalanceBefore + 3, "pool owner balance not 3 higher");
        uint256 poolTokenBalanceAfter = token.balanceOf(pool.getWallet());
        assertEq(poolTokenBalanceAfter, poolTokenBalanceBefore - 3, "pool balance not 3 lower");

        Amount poolFeeAfter = instanceReader.getFeeAmount(poolNftId);
        assertEq(poolFeeAfter.toInt(), 2, "pool fee not 2");
        Amount poolBalanceAfter = instanceReader.getBalanceAmount(poolNftId);
        assertEq(poolBalanceAfter.toInt(), poolBalance.toInt() - 3, "pool balance not 3 lower");
    }

    /// @dev test withdraw fees from pool component as not the pool owner
    function test_feesWithdrawPoolFeesNotOwner() public {
        // GIVEN
        _setupWithActivePolicy(false);

        vm.startPrank(productOwner);
        Amount withdrawAmount = AmountLib.toAmount(3);

        // THEN
        vm.expectRevert(abi.encodeWithSelector(
            INftOwnable.ErrorNftOwnableNotOwner.selector, 
            productOwner));

        // WHEN    
        pool.withdrawFees(withdrawAmount);
    }

    /// @dev test withdraw fees from product component as product owner
    function test_feesWithdrawProductFeesHappyCase() public {
        // GIVEN
        _setupWithActivePolicy(false);

        // solhint-disable-next-line 
        Amount productFee = instanceReader.getFeeAmount(productNftId);
        assertEq(productFee.toInt(), 5, "product fee not 5"); // 5% of the 10% premium -> 5
        Amount productBalance = instanceReader.getBalanceAmount(productNftId);

        uint256 productOwnerTokenBalanceBefore = token.balanceOf(productOwner);
        uint256 productTokenBalanceBefore = token.balanceOf(product.getWallet());
        vm.stopPrank();

        // WHEN
        vm.startPrank(productOwner);
        Amount amountWithdrawn = product.withdrawFees(AmountLib.toAmount(3));

        // THEN
        assertEq(amountWithdrawn.toInt(), 3, "withdrawn amount not 3");
        uint256 productOwnerTokenBalanceAfter = token.balanceOf(productOwner);
        assertEq(productOwnerTokenBalanceAfter, productOwnerTokenBalanceBefore + 3, "product owner balance not 3 higher");
        uint256 productTokenBalanceAfter = token.balanceOf(product.getWallet());
        assertEq(productTokenBalanceAfter, productTokenBalanceBefore - 3, "product balance not 3 lower");

        Amount productFeeAfter = instanceReader.getFeeAmount(productNftId);
        assertEq(productFeeAfter.toInt(), 2, "product fee not 2");
        Amount productBalanceAfter = instanceReader.getBalanceAmount(productNftId);
        assertEq(productBalanceAfter.toInt(), productBalance.toInt() - 3, "product balance not 3 lower");
    }

    /// @dev test withdraw fees from product component as not the product owner
    function test_feesWithdrawProductFees_notOwner() public {
        // GIVEN
        _setupWithActivePolicy(false);

        vm.startPrank(distributionOwner);
        Amount withdrawAmount = AmountLib.toAmount(3);

        // THEN
        vm.expectRevert(abi.encodeWithSelector(
            INftOwnable.ErrorNftOwnableNotOwner.selector, 
            distributionOwner));

        // WHEN
        product.withdrawFees(withdrawAmount);
    }
    
    /// @dev test withdraw of distributor commission
    function test_feesWithdrawCommissionHappyCase() public {
        // GIVEN
        _setupWithActivePolicy(true);

        // solhint-disable-next-line 
        Amount distributionFeeBefore = instanceReader.getFeeAmount(distributionNftId);
        assertEq(distributionFeeBefore.toInt(), 8, "distribution fee not 8"); // 20% of the 10% premium -> 20 - 7 (discount) - 5 (referral) = 8
        Amount distributionBalanceBefore = instanceReader.getBalanceAmount(distributionNftId);

        Amount commission = instanceReader.getFeeAmount(distributorNftId);
        assertEq(commission.toInt(), 5, "commission not 5");

        uint256 distributionOwnerTokenBalanceBefore = token.balanceOf(distributionOwner);
        uint256 distributorTokenBalanceBefore = token.balanceOf(distributor);
        uint256 distributionTokenBalanceBefore = token.balanceOf(distribution.getWallet());
        vm.stopPrank();

        Amount withdrawAmount = AmountLib.toAmount(3);
        vm.startPrank(distributor);

        // THEN - expect a log entry for the commission withdrawal
        vm.expectEmit();
        emit IDistributionService.LogDistributionServiceCommissionWithdrawn(
            distributorNftId,
            distributor,
            address(token),
            withdrawAmount
        );
        
        // WHEN - the distributor withdraws part of his commission
        Amount amountWithdrawn = distribution.withdrawCommission(distributorNftId, withdrawAmount);

        // THEN - make sure, the withdrawn amount is correct and all counters have been correctly updated or not
        assertEq(amountWithdrawn.toInt(), withdrawAmount.toInt(), "withdrawn amount not 3");
        Amount commissionAfter = instanceReader.getFeeAmount(distributorNftId);
        assertEq(commissionAfter.toInt(), 2, "distribution fee not 2");
        Amount distributionFeeAfter = instanceReader.getFeeAmount(distributionNftId);
        assertEq(distributionFeeAfter.toInt(), distributionFeeBefore.toInt(), "distribution fee has changed"); 
        Amount distributionBalanceAfter = instanceReader.getBalanceAmount(distributionNftId);
        assertEq(distributionBalanceAfter.toInt(), distributionBalanceBefore.toInt() - withdrawAmount.toInt(), "distribution balance not 3 lower");

        // and the tokens have been transferred
        uint256 distributionOwnerTokenBalanceAfter = token.balanceOf(distributionOwner);
        assertEq(distributionOwnerTokenBalanceAfter, distributionOwnerTokenBalanceBefore, "distribution owner balance changed");
        uint256 distributorTokenBalanceAfter = token.balanceOf(distributor);
        assertEq(distributorTokenBalanceAfter, distributorTokenBalanceBefore + withdrawAmount.toInt(), "distribution owner balance not 3 higher");
        uint256 distributionTokenBalanceAfter = token.balanceOf(distribution.getWallet());
        assertEq(distributionTokenBalanceAfter, distributionTokenBalanceBefore - withdrawAmount.toInt(), "distribution balance not 3 lower");
    }

    /// @dev test withdraw of distributor commission as not the distributor
    function test_feesWithdrawCommissionNotDistributor() public {
        // GIVEN
        _setupWithActivePolicy(true);

        vm.startPrank(productOwner);
        Amount withdrawAmount = AmountLib.toAmount(3);

        // THEN 
        vm.expectRevert();

        // WHEN - the distributor withdraws part of his commission
        distribution.withdrawCommission(distributorNftId, withdrawAmount);
    }

    /// @dev test withdraw of distributor commission with max value
    function test_feesWithdrawCommissionMaxAmount() public {
        // GIVEN
        _setupWithActivePolicy(true);

        // solhint-disable-next-line 
        Amount distributionFeeBefore = instanceReader.getFeeAmount(distributionNftId);
        assertEq(distributionFeeBefore.toInt(), 8, "distribution fee not 8"); // 20% of the 10% premium -> 20 - 7 (discount) - 5 (referral) = 8

        Amount commission = instanceReader.getFeeAmount(distributorNftId);
        assertEq(commission.toInt(), 5, "commission not 5");

        uint256 distributionOwnerBalanceBefore = token.balanceOf(distributionOwner);
        uint256 distributorBalanceBefore = token.balanceOf(distributor);
        uint256 distributionBalanceBefore = token.balanceOf(distribution.getWallet());
        vm.stopPrank();

        Amount withdrawAmount = AmountLib.max();
        Amount expectedWithdrawnAmount = AmountLib.toAmount(5);
        vm.startPrank(distributor);

        // THEN - expect a log entry for the commission withdrawal
        vm.expectEmit();
        emit IDistributionService.LogDistributionServiceCommissionWithdrawn(
            distributorNftId,
            distributor,
            address(token),
            expectedWithdrawnAmount
        );
        
        // WHEN - the distributor withdraws part of his commission
        Amount amountWithdrawn = distribution.withdrawCommission(distributorNftId, withdrawAmount);

        // THEN - make sure, the withdrawn amount is correct and all counters have been correctly updated or not
        assertEq(amountWithdrawn.toInt(), expectedWithdrawnAmount.toInt(), "withdrawn amount not 5");
        Amount commissionAfter = instanceReader.getFeeAmount(distributorNftId);
        assertEq(commissionAfter.toInt(), 0, "distribution fee not 0");
        Amount distributionFeeAfter = instanceReader.getFeeAmount(distributionNftId);
        assertEq(distributionFeeAfter.toInt(), distributionFeeBefore.toInt(), "distribution fee has changed"); 

        // and the tokens have been transferred
        uint256 distributionOwnerBalanceAfter = token.balanceOf(distributionOwner);
        assertEq(distributionOwnerBalanceAfter, distributionOwnerBalanceBefore, "distribution owner balance changed");
        uint256 distributorBalanceAfter = token.balanceOf(distributor);
        assertEq(distributorBalanceAfter, distributorBalanceBefore + expectedWithdrawnAmount.toInt(), "distribution owner balance not 5 higher");
        uint256 distributionBalanceAfter = token.balanceOf(distribution.getWallet());
        assertEq(distributionBalanceAfter, distributionBalanceBefore - expectedWithdrawnAmount.toInt(), "distribution balance not 5 lower");
    }

    /// @dev test withdraw of distributor commission with a too large amount
    function test_feesWithdrawCommissionAmountTooLarge() public {
        // GIVEN
        _setupWithActivePolicy(true);

        Amount withdrawAmount = AmountLib.toAmount(10);
        vm.startPrank(distributor);

        // THEN 
        vm.expectRevert(abi.encodeWithSelector(
            IDistributionService.ErrorDistributionServiceCommissionWithdrawAmountExceedsLimit.selector, 
            10, 
            5));
        
        // WHEN - the distributor withdraws part of his commission
        distribution.withdrawCommission(distributorNftId, withdrawAmount);
    }

    /// @dev test withdraw of distributor commission with a zero amount
    function test_feesWithdrawCommissionAmountIsZero() public {
        // GIVEN
        _setupWithActivePolicy(true);

        Amount withdrawAmount = AmountLib.toAmount(0);
        vm.startPrank(distributor);

        // THEN 
        vm.expectRevert(abi.encodeWithSelector(
            TokenHandlerBase.ErrorTokenHandlerAmountIsZero.selector));
        
        // WHEN - the distributor withdraws part of his commission
        distribution.withdrawCommission(distributorNftId, withdrawAmount);
    }

    /// @dev test withdraw of distributor commission when allowance is too small
    function test_feesWithdrawCommissionAllowanceTooSmall() public {
        // GIVEN
        _setupWithActivePolicy(true);

        address externalWallet = makeAddr("externalWallet");
        vm.startPrank(distributionOwner);
        distribution.setWallet(externalWallet);
        vm.stopPrank();

        Amount withdrawAmount = AmountLib.max();
        vm.startPrank(distributor);

        // THEN 
        vm.expectRevert(abi.encodeWithSelector(
            TokenHandlerBase.ErrorTokenHandlerAllowanceTooSmall.selector,
            address(token),
            externalWallet,
            address(distribution.getTokenHandler()),
            0,
            5));
        
        // WHEN - the distributor withdraws part of his commission
        distribution.withdrawCommission(distributorNftId, withdrawAmount);
    }

    function test_feesWithdrawBundleFeesHappyCase() public {
        // GIVEN
        _setupWithActivePolicy(false);

        // solhint-disable-next-line 
        Amount bundleFeeBefore = instanceReader.getFeeAmount(bundleNftId);
        assertEq(bundleFeeBefore.toInt(), 10, "bundle fee expected to be 10"); 
        Amount bundleBalanceBefore = instanceReader.getBalanceAmount(bundleNftId);
        Amount poolBalanceBefore = instanceReader.getBalanceAmount(poolNftId);
        Amount poolFeeBefore = instanceReader.getFeeAmount(poolNftId);

        uint256 investorTokenBalanceBefore = token.balanceOf(investor);
        uint256 poolTokenBalanceBefore = token.balanceOf(pool.getWallet());
        vm.stopPrank();

        Amount withdrawAmount = AmountLib.toAmount(5);
        vm.startPrank(investor);

        // THEN - expect a log entry for the fee withdrawal
        vm.expectEmit();
        emit IPoolService.LogPoolServiceFeesWithdrawn(
            bundleNftId,
            investor,
            address(token),
            withdrawAmount
        );
        
        // WHEN - the investor withdraws part of the bundle fee
        Amount amountWithdrawn = pool.withdrawBundleFees(bundleNftId, withdrawAmount);

        // THEN - make sure, the withdrawn amount is correct and all counters have been correctly updated or not
        assertEq(amountWithdrawn.toInt(), withdrawAmount.toInt(), "withdrawn amount not as expected");
        Amount bundleFeeAfter = instanceReader.getFeeAmount(bundleNftId);
        assertEq(bundleFeeAfter.toInt(), bundleFeeBefore.toInt() - withdrawAmount.toInt(), "bundle fee was not decreased by the withdraw amount"); 
        Amount bundleBalanceAfter = instanceReader.getBalanceAmount(bundleNftId);
        assertEq(bundleBalanceAfter.toInt(), bundleBalanceBefore.toInt() - withdrawAmount.toInt(), "bundle balance was not decreased by the withdraw amount");
        Amount poolBalanceAfter = instanceReader.getBalanceAmount(poolNftId);
        assertEq(poolBalanceAfter.toInt(), poolBalanceBefore.toInt() - withdrawAmount.toInt(), "pool balance was not decreased by the withdraw amount");
        Amount poolFeeAfter = instanceReader.getFeeAmount(poolNftId);
        assertEq(poolFeeAfter.toInt(), poolFeeBefore.toInt(), "pool fee has changed");

        // and the tokens have been transferred
        uint256 investorTokenBalanceAfter = token.balanceOf(investor);
        assertEq(investorTokenBalanceAfter, investorTokenBalanceBefore + withdrawAmount.toInt(), "investor did not received the withdrawn tokens");
        uint256 poolTokenBalanceAfter = token.balanceOf(pool.getWallet());
        assertEq(poolTokenBalanceAfter, poolTokenBalanceBefore - withdrawAmount.toInt(), "pool did not transfer the withdrawn tokens");
    }

    /// @dev test withdraw of bundle fees when the bundle is locked
    function test_feesWithdrawBundleFees_bundleLocked() public {
        // GIVEN
        _setupWithActivePolicy(false);

        vm.stopPrank();

        
        Amount withdrawAmount = AmountLib.toAmount(5);
        vm.startPrank(investor);
        pool.setBundleLocked(bundleNftId, true);

        // THEN - expect a log entry for the fee withdrawal
        vm.expectEmit();
        emit IPoolService.LogPoolServiceFeesWithdrawn(
            bundleNftId,
            investor,
            address(token),
            withdrawAmount
        );
        
        // WHEN - the investor withdraws part of his bundle fee from the locked bundle
        Amount amountWithdrawn = pool.withdrawBundleFees(bundleNftId, withdrawAmount);

        // THEN - make sure, the withdrawn amount is correct and all counters have been correctly updated or not
        assertEq(amountWithdrawn.toInt(), withdrawAmount.toInt(), "withdrawn amount not as expected");
    }

    /// @dev test withdraw of bundle fees when the requester is not the bundle owner
    function test_feesWithdrawBundleFees_notBundleOwner() public {
        // GIVEN
        _setupWithActivePolicy(false);

        vm.stopPrank();
        
        Amount withdrawAmount = AmountLib.toAmount(5);
        vm.startPrank(customer);
        
        // THEN - expect a revert
        vm.expectRevert(abi.encodeWithSelector(
            IPoolComponent.ErrorPoolNotBundleOwner.selector, 
            bundleNftId,
            customer));
        
        // WHEN - the customer tries to withdraw 
        pool.withdrawBundleFees(bundleNftId, withdrawAmount);
    }

    /// @dev test withdraw of bundle fees when the max amount is requested
    function test_feesWithdrawBundleFees_maxAmount() public {
        // GIVEN
        _setupWithActivePolicy(false);

        // solhint-disable-next-line 
        Amount bundleFeeBefore = instanceReader.getFeeAmount(bundleNftId);
        assertEq(bundleFeeBefore.toInt(), 10, "bundle fee expected to be 10"); 
        Amount bundleBalanceBefore = instanceReader.getBalanceAmount(bundleNftId);
        Amount poolBalanceBefore = instanceReader.getBalanceAmount(poolNftId);
        Amount poolFeeBefore = instanceReader.getFeeAmount(poolNftId);

        uint256 investorTokenBalanceBefore = token.balanceOf(investor);
        uint256 poolTokenBalanceBefore = token.balanceOf(pool.getWallet());
        vm.stopPrank();

        Amount withdrawAmount = AmountLib.max();
        Amount expectedWithdrawAmount = AmountLib.toAmount(10);
        vm.startPrank(investor);

        // THEN - expect a log entry for the fee withdrawal
        vm.expectEmit();
        emit IPoolService.LogPoolServiceFeesWithdrawn(
            bundleNftId,
            investor,
            address(token),
            bundleFeeBefore
        );
        
        // WHEN - the investor withdraws the maximum available bundle fee amount
        Amount amountWithdrawn = pool.withdrawBundleFees(bundleNftId, withdrawAmount);

        // THEN - make sure, the withdrawn amount is correct and all counters have been correctly updated or not
        assertEq(amountWithdrawn.toInt(), expectedWithdrawAmount.toInt(), "withdrawn amount not as expected");
        Amount bundleFeeAfter = instanceReader.getFeeAmount(bundleNftId);
        assertEq(bundleFeeAfter.toInt(), bundleFeeBefore.toInt() - expectedWithdrawAmount.toInt(), "bundle fee was not decreased by the withdraw amount"); 
        Amount bundleBalanceAfter = instanceReader.getBalanceAmount(bundleNftId);
        assertEq(bundleBalanceAfter.toInt(), bundleBalanceBefore.toInt() - expectedWithdrawAmount.toInt(), "bundle balance was not decreased by the withdraw amount");
        Amount poolBalanceAfter = instanceReader.getBalanceAmount(poolNftId);
        assertEq(poolBalanceAfter.toInt(), poolBalanceBefore.toInt() - expectedWithdrawAmount.toInt(), "pool balance was not decreased by the withdraw amount");
        Amount poolFeeAfter = instanceReader.getFeeAmount(poolNftId);
        assertEq(poolFeeAfter.toInt(), poolFeeBefore.toInt(), "pool fee has changed");

        // and the tokens have been transferred
        uint256 investorTokenBalanceAfter = token.balanceOf(investor);
        assertEq(investorTokenBalanceAfter, investorTokenBalanceBefore + expectedWithdrawAmount.toInt(), "investor did not received the withdrawn tokens");
        uint256 poolTokenBalanceAfter = token.balanceOf(pool.getWallet());
        assertEq(poolTokenBalanceAfter, poolTokenBalanceBefore - expectedWithdrawAmount.toInt(), "pool did not transfer the withdrawn tokens");
    }

    /// @dev test withdraw of bundle fees when the withdraw amount is too large
    function test_feesWithdrawBundleFees_amountTooLarge() public {
        // GIVEN
        _setupWithActivePolicy(false);

        vm.stopPrank();
        
        Amount withdrawAmount = AmountLib.toAmount(50);
        vm.startPrank(investor);
        
        // THEN - expect a revert
        vm.expectRevert(abi.encodeWithSelector(
            IPoolService.ErrorPoolServiceFeesWithdrawAmountExceedsLimit.selector, 
            withdrawAmount,
            10));
        
        // WHEN - the investor tries to withdraw more tokens than available 
        pool.withdrawBundleFees(bundleNftId, withdrawAmount);
    }

    /// @dev test withdraw of bundle fees when the allowance is too small
    function test_feesWithdrawBundleFees_allowanceTooSmall() public {
        // GIVEN
        _setupWithActivePolicy(false);

        vm.stopPrank();

        vm.startPrank(poolOwner);
        address externalWallet = makeAddr("externalWallet");
        pool.setWallet(externalWallet);
        vm.stopPrank();
        
        Amount withdrawAmount = AmountLib.toAmount(7);
        vm.startPrank(investor);
        
        // THEN - expect a revert
        vm.expectRevert(abi.encodeWithSelector(
            TokenHandlerBase.ErrorTokenHandlerAllowanceTooSmall.selector, 
            address(token),
            externalWallet,
            address(pool.getTokenHandler()),
            0,
            7));
        
        // WHEN - the investor tries to withdraw more tokens than available 
        pool.withdrawBundleFees(bundleNftId, withdrawAmount);
    }

    /// @dev test withdraw of bundle fees when the amount is zero
    function test_feesWithdrawBundleFees_amountIsZero() public {
        // GIVEN
        _setupWithActivePolicy(false);

        vm.stopPrank();

        vm.startPrank(poolOwner);
        address externalWallet = makeAddr("externalWallet");
        pool.setWallet(externalWallet);
        vm.stopPrank();
        
        Amount withdrawAmount = AmountLib.toAmount(0);
        vm.startPrank(investor);
        
        // THEN - expect a revert
        vm.expectRevert(abi.encodeWithSelector(
            TokenHandlerBase.ErrorTokenHandlerAmountIsZero.selector));
        
        // WHEN - the investor tries to withdraw more tokens than available 
        pool.withdrawBundleFees(bundleNftId, withdrawAmount);
    }


    function _setupWithActivePolicy(bool purchaseWithReferral) internal returns (NftId policyNftId) {
        vm.startPrank(registryOwner);
        token.transfer(customer, 1000);
        vm.stopPrank();

        _prepareProduct();  

        // setup bundle fees
        vm.startPrank(investor);
        pool.setBundleFee(bundleNftId, FeeLib.percentageFee(10));
        vm.stopPrank();

        // setup pool fees
        vm.startPrank(poolOwner);
        pool.setFees(
            FeeLib.percentageFee(5), 
            FeeLib.zero(),
            FeeLib.zero());
        vm.stopPrank();


        // set product fees
        vm.startPrank(productOwner);
        product.setFees(
            FeeLib.percentageFee(5), 
            FeeLib.zero());
        
        bytes memory data = "bla di blubb";
        RiskId riskId = product.createRisk("42x4711", data);
        vm.stopPrank();

        if (purchaseWithReferral) {
            // prepare distributor type, distributor and referral
            vm.startPrank(distributionOwner);
            distributorType = distribution.createDistributorType(
                "PREMIUM_SELLER", 
                instanceReader.toUFixed(5, -2), 
                instanceReader.toUFixed(8, -2), 
                instanceReader.toUFixed(5, -2), 
                10, 
                SecondsLib.toSeconds(30 * 24 * 60 * 60), 
                false, 
                false, 
                "");
            distributorNftId = distribution.createDistributor(distributor, distributorType, "");
            vm.stopPrank();
            vm.startPrank(distributor);
            referralId = distribution.createReferral(
                distributorNftId,
                "DEAL", 
                instanceReader.toUFixed(5, -2), 
                10, 
                TimestampLib.toTimestamp(30 * 24 * 60 * 60), 
                "");
            vm.stopPrank();
        } else {
            referralId = ReferralLib.zero();
        }

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
        Timestamp activateAt = TimestampLib.current();
        product.createPolicy(policyNftId, true, activateAt); 

        assertTrue(instanceReader.getPolicyState(policyNftId) == COLLATERALIZED(), "policy state not COLLATERALIZED");
        IPolicy.PolicyInfo memory productInfo = instanceReader.getPolicyInfo(policyNftId);
        assertEq(productInfo.activatedAt.toInt(), activateAt.toInt(), "policy activation time not as expected");
    }

    
}