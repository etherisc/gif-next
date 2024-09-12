// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../../lib/forge-std/src/Test.sol";

import {IComponents} from "../../contracts/instance/module/IComponents.sol";
import {IStaking} from "../../contracts/staking/IStaking.sol";

import {Amount, AmountLib} from "../../contracts/type/Amount.sol";
import {ChainId, ChainIdLib} from "../../contracts/type/ChainId.sol";
import {ClaimId} from "../../contracts/type/ClaimId.sol";
import {Fee, FeeLib} from "../../contracts/type/Fee.sol";
import {GifTest} from "../base/GifTest.sol";
import {NftId} from "../../contracts/type/NftId.sol";
import {PayoutId} from "../../contracts/type/PayoutId.sol";
import {ReferralId, ReferralLib} from "../../contracts/type/Referral.sol";
import {RiskId} from "../../contracts/type/RiskId.sol";
import {Seconds, SecondsLib} from "../../contracts/type/Seconds.sol";
import {TimestampLib} from "../../contracts/type/Timestamp.sol";
import {UFixed, UFixedLib} from "../../contracts/type/UFixed.sol";


contract RequiredStakingTest is GifTest {

    ChainId public chainId;
    UFixed public stakingRate;

    // product
    RiskId public riskId;
    ReferralId public referralId;
    Seconds public policyLifetime;


    function setUp() public override {
        super.setUp();

        // start at 1000 seconds and with block number 1000 (block numbers start at 1)
        _wait(SecondsLib.toSeconds(1000), 999);

        _prepareProduct();
        _configureProduct(1000000 * 10 ** token.decimals());
        _configureStaking();

        // fund customer
        vm.startPrank(registryOwner);
        token.transfer(customer, 100000 * 10 ** token.decimals());
        vm.stopPrank();

        vm.startPrank(stakingOwner);
        staking.setStakingRate(
            chainId, 
            address(token), 
            stakingRate);
        vm.stopPrank();

        // approve token handler
        vm.startPrank(customer);
        token.approve(
            address(product.getTokenHandler()),
            token.balanceOf(customer));
        vm.stopPrank();
    }


    function test_stakingRequiredStakingSetup() public {
        // check if staking rate is set correctly
        assertTrue(
            stakingReader.getTokenInfo(chainId, address(token)).stakingRate == stakingRate,
            "unexpected staking rate");

        // check initial tvl info
        IStaking.TvlInfo memory tvlInfo = stakingReader.getTvlInfo(instanceNftId, address(token));
        assertEq(tvlInfo.tvlAmount.toInt(), 0, "unexpected initial tvl amount");
        assertEq(tvlInfo.tvlBaselineAmount.toInt(), 0, "unexpected initial tvl baseline amount");
        assertEq(tvlInfo.updatesCounter, 0, "unexpected initial updates counter");
        assertEq(tvlInfo.lastUpdateIn.toInt(), 1000, "unexpected initial last update in");

        console.log("required stakes (dip)", stakingReader.getRequiredStakeBalance(instanceNftId).toInt());
    }

    /// @dev no test, just checking and experimenting with internal functions
    function test_stakingRequiredStakingConsole() public {

        Amount sumInsured = AmountLib.toAmount(100 * 10 ** token.decimals());
        Amount payoutAmount = AmountLib.toAmount(20 * 10 ** token.decimals());

        _printRequiredStakes("(before)");
        NftId policyNftId1 = _createPolicy(sumInsured);
        _printRequiredStakes("(after 1 policy /w 100 usdc)");
        _createPayout(policyNftId1, payoutAmount);
        _printRequiredStakes("(after payout /w 20 usdc)");
        _closePolicy(policyNftId1);
        _printRequiredStakes("(after closing policy)");
    }


    function test_stakingRequiredStakingCreatePolicy() public {
        // GIVEN 

        Amount sumInsured = AmountLib.toAmount(100 * 10 ** token.decimals());
        Amount requiredStakesBefore = stakingReader.getRequiredStakeBalance(instanceNftId);
        assertEq(requiredStakesBefore.toInt(), 0, "unexpected initial required stakes");

        // WHEN
        NftId policyNftId1 = _createPolicy(sumInsured);

        // THEN
        Amount expectedRequiredStakes = _getExpectedRequiredStakes(sumInsured);
        Amount requiredStakesAfter = stakingReader.getRequiredStakeBalance(instanceNftId);
        assertEq(requiredStakesAfter.toInt(), expectedRequiredStakes.toInt(), "unexpected required stakes after 1 policy");  

        // check tvl info
        IStaking.TvlInfo memory tvlInfo = stakingReader.getTvlInfo(instanceNftId, address(token));
        assertEq(tvlInfo.tvlAmount.toInt(), sumInsured.toInt(), "unexpected tvl amount");
        assertEq(tvlInfo.tvlBaselineAmount.toInt(), 0, "unexpected tvl baseline amount");
        assertEq(tvlInfo.updatesCounter, 1, "unexpected updates counter");
        assertEq(tvlInfo.lastUpdateIn.toInt(), 1000, "unexpected last update in");

        // assertTrue(false, "oops");
    }


    function test_stakingRequiredStakingCreatePayout() public {
        // GIVEN 

        Amount sumInsured = AmountLib.toAmount(100 * 10 ** token.decimals());
        Amount payoutAmount = AmountLib.toAmount(20 * 10 ** token.decimals());
        NftId policyNftId1 = _createPolicy(sumInsured);

        Amount expectedRequiredStakes = _getExpectedRequiredStakes(sumInsured);
        Amount requiredStakesBefore = stakingReader.getRequiredStakeBalance(instanceNftId);
        assertEq(requiredStakesBefore.toInt(), expectedRequiredStakes.toInt(), "unexpected required stakes before payout");

        IStaking.TvlInfo memory tvlInfo = stakingReader.getTvlInfo(instanceNftId, address(token));
        assertEq(tvlInfo.updatesCounter, 1, "unexpected updates counter");

        // WHEN
        _createPayout(policyNftId1, payoutAmount);

        // THEN
        Amount expectedRequiredStakesAfter = _getExpectedRequiredStakes(sumInsured - payoutAmount);
        Amount requiredStakesAfter = stakingReader.getRequiredStakeBalance(instanceNftId);
        assertEq(requiredStakesAfter.toInt(), expectedRequiredStakesAfter.toInt(), "unexpected required stakes after payout");

        // check tvl info
        tvlInfo = stakingReader.getTvlInfo(instanceNftId, address(token));
        Amount expectedTvlAmount = sumInsured - payoutAmount;
        assertEq(tvlInfo.tvlAmount.toInt(), expectedTvlAmount.toInt(), "unexpected tvl amount");
        // 2nd tvl update triggers update of tvl baseline
        assertEq(tvlInfo.tvlBaselineAmount.toInt(), expectedTvlAmount.toInt(), "unexpected tvl baseline amount");
        // reset counter with every 2nd update
        assertEq(tvlInfo.updatesCounter, 0, "unexpected updates counter");
        assertEq(tvlInfo.lastUpdateIn.toInt(), 1001, "unexpected last update in");

        // assertTrue(false, "oops");
    }


    function test_stakingRequiredStakingClosePolicy() public {
        // GIVEN 

        Amount sumInsured = AmountLib.toAmount(100 * 10 ** token.decimals());
        Amount payoutAmount = AmountLib.toAmount(20 * 10 ** token.decimals());
        NftId policyNftId1 = _createPolicy(sumInsured);

        IStaking.TvlInfo memory tvlInfo = stakingReader.getTvlInfo(instanceNftId, address(token));
        assertEq(tvlInfo.updatesCounter, 1, "unexpected updates counter before payout");
        assertEq(tvlInfo.lastUpdateIn.toInt(), 1000, "unexpected last update in before payout");

        _createPayout(policyNftId1, payoutAmount);

        Amount expectedRequiredStakes = _getExpectedRequiredStakes(sumInsured - payoutAmount);
        Amount requiredStakesBefore = stakingReader.getRequiredStakeBalance(instanceNftId);
        assertEq(requiredStakesBefore.toInt(), expectedRequiredStakes.toInt(), "unexpected required stakes before closing");  

        // check tvl info
        tvlInfo = stakingReader.getTvlInfo(instanceNftId, address(token));
        Amount expectedTvlAmountBeforeClosing = sumInsured - payoutAmount;
        assertEq(tvlInfo.tvlAmount.toInt(), expectedTvlAmountBeforeClosing.toInt(), "unexpected tvl amount before closing");
        assertEq(tvlInfo.updatesCounter, 0, "unexpected updates counter before closing");
        assertEq(tvlInfo.lastUpdateIn.toInt(), 1001, "unexpected last update in before closing");

        // WHEN
        _closePolicy(policyNftId1);

        // THEN
        Amount requiredStakesAfter = stakingReader.getRequiredStakeBalance(instanceNftId);
        assertEq(requiredStakesAfter.toInt(), 0, "unexpected required stakes after closing policy");

        // check tvl info
        tvlInfo = stakingReader.getTvlInfo(instanceNftId, address(token));
        // after closing the only policy tvl must be back at 0
        assertEq(tvlInfo.tvlAmount.toInt(), 0, "unexpected tvl amount");
        // 2nd tvl update (the payout) triggers update of tvl baseline
        assertEq(tvlInfo.tvlBaselineAmount.toInt(), expectedTvlAmountBeforeClosing.toInt(), "unexpected tvl baseline amount");
        // reset counter with every 2nd update, after 3rd update counter needs to be at 1 again
        assertEq(tvlInfo.updatesCounter, 1, "unexpected updates counter");
        assertEq(tvlInfo.lastUpdateIn.toInt(), 1002, "unexpected last update in");

        // assertTrue(false, "oops");
    }


    function _createPolicy(Amount sumInsured)
        internal
        returns (NftId policyNftId)
    {
        policyNftId = product.createApplication(
            customer,
            riskId,
            sumInsured.toInt(),
            SecondsLib.toSeconds(30), // lif
            "", // application data
            bundleNftId,
            ReferralLib.zero()
        );

        product.createPolicy(
            policyNftId, 
            true, 
            TimestampLib.current());
    }


    function _getExpectedRequiredStakes(Amount lockedAmount) internal view returns (Amount expectedRequiredStakes) {
        uint256 usdcTokens = lockedAmount.toInt() / 10 ** token.decimals();
        uint256 requiredDipTokens = usdcTokens * 10;
        expectedRequiredStakes = AmountLib.toAmount(requiredDipTokens * 10 ** dip.decimals());
    }


    function _createPayout(NftId policyNftId, Amount amount) internal {
        _wait(SecondsLib.toSeconds(1));
        ClaimId claimId = product.submitClaim(policyNftId, amount, "");
        product.confirmClaim(policyNftId, claimId, amount, "");
        PayoutId payoutId = product.createPayout(policyNftId, claimId, amount, "");
        product.processPayout(policyNftId, payoutId);
    }


    function _closePolicy(NftId policyNftId) internal {
        _wait(policyLifetime);
        product.close(policyNftId);
    }


    function _configureStaking() internal {
        // set staking rate
        // for every usdc token 10 dip tokens must be staked
        chainId = ChainIdLib.current();
        stakingRate = UFixedLib.toUFixed(1, int8(dip.decimals() - token.decimals() + 1));

        // needs component service to be registered
        // can therefore only be called after service registration
        vm.startPrank(staking.getOwner());
        staking.approveTokenHandler(dip, AmountLib.max());
        vm.stopPrank();
    }


    function _configureProduct(uint bundleCapital) internal {
        vm.startPrank(productOwner);
        bytes memory data = "bla di blubb";
        riskId = product.createRisk("42x4711", data);
        policyLifetime = SecondsLib.toSeconds(30);
        vm.stopPrank();

        vm.startPrank(distributionOwner);
        Fee memory distributionFee = FeeLib.toFee(UFixedLib.zero(), 10);
        Fee memory minDistributionOwnerFee = FeeLib.toFee(UFixedLib.zero(), 10);
        distribution.setFees(
            distributionFee, 
            minDistributionOwnerFee);
        referralId = ReferralLib.zero();
        vm.stopPrank();

        vm.startPrank(poolOwner);
        Fee memory poolFee = FeeLib.toFee(UFixedLib.zero(), 10);
        pool.setFees(
            poolFee, 
            FeeLib.zero(), // staking fees
            FeeLib.zero()); // performance fees
        vm.stopPrank();

        vm.startPrank(registryOwner);
        token.transfer(investor, bundleCapital);
        vm.stopPrank();

        vm.startPrank(investor);
        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(poolNftId);
        token.approve(address(componentInfo.tokenHandler), bundleCapital);

        Fee memory bundleFee = FeeLib.toFee(UFixedLib.zero(), 10);
        (bundleNftId,) = pool.createBundle(
            bundleFee, 
            bundleCapital, 
            SecondsLib.toSeconds(604800), 
            ""
        );
        vm.stopPrank();
    }


    function _printRequiredStakes(string memory postfix) internal {
        console.log(
            "required dip stakes", 
            postfix, 
            stakingReader.getRequiredStakeBalance(instanceNftId).toInt()/10**18);
    }


    /// @dev adds a number of seconds to block time, and also moves blocknumber by 1 block ahead
    function _wait(Seconds secondsToWait) internal {
        _wait(secondsToWait, 1);
    }


    /// @dev adds a number of seconds to block time, and a number of blocks to blocknumber
    function _wait(Seconds secondsToWait, uint256 blocksToAdd) internal {
        vm.warp(block.timestamp + secondsToWait.toInt());
        vm.roll(block.number + blocksToAdd);
    }
}
