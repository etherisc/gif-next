// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount, AmountLib} from "../../../contracts/type/Amount.sol";
import {ACTIVE} from "../../../contracts/type/StateId.sol";
import {Fee, FeeLib} from "../../../contracts/type/Fee.sol";
import {FireTestBase} from "./FireTestBase.t.sol";
import {IBundle} from "../../../contracts/instance/module/IBundle.sol";
import {SecondsLib} from "../../../contracts/type/Seconds.sol";
import {UFixedLib} from "../../../contracts/type/UFixed.sol";

// solhint-disable func-name-mixedcase
contract FirePoolTest is FireTestBase {

    function setUp() public override {
        super.setUp();
    }

    function test_FirePool_createBundle() public {
        // GIVEN
        vm.startPrank(investor);
        Fee memory bundleFee = FeeLib.percentageFee(2);
        Amount investAmount = AmountLib.toAmount(10000000 * 10 ** 6);
        fireUSD.approve(
            address(firePool.getTokenHandler()), 
            investAmount.toInt());

        uint256 tokenBalanceInvestorBefore = fireUSD.balanceOf(investor);

        // WHEN
        (bundleNftId,) = firePool.createBundle(
            bundleFee, 
            investAmount, 
            SecondsLib.toSeconds(5 * 365 * 24 * 60 * 60)); // 5 years
        vm.stopPrank();

        // THEN
        assertTrue(ACTIVE().eq(instanceReader.getBundleState(bundleNftId)));
        IBundle.BundleInfo memory bundleInfo = instanceReader.getBundleInfo(bundleNftId);
        assertTrue(firePoolNftId.eq(bundleInfo.poolNftId));

        assertEq(tokenBalanceInvestorBefore - investAmount.toInt(), fireUSD.balanceOf(investor));
        assertEq(investAmount.toInt(), fireUSD.balanceOf(firePool.getWallet()));
        assertEq(investAmount.toInt(), instanceReader.getBalanceAmount(firePoolNftId).toInt());
        assertEq(investAmount.toInt(), instanceReader.getBalanceAmount(bundleNftId).toInt());
    }

    function test_FirePool_createBundle_withPoolFee() public {
        // GIVEN
        vm.startPrank(firePoolOwner);
        firePool.setFees(FeeLib.zero(), FeeLib.percentageFee(2), FeeLib.zero());
        vm.stopPrank();

        vm.startPrank(investor);
        Fee memory bundleFee = FeeLib.percentageFee(2);
        Amount investAmount = AmountLib.toAmount(10000000 * 10 ** 6);
        fireUSD.approve(
            address(firePool.getTokenHandler()), 
            investAmount.toInt());

        uint256 tokenBalanceInvestorBefore = fireUSD.balanceOf(investor);

        Amount netStakedAmount;
        // WHEN
        (bundleNftId, netStakedAmount) = firePool.createBundle(
            bundleFee, 
            investAmount, 
            SecondsLib.toSeconds(5 * 365 * 24 * 60 * 60)); // 5 years
        vm.stopPrank();

        // THEN
        assertTrue(ACTIVE().eq(instanceReader.getBundleState(bundleNftId)));
        IBundle.BundleInfo memory bundleInfo = instanceReader.getBundleInfo(bundleNftId);
        assertEq(firePoolNftId, bundleInfo.poolNftId, "bundle.poolNftId mismatch");

        Amount expectedStakingFee = investAmount.multiplyWith(UFixedLib.toUFixed(2) / UFixedLib.toUFixed(100));
        assertEq(investAmount - expectedStakingFee, netStakedAmount, "netStakedAmount mismatch");

        assertEq(tokenBalanceInvestorBefore - investAmount.toInt(), fireUSD.balanceOf(investor));
        assertEq(investAmount.toInt(), fireUSD.balanceOf(firePool.getWallet()));
        assertEq(investAmount, instanceReader.getBalanceAmount(firePoolNftId), "firePool balance mismatch");
        assertEq(investAmount - expectedStakingFee, instanceReader.getBalanceAmount(bundleNftId), "bundle balance mismatch");
    }

    // TODO: add test for createBundle with missing role (once custom role is implemented)
}