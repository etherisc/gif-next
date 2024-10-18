// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../../../lib/forge-std/src/Test.sol";

import {INftOwnable} from "../../../contracts/shared/INftOwnable.sol";

import {Amount, AmountLib} from "../../../contracts/type/Amount.sol";
import {ACTIVE} from "../../../contracts/type/StateId.sol";
import {FlightBaseTest} from "./FlightBase.t.sol";
import {IBundle} from "../../../contracts/instance/module/IBundle.sol";
import {NftId} from "../../../contracts/type/NftId.sol";
import {SecondsLib} from "../../../contracts/type/Seconds.sol";
import {UFixedLib} from "../../../contracts/type/UFixed.sol";

// solhint-disable func-name-mixedcase
contract FlightPoolTest is FlightBaseTest {

    function setUp() public override {
        super.setUp();

        vm.startPrank(flightOwner);
        flightUSD.approve(
            address(flightPool.getTokenHandler()), 
            flightUSD.balanceOf(flightOwner));
        vm.stopPrank();
    }


    function test_flightPoolSetup() public {
        // GIVEN - setp from flight base test

        // solhint-disable
        console.log("");
        console.log("flight pool", flightPoolNftId.toInt(), address(flightPool));
        console.log("flight pool wallet", flightPool.getWallet());
        console.log("flight pool wallet balance [$]", flightUSD.balanceOf(flightPool.getWallet()) / 10 ** flightUSD.decimals());
        console.log("flight pool wallet allowance [$] (token handler)", flightUSD.allowance(flightPool.getWallet(), address(flightPool.getTokenHandler())) / 10 ** flightUSD.decimals());
        console.log("flight pool token handler", address(flightPool.getTokenHandler()));
        console.log("");
        console.log("flight owner", flightOwner);
        console.log("flight owner balance [$]", flightUSD.balanceOf(flightOwner) / 10 ** flightUSD.decimals());
        console.log("flight owner allowance [$] (token handler)", flightUSD.allowance(flightOwner, address(flightPool.getTokenHandler())) / 10 ** flightUSD.decimals());
        // solhint-enable

        // THEN
        assertTrue(flightUSD.allowance(flightOwner, address(flightPool.getTokenHandler())) > 0, "pool allowance zero");
        assertEq(registry.getNftIdForAddress(address(flightPool)).toInt(), flightPoolNftId.toInt(), "unexpected pool nft id");
        assertEq(registry.ownerOf(flightPoolNftId), flightOwner, "unexpected pool owner");
        assertEq(flightPool.getWallet(), flightPoolWallet, "unexpected pool wallet address");
    }


    function test_flightPoolCreateBundleHappyCase() public {
        // GIVEN - setp from flight base test

        uint256 balanceBefore = flightUSD.balanceOf(flightOwner);
        Amount bundleAmount = AmountLib.toAmount(10000 * 10 ** flightUSD.decimals());

        console.log("balance before", balanceBefore / 10 ** flightUSD.decimals());

        // WHEN
        vm.startPrank(flightOwner);
        NftId bundleNftId = flightPool.createBundle(bundleAmount);
        vm.stopPrank();

        // extrnally managed, need to also transfer token to pool
        _transferTokenToPoolWallet(bundleAmount.toInt(), false);

        // THEN
        assertEq(instanceReader.getBundleState(bundleNftId).toInt(), ACTIVE().toInt(), "unexpected bundle state");

        // check bundle info
        IBundle.BundleInfo memory bundleInfo = instanceReader.getBundleInfo(bundleNftId);
        assertEq(flightPoolNftId.toInt(), bundleInfo.poolNftId.toInt(), "unexpected pool nft id");
        assertEq(instanceReader.getBalanceAmount(flightPoolNftId).toInt(), bundleAmount.toInt(), "unexpected pool balance");
        assertEq(instanceReader.getBalanceAmount(bundleNftId).toInt(), bundleAmount.toInt(), "unexpected bundle balance");
        assertEq(instanceReader.getLockedAmount(bundleNftId).toInt(), 0, "unexpected bundle locked amount");

        // check token balances
        assertEq(flightUSD.balanceOf(flightOwner), balanceBefore - bundleAmount.toInt(), "unexpected investor tioken balance (after)");
        assertEq(flightUSD.balanceOf(flightPool.getWallet()), bundleAmount.toInt(), "unexpected flight pool wallet balance (after)");
    }


    function test_flightPoolCreateBundleNotOwner() public {
        // GIVEN - setp from flight base test

        Amount bundleAmount = AmountLib.toAmount(10000 * 10 ** flightUSD.decimals());

        // WHEN
        vm.expectRevert(
            abi.encodeWithSelector(
                INftOwnable.ErrorNftOwnableNotOwner.selector, 
                outsider));

        vm.prank(outsider);
        bundleNftId = flightPool.createBundle(bundleAmount); 
    }


    function test_flightPoolStakeAndUnstake() public {

        // GIVEN
        Amount bundleAmount = AmountLib.toAmount(10000 * 10 ** flightUSD.decimals());
        uint256 bundleAmountInt = bundleAmount.toInt();

        vm.startPrank(flightOwner);
        NftId bundleNftId = flightPool.createBundle(bundleAmount);
        vm.stopPrank();

        assertEq(flightUSD.balanceOf(flightPool.getWallet()), 0, "unexpected pool wallet balance (before)");
        assertEq(instanceReader.getBalanceAmount(flightPoolNftId).toInt(), bundleAmountInt, "unexpected pool balance (before)");
        assertEq(instanceReader.getLockedAmount(flightPoolNftId).toInt(), 0, "unexpected pool locked amount (before)");
        assertEq(instanceReader.getBalanceAmount(bundleNftId).toInt(), bundleAmountInt, "unexpected bundle balance (before)");
        assertEq(instanceReader.getLockedAmount(bundleNftId).toInt(), 0, "unexpected bundle locked amount (before)");

        // WHEN - increase bundle stake
        Amount stakeAmount = AmountLib.toAmount(3000 * 10 ** flightUSD.decimals());
        uint256 stakeAmountInt = stakeAmount.toInt();

        vm.startPrank(flightOwner);
        flightPool.stake(bundleNftId, stakeAmount);
        vm.stopPrank();

        // THEN
        assertEq(flightUSD.balanceOf(flightPool.getWallet()), 0, "unexpected pool wallet balance (after)");
        assertEq(instanceReader.getBalanceAmount(flightPoolNftId).toInt(), bundleAmountInt + stakeAmountInt, "unexpected pool balance (after)");
        assertEq(instanceReader.getLockedAmount(flightPoolNftId).toInt(), 0, "unexpected pool locked amount (after)");
        assertEq(instanceReader.getBalanceAmount(bundleNftId).toInt(), bundleAmountInt + stakeAmountInt, "unexpected bundle balance (after)");
        assertEq(instanceReader.getLockedAmount(bundleNftId).toInt(), 0, "unexpected bundle locked amount (after)");

        // WHEN - decrease bundle stake
        Amount unstakeAmount = AmountLib.toAmount(6000 * 10 ** flightUSD.decimals());
        uint256 unstakeAmountInt = unstakeAmount.toInt();

        vm.startPrank(flightOwner);
        flightPool.unstake(bundleNftId, unstakeAmount);
        vm.stopPrank();

        // THEN
        assertEq(flightUSD.balanceOf(flightPool.getWallet()), 0, "unexpected pool wallet balance (after 2)");
        assertEq(instanceReader.getBalanceAmount(flightPoolNftId).toInt(), bundleAmountInt + stakeAmountInt - unstakeAmountInt, "unexpected pool balance (after 2)");
        assertEq(instanceReader.getLockedAmount(flightPoolNftId).toInt(), 0, "unexpected pool locked amount (after 2)");
        assertEq(instanceReader.getBalanceAmount(bundleNftId).toInt(), bundleAmountInt + stakeAmountInt - unstakeAmountInt, "unexpected bundle balance (after 2)");
        assertEq(instanceReader.getLockedAmount(bundleNftId).toInt(), 0, "unexpected bundle locked amount (after 2)");

        assertEq(instanceReader.getBalanceAmount(flightPoolNftId).toInt(), 7000 * 10 ** flightUSD.decimals(), "unexpected pool balance (after 2b)");
        assertEq(instanceReader.getBalanceAmount(bundleNftId).toInt(), 7000 * 10 ** flightUSD.decimals(), "unexpected bundle balance (after 2b)");
    }


    function test_flightPoolTransferTokenToAndFromPool() public {

        // GIVEN
        Amount bundleAmount = AmountLib.toAmount(10000 * 10 ** flightUSD.decimals());
        uint256 bundleAmountInt = bundleAmount.toInt();

        vm.startPrank(flightOwner);
        NftId bundleNftId = flightPool.createBundle(bundleAmount);
        vm.stopPrank();

        assertEq(flightUSD.balanceOf(flightPool.getWallet()), 0, "unexpected pool wallet balance (before)");
        assertEq(instanceReader.getBalanceAmount(flightPoolNftId).toInt(), bundleAmountInt, "unexpected pool balance (before)");
        assertEq(instanceReader.getLockedAmount(flightPoolNftId).toInt(), 0, "unexpected pool locked amount (before)");
        assertEq(instanceReader.getBalanceAmount(bundleNftId).toInt(), bundleAmountInt, "unexpected bundle balance (before)");
        assertEq(instanceReader.getLockedAmount(bundleNftId).toInt(), 0, "unexpected bundle locked amount (before)");

        // WHEN - transfer token to pool wallet
        _transferTokenToPoolWallet(bundleAmountInt, false);

        // THEN
        assertEq(flightUSD.balanceOf(flightPool.getWallet()), bundleAmountInt, "unexpected pool wallet balance (after)");
        assertEq(instanceReader.getBalanceAmount(flightPoolNftId).toInt(), bundleAmountInt, "unexpected pool balance (after)");
        assertEq(instanceReader.getLockedAmount(flightPoolNftId).toInt(), 0, "unexpected pool locked amount (after)");
        assertEq(instanceReader.getBalanceAmount(bundleNftId).toInt(), bundleAmountInt, "unexpected bundle balance (after)");
        assertEq(instanceReader.getLockedAmount(bundleNftId).toInt(), 0, "unexpected bundle locked amount (after)");

        // WHEN - transfer token from pool wallet
        uint256 transferAmountInt = 100 * 10 ** flightUSD.decimals();
        vm.prank(flightPoolWallet);
        flightUSD.transfer(flightOwner, transferAmountInt);

        // THEN
        assertEq(flightUSD.balanceOf(flightPool.getWallet()), bundleAmountInt - transferAmountInt, "unexpected pool wallet balance (after 2)");
        assertEq(instanceReader.getBalanceAmount(flightPoolNftId).toInt(), bundleAmountInt, "unexpected pool balance (after 2)");
        assertEq(instanceReader.getLockedAmount(flightPoolNftId).toInt(), 0, "unexpected pool locked amount (after 2)");
        assertEq(instanceReader.getBalanceAmount(bundleNftId).toInt(), bundleAmountInt, "unexpected bundle balance (after 2)");
        assertEq(instanceReader.getLockedAmount(bundleNftId).toInt(), 0, "unexpected bundle locked amount (after 2)");
    }
}