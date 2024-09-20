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
import {ObjectType, INSTANCE} from "../../contracts/type/ObjectType.sol";
import {PayoutId} from "../../contracts/type/PayoutId.sol";
import {ReferralId, ReferralLib} from "../../contracts/type/Referral.sol";
import {RiskId} from "../../contracts/type/RiskId.sol";
import {Seconds, SecondsLib} from "../../contracts/type/Seconds.sol";
import {TargetHandler} from "../../contracts/staking/TargetHandler.sol";
import {TimestampLib} from "../../contracts/type/Timestamp.sol";
import {UFixed, UFixedLib} from "../../contracts/type/UFixed.sol";


contract RequiredStakingTest is GifTest {

    ChainId public chainId;
    UFixed public stakingRate;

    // support info
    IStaking.SupportInfo public instanceSupportInfo;

    // instance limit info
    Amount public instanceMarginAmount;
    Amount public instanceHardLimitAmount;

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

        // set instance limits
        instanceMarginAmount = AmountLib.toAmount(500 * 10 ** dip.decimals()); // 1'000 DIP margin
        instanceHardLimitAmount = AmountLib.toAmount(5000 * 10 ** dip.decimals()); // 50'000 DIP hard limit
        vm.startPrank(instanceOwner);
        staking.setTargetLimits(
            instanceNftId,
            instanceMarginAmount,
            instanceHardLimitAmount);
        vm.stopPrank();

        // fund customer
        vm.startPrank(tokenIssuer);
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

    //--- setup testing -------------------------------------------------------------//

    function test_stakingRequiredStakingSetup() public {

        // solhint-disable
        console.log("min instance staking", instanceSupportInfo.minStakingAmount.toInt());
        console.log("instance margin", instanceMarginAmount.toInt());
        // solhint-enable

        // check if staking rate is set correctly
        assertTrue(
            stakingReader.getTokenInfo(chainId, address(token)).stakingRate == stakingRate,
            "unexpected staking rate");

        // check margin amount < min staking requirement
        assertTrue(
            instanceMarginAmount < instanceSupportInfo.minStakingAmount,
            "min margin amount not smaller than min instance staking");

        // check initial tvl info
        IStaking.TvlInfo memory tvlInfo = stakingReader.getTvlInfo(instanceNftId, address(token));
        assertEq(tvlInfo.tvlAmount.toInt(), 0, "unexpected initial tvl amount");
        assertEq(tvlInfo.tvlBaselineAmount.toInt(), 0, "unexpected initial tvl baseline amount");
        assertEq(tvlInfo.updatesCounter, 0, "unexpected initial updates counter");
        assertEq(tvlInfo.lastUpdateIn.toInt(), 1000, "unexpected initial last update in");
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

    //--- limit update required -----------------------------------------------------//

    function test_stakingRequiredStakingUpdateRequiredAlways() public {
        // GIVEN
        vm.prank(stakingOwner);
        staking.setUpdateTriggers(
            1, // every tvl change may riggers limit update
            UFixedLib.toUFixed(0)); // any tvl change triggers limit update

        // constants for this test case
        TargetHandler th = staking.getTargetHandler();
        NftId nftid = instanceNftId;
        address tok = address(token);
        Amount z = AmountLib.zero();
        Amount a1 = AmountLib.toAmount(1 * 10 ** token.decimals());
        Amount a2 = AmountLib.toAmount(2 * 10 ** token.decimals());
        Amount a1000000 = AmountLib.toAmount(1000000 * 10 ** token.decimals());
        Amount a1000001 = AmountLib.toAmount(1000001 * 10 ** token.decimals());

        // WHEN + THEN

        // corner cases
        assertFalse(th.isLimitUpdateRequired(nftid, tok, 0, z, z), "unexpected update for 0, 0, 0");
        assertFalse(th.isLimitUpdateRequired(nftid, tok, 1, z, z), "unexpected update for 1, 0, 0");
        assertTrue(th.isLimitUpdateRequired(nftid, tok, 1, z, a1), "no update 1, 0, 1");
        assertTrue(th.isLimitUpdateRequired(nftid, tok, 1, a1, z), "no update 1, 1, 0");
        assertTrue(th.isLimitUpdateRequired(nftid, tok, 1, a1, a1), "no update 1, 1, 1");
        // small values, big delta
        assertTrue(th.isLimitUpdateRequired(nftid, tok, 1, a1, a2), "no update 1, 1, 2");
        assertTrue(th.isLimitUpdateRequired(nftid, tok, 1, a2, a1), "no update 1, 2, 1");
        assertTrue(th.isLimitUpdateRequired(nftid, tok, 1, a2, a2), "no update 1, 2, 2");
        // big values, small delta
        assertTrue(th.isLimitUpdateRequired(nftid, tok, 1, a1000000, a1000000), "no update 1, 1000000, 1000000");
        assertTrue(th.isLimitUpdateRequired(nftid, tok, 1, a1000000, a1000001), "no update 1, 1000000, 1000001");
        assertTrue(th.isLimitUpdateRequired(nftid, tok, 1, a1000001, a1000000), "no update 1, 1000001, 1000000");
    }


    function test_stakingRequiredStakingUpdateRequiredMoreRestrictive() public {
        // GIVEN
        vm.prank(stakingOwner);
        staking.setUpdateTriggers(
            10, // below 10 tvl changes limit update is never triggered
            UFixedLib.toUFixed(11, -1)); // below 10% tvl change limit update is never triggered

        // constants for this test case
        TargetHandler th = staking.getTargetHandler();
        NftId nftid = instanceNftId;
        address tok = address(token);
        Amount a1000 = AmountLib.toAmount(1000 * 10 ** token.decimals());
        Amount a1001 = AmountLib.toAmount(1001 * 10 ** token.decimals());
        Amount a1099 = AmountLib.toAmount(1099 * 10 ** token.decimals());
        Amount a1100 = AmountLib.toAmount(1100 * 10 ** token.decimals());
        Amount a1500 = AmountLib.toAmount(1500 * 10 ** token.decimals());

        // WHEN + THEN

        // check counters
        assertFalse(th.isLimitUpdateRequired(nftid, tok, 0, a1000, a1500), "unexpected update for 0, 1000, 1500");
        assertFalse(th.isLimitUpdateRequired(nftid, tok, 9, a1000, a1500), "unexpected update for 9, 1000, 1500");
        assertTrue(th.isLimitUpdateRequired(nftid, tok, 10, a1000, a1500), "no update 10, 1000, 1500");
        assertTrue(th.isLimitUpdateRequired(nftid, tok, 11, a1000, a1500), "no update 11, 1000, 1500");

        // check tvl changes
        assertFalse(th.isLimitUpdateRequired(nftid, tok, 10, a1000, a1000), "unexpected update for 10, 1000, 1000");
        assertFalse(th.isLimitUpdateRequired(nftid, tok, 10, a1000, a1001), "unexpected update for 10, 1000, 1001");
        assertFalse(th.isLimitUpdateRequired(nftid, tok, 10, a1000, a1099), "unexpected update for 10, 1000, 1099");
        assertTrue(th.isLimitUpdateRequired(nftid, tok, 10, a1000, a1100), "no update 10, 1000, 1100");
        assertTrue(th.isLimitUpdateRequired(nftid, tok, 10, a1000, a1500), "no update 10, 1000, 1100");
    }

    //--- target info limit amount --------------------------------------------------//

    function test_stakingRequiredStakingPolicyNone() public {
        // GIVEN - just setup

        // WHEN - trigger limit update without policy
        vm.prank(outsider);
        staking.updateTargetLimit(instanceNftId);

        // THEN
        IStaking.TargetInfo memory targetInfo = stakingReader.getTargetInfo(instanceNftId);
        assertEq(targetInfo.limitAmount.toInt(), instanceMarginAmount.toInt(), "unexpected initial limit amount");
    }


    function test_stakingRequiredStakingLimitsForVariousSumInsureds() public {
        // solhint-disable
        console.log("instance min staking", instanceSupportInfo.minStakingAmount.toInt()/10**dip.decimals());
        console.log("instance margin", instanceMarginAmount.toInt()/10**dip.decimals());
        console.log("instance hard limit", instanceHardLimitAmount.toInt()/10**dip.decimals());
        // solhint-enable

        _checkLimit(AmountLib.toAmount(0 * 10 ** token.decimals()));
        _checkLimit(AmountLib.toAmount(3 * 10 ** token.decimals()));
        _checkLimit(AmountLib.toAmount(30 * 10 ** token.decimals()));
        _checkLimit(AmountLib.toAmount(300 * 10 ** token.decimals()));
        _checkLimit(AmountLib.toAmount(3000 * 10 ** token.decimals()));
        _checkLimit(AmountLib.toAmount(30000 * 10 ** token.decimals()));

        _checkLimit(AmountLib.toAmount(3000 * 10 ** token.decimals()));
        _checkLimit(AmountLib.toAmount(300 * 10 ** token.decimals()));
        _checkLimit(AmountLib.toAmount(30 * 10 ** token.decimals()));
        _checkLimit(AmountLib.toAmount(3 * 10 ** token.decimals()));
        _checkLimit(AmountLib.toAmount(0 * 10 ** token.decimals()));
    }

    function _checkLimit(Amount sumInsured) internal {
        // GIVEN - policy to end up below min staking amount

        Amount requiredStakes = _getExpectedRequiredStakes(sumInsured, INSTANCE(), false);
        NftId policyNftId = _createPolicy(sumInsured);

        // WHEN - trigger limit update without policy
        vm.prank(outsider);
        staking.updateTargetLimit(instanceNftId);

        // THEN
        IStaking.TargetInfo memory targetInfo = stakingReader.getTargetInfo(instanceNftId);

        // solhint-disable
        console.log(
            "sum_insured required_stakes limit_amount", 
            sumInsured.toInt()/10**token.decimals(),
            requiredStakes.toInt()/10**dip.decimals(),
            targetInfo.limitAmount.toInt()/10**dip.decimals());
        // solhint-enable

        IStaking.LimitInfo memory limitInfo = stakingReader.getLimitInfo(instanceNftId);
        if (targetInfo.limitAmount < limitInfo.hardLimitAmount) {
            assertEq(targetInfo.limitAmount.toInt(), (requiredStakes + instanceMarginAmount).toInt(), "unexpected limit amount (below hard limit)");
        } else {
            assertEq(targetInfo.limitAmount.toInt(), limitInfo.hardLimitAmount.toInt(), "unexpected limit amount (at or above hard limit)");
        }

        // CLEANUP - with check
        _closePolicy(policyNftId);
        vm.prank(outsider);
        staking.updateTargetLimit(instanceNftId);

        targetInfo = stakingReader.getTargetInfo(instanceNftId);
        assertEq(targetInfo.limitAmount.toInt(), instanceMarginAmount.toInt(), "unexpected limit amount (after cleanup)");

        _wait(SecondsLib.toSeconds(1));
    }

    //--- simple policy creation, payout and closing tests --------------------------//

    function test_stakingRequiredStakingCreatePolicy() public {
        // GIVEN 

        Amount sumInsured = AmountLib.toAmount(2000 * 10 ** token.decimals());
        Amount requiredStakesBefore = stakingReader.getRequiredStakeBalance(instanceNftId);
        assertEq(requiredStakesBefore.toInt(), instanceSupportInfo.minStakingAmount.toInt(), "unexpected initial required stakes");

        // WHEN
        NftId policyNftId1 = _createPolicy(sumInsured);

        // THEN
        Amount expectedRequiredStakes = _getExpectedRequiredStakes(sumInsured, INSTANCE());
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

        Amount sumInsured = AmountLib.toAmount(2000 * 10 ** token.decimals());
        Amount payoutAmount = AmountLib.toAmount(100 * 10 ** token.decimals());
        NftId policyNftId1 = _createPolicy(sumInsured);

        Amount expectedRequiredStakes = _getExpectedRequiredStakes(sumInsured, INSTANCE());
        Amount requiredStakesBefore = stakingReader.getRequiredStakeBalance(instanceNftId);
        assertEq(requiredStakesBefore.toInt(), expectedRequiredStakes.toInt(), "unexpected required stakes before payout");

        IStaking.TvlInfo memory tvlInfo = stakingReader.getTvlInfo(instanceNftId, address(token));
        assertEq(tvlInfo.updatesCounter, 1, "unexpected updates counter");

        // WHEN
        _createPayout(policyNftId1, payoutAmount);

        // THEN
        Amount expectedRequiredStakesAfter = _getExpectedRequiredStakes(sumInsured - payoutAmount, INSTANCE());
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

        Amount expectedRequiredStakes = _getExpectedRequiredStakes(sumInsured - payoutAmount, INSTANCE());
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
        assertEq(requiredStakesAfter.toInt(), instanceSupportInfo.minStakingAmount.toInt(), "unexpected required stakes after closing policy");

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


    function _getExpectedRequiredStakes(Amount lockedAmount, ObjectType targetType) internal view returns (Amount expectedRequiredStakes) {
        return _getExpectedRequiredStakes(lockedAmount, targetType, true);
    }


    function _getExpectedRequiredStakes(Amount lockedAmount, ObjectType targetType, bool includeSupportInfo) internal view returns (Amount expectedRequiredStakes) {
        uint256 usdcTokens = lockedAmount.toInt() / 10 ** token.decimals();
        uint256 requiredDipTokens = usdcTokens * 10;
        expectedRequiredStakes = AmountLib.toAmount(requiredDipTokens * 10 ** dip.decimals());

        // update value according to support info
        if (includeSupportInfo) {
            IStaking.SupportInfo memory supportInfo = stakingReader.getSupportInfo(targetType);
            if (expectedRequiredStakes < supportInfo.minStakingAmount) {
                expectedRequiredStakes = supportInfo.minStakingAmount;
            } else if (expectedRequiredStakes > supportInfo.maxStakingAmount) {
                expectedRequiredStakes = supportInfo.maxStakingAmount;
            }
        }
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

        // set tvl update triggers
        vm.startPrank(stakingOwner);
        staking.setUpdateTriggers(2, UFixedLib.toUFixed(1, -1));
        vm.stopPrank();

        // set low minimum required stake amount for instance staking
        IStaking.SupportInfo memory isi = stakingReader.getSupportInfo(INSTANCE());
        vm.startPrank(stakingOwner);
        staking.setSupportInfo(
            INSTANCE(),
            isi.isSupported,
            isi.allowNewTargets,
            isi.allowCrossChain,
            AmountLib.toAmount(1000 * 10 ** 18), // minStakingAmount 500 IDP
            isi.maxStakingAmount,
            isi.minLockingPeriod,
            isi.maxLockingPeriod,
            isi.minRewardRate,
            isi.maxRewardRate);
        vm.stopPrank();

        instanceSupportInfo = stakingReader.getSupportInfo(INSTANCE());

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

        vm.startPrank(tokenIssuer);
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
        // solhint-disable-next-line
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
