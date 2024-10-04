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
        console.log("flight pool token handler", address(flightPool.getTokenHandler()));
        console.log("flight owner", flightOwner);
        console.log("flight owner balance [$]", flightUSD.balanceOf(flightOwner) / 10 ** flightUSD.decimals());
        console.log("flight owner allowance [$] (token handler)", flightUSD.allowance(flightOwner, address(flightPool.getTokenHandler())) / 10 ** flightUSD.decimals());
        // solhint-enable

        // THEN
        assertTrue(flightUSD.allowance(flightOwner, address(flightPool.getTokenHandler())) > 0, "pool allowance zero");
        assertEq(registry.getNftIdForAddress(address(flightPool)).toInt(), flightPoolNftId.toInt(), "unexpected pool nft id");
        assertEq(registry.ownerOf(flightPoolNftId), flightOwner, "unexpected pool owner");
        assertEq(flightPool.getWallet(), address(flightPool.getTokenHandler()), "unexpected pool wallet address");
    }


    function test_flightPoolCreateBundleHappyCase() public {
        // GIVEN - setp from flight base test

        uint256 balanceBefore = flightUSD.balanceOf(flightOwner);
        Amount bundleAmount = AmountLib.toAmount(10000 * 10 ** flightUSD.decimals());

        // WHEN
        vm.prank(flightOwner);
        NftId bundleNftId = flightPool.createBundle(bundleAmount);

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
}