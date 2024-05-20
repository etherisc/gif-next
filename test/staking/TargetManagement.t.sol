// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../../lib/forge-std/src/Test.sol";

import {Amount, AmountLib} from "../../contracts/type/Amount.sol";
import {GifTest} from "../base/GifTest.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {IStaking} from "../../contracts/staking/IStaking.sol";
import {IStakingService} from "../../contracts/staking/IStakingService.sol";
import {NftId} from "../../contracts/type/NftId.sol";
import {INSTANCE, PROTOCOL, SERVICE, STAKE, STAKING} from "../../contracts/type/ObjectType.sol";
import {Seconds, SecondsLib} from "../../contracts/type/Seconds.sol";
import {StakeManagerLib} from "../../contracts/staking/StakeManagerLib.sol";
import {TargetManagerLib} from "../../contracts/staking/TargetManagerLib.sol";
import {Timestamp, TimestampLib} from "../../contracts/type/Timestamp.sol";
import {TokenHandler} from "../../contracts/shared/TokenHandler.sol";
import {UFixed, UFixedLib} from "../../contracts/type/UFixed.sol";
import {VersionPart} from "../../contracts/type/Version.sol";


contract StakingTargetManagementTest is GifTest {

    uint256 public constant STAKING_WALLET_APPROVAL = 5000;


    function test_stakingTargetSetLockingPeriodHappyCase() public {
        IStaking.TargetInfo memory targetInfo = stakingReader.getTargetInfo(instanceNftId);
        assertEq(targetInfo.lockingPeriod.toInt(), TargetManagerLib.getDefaultLockingPeriod().toInt(), "unexpected locking period");
        assertEq(registry.ownerOf(instanceNftId), instanceOwner, "unexpected instance owner");

        vm.startPrank(instanceOwner);

        Seconds newLockingPeriod = SecondsLib.toSeconds(14 * 24 * 3600);
        stakingService.setLockingPeriod(
            instanceNftId, 
            newLockingPeriod);

        vm.stopPrank();

        targetInfo = stakingReader.getTargetInfo(instanceNftId);
        assertEq(targetInfo.lockingPeriod.toInt(), newLockingPeriod.toInt(), "unexpected locking period after setting");
    }


    function test_stakingTargetSetLockingPeriodNotTargetOwner() public {
        IStaking.TargetInfo memory targetInfo = stakingReader.getTargetInfo(instanceNftId);
        assertEq(targetInfo.lockingPeriod.toInt(), TargetManagerLib.getDefaultLockingPeriod().toInt(), "unexpected locking period");
        assertEq(registry.ownerOf(instanceNftId), instanceOwner, "unexpected instance owner");
        assertTrue(instanceOwner != staker, "instance and stake owner same");

        vm.startPrank(staker);

        Seconds newLockingPeriod = SecondsLib.toSeconds(14 * 24 * 3600);

        vm.expectRevert(
            abi.encodeWithSelector(
                IStakingService.ErrorStakingServiceNotNftOwner.selector,
                instanceNftId,
                instanceOwner, // expected owner
                staker)); // attempting owner

        stakingService.setLockingPeriod(
            instanceNftId, 
            newLockingPeriod);

        vm.stopPrank();

        targetInfo = stakingReader.getTargetInfo(instanceNftId);
        assertEq(targetInfo.lockingPeriod.toInt(), TargetManagerLib.getDefaultLockingPeriod().toInt(), "unexpected locking period after setting");
    }


    function test_stakingTargetSetRewardRateHappyCase() public {
        IStaking.TargetInfo memory targetInfo = stakingReader.getTargetInfo(instanceNftId);

        assertEq(registry.ownerOf(instanceNftId), instanceOwner, "unexpected instance owner");
        assertEq(_times1000(targetInfo.rewardRate), _times1000(TargetManagerLib.getDefaultRewardRate()), "unexpected reward rate");

        vm.startPrank(instanceOwner);

        UFixed newRewardRate = UFixedLib.toUFixed(75, -3);
        stakingService.setRewardRate(
            instanceNftId, 
            newRewardRate);

        vm.stopPrank();

        targetInfo = stakingReader.getTargetInfo(instanceNftId);
        assertEq(_times1000(targetInfo.rewardRate), _times1000(newRewardRate), "unexpected reward rate (updated)");
    }


    function test_stakingTargetSetRewardRateNotTargetOwner() public {
        IStaking.TargetInfo memory targetInfo = stakingReader.getTargetInfo(instanceNftId);
        UFixed newRewardRate = UFixedLib.toUFixed(75, -3);

        vm.startPrank(staker);

        vm.expectRevert(
            abi.encodeWithSelector(
                IStakingService.ErrorStakingServiceNotNftOwner.selector,
                instanceNftId,
                instanceOwner, // expected owner
                staker)); // attempting owner

        stakingService.setRewardRate(
            instanceNftId, 
            newRewardRate);

        vm.stopPrank();

        // verify reward rate did not change
        targetInfo = stakingReader.getTargetInfo(instanceNftId);
        assertEq(_times1000(targetInfo.rewardRate), _times1000(TargetManagerLib.getDefaultRewardRate()), "unexpected reward rate");
    }


    function test_stakingTargetRefillRewardReservesInstanceOwner() public {

        // GIVEN
        Amount reservesInitialAmount = stakingReader.getRewardBalance(instanceNftId);
        assertEq(reservesInitialAmount.toInt(), 0, "instance reward reserves not 0");

        address stakingWallet = staking.getWallet();
        uint256 refillAmountFullDips = 500;

        (
            TokenHandler tokenHandler, 
            Amount refillAmount
        ) = _prepareAccount(instanceOwner, refillAmountFullDips);

        assertEq(dip.balanceOf(stakingWallet), 0, "staking wallet dip balance not 0 (after instance owner funding)");
        assertEq(refillAmount.toInt(), refillAmountFullDips * 10 ** dip.decimals(), "unexpected refill amount");
        assertEq(dip.balanceOf(instanceOwner), refillAmount.toInt(), "staking owner dip balance not at refill amount (after instance owner funding)");
        assertEq(stakingReader.getReserveBalance(instanceNftId).toInt(), 0, "reward reserves balance not at refill amount (after instance owner funding)");

        // WHEN
        vm.startPrank(instanceOwner);
        stakingService.refillRewardReserves(
            instanceNftId, 
            refillAmount);
        vm.stopPrank();

        // THEN
        // check reward reserve balance from book keeping
        assertEq(stakingReader.getReserveBalance(instanceNftId).toInt(), refillAmount.toInt(), "reward reserves balance not at refill amount (after reward funding)");

        // check dips have been transferred to staking wallet
        assertEq(dip.balanceOf(stakingWallet), refillAmount.toInt(), "staking wallet dip balance not at refill amount (after reward funding)");
        assertEq(dip.balanceOf(instanceOwner), 0, "staking owner dip balance not 0 (after reward funding)");
    }


    function test_stakingTargetRefillRewardReservesOutsider() public {

        // GIVEN
        address stakingWallet = staking.getWallet();
        uint256 refillAmountFullDips = 500;

        // check reward reserve balance from book keeping
        assertEq(stakingReader.getReserveBalance(instanceNftId).toInt(), 0, "reward reserves balance not at refill amount (before funding)");

        assertEq(dip.balanceOf(stakingWallet), 0, "staking wallet dip balance not 0 (before funding)");
        assertEq(dip.balanceOf(outsider), 0, "outsider dip balance not 0 (before funding)");

        // WHEN
        (
            TokenHandler tokenHandler,
            Amount refillAmount
        ) = _addRewardReserves(instanceNftId, outsider, refillAmountFullDips);

        // THEN

        // check reward reserve balance from book keeping
        assertEq(stakingReader.getReserveBalance(instanceNftId).toInt(), refillAmount.toInt(), "reward reserves balance not at refill amount (after reward funding)");

        // check dips have been transferred to staking wallet
        assertEq(dip.balanceOf(stakingWallet), refillAmount.toInt(), "staking wallet dip balance not at refill amount (after reward funding)");
        assertEq(dip.balanceOf(outsider), 0, "outsider dip balance not 0 (after reward funding)");
    }


    function test_stakingTargetWithdrawRewardReservesInstanceOwner() public {

        // GIVEN
        address stakingWallet = staking.getWallet();
        uint256 refillAmountFullDips = 500;
        (
            TokenHandler tokenHandler,
            Amount refillAmount
        ) = _addRewardReserves(instanceNftId, instanceOwner, refillAmountFullDips);

        // check reward reserve balance from book keeping
        assertEq(stakingReader.getReserveBalance(instanceNftId).toInt(), refillAmount.toInt(), "reward reserves balance not at refill amount (after reward funding)");

        // check dips have been transferred to staking wallet
        assertEq(dip.balanceOf(stakingWallet), refillAmount.toInt(), "staking wallet dip balance not at refill amount (after reward funding)");
        assertEq(dip.balanceOf(outsider), 0, "outsider dip balance not 0 (after reward funding)");

        // WHEN (withdraw some reserves)
        Amount withdrawAmount = AmountLib.toAmount(refillAmount.toInt() / 2);

        vm.startPrank(instanceOwner);
        stakingService.withdrawRewardReserves(
            instanceNftId, 
            withdrawAmount);
        vm.stopPrank();

        // THEN 
        // check reward reserve balance from book keeping
        Amount expectedRemainingReserves = refillAmount - withdrawAmount;
        assertEq(stakingReader.getReserveBalance(instanceNftId).toInt(), expectedRemainingReserves.toInt(), "unexpected reward reserves balance (after reserve withdrawal)");

        // check dips have been transferred to staking wallet
        assertEq(dip.balanceOf(stakingWallet), expectedRemainingReserves.toInt(), "unexpected staking wallet dip balance (after reserve withdrawal)");
        assertEq(dip.balanceOf(instanceOwner), withdrawAmount.toInt(), "unexpected instance owner dip balance (after reward funding)");
    }


    function test_stakingTargetWithdrawRewardReservesOutsider() public {

        // GIVEN
        address stakingWallet = staking.getWallet();
        uint256 refillAmountFullDips = 500;
        (
            TokenHandler tokenHandler,
            Amount refillAmount
        ) = _addRewardReserves(instanceNftId, instanceOwner, refillAmountFullDips);

        // WHEN / THEN (withdraw some reserves as outsider)
        Amount withdrawAmount = AmountLib.toAmount(refillAmount.toInt() / 2);

        vm.expectRevert(
            abi.encodeWithSelector(
                IStakingService.ErrorStakingServiceNotNftOwner.selector,
                instanceNftId,
                instanceOwner,
                outsider));

        vm.startPrank(outsider);
        stakingService.withdrawRewardReserves(
            instanceNftId, 
            withdrawAmount);
        vm.stopPrank();
    }


    function setUp() public override {
        super.setUp();

        // set staking wallet approval for staking token handler
        vm.startPrank(stakingOwner);
        staking.approveTokenHandler(AmountLib.max());
        vm.stopPrank();
    }


    function _addRewardReserves(
        NftId instanceNftId, 
        address account, 
        uint256 amount
    )
        internal
        returns(
            TokenHandler tokenHandler,
            Amount refillAmount
        )
    {
        (tokenHandler, refillAmount) = _prepareAccount(account, amount);

        vm.startPrank(account);
        stakingService.refillRewardReserves(
            instanceNftId, 
            refillAmount);
        vm.stopPrank();
    }


    function _prepareAccount(
        address myStaker, 
        uint256 myStakeAmount
    )
        internal
        returns(
            TokenHandler tokenHandler,
            Amount dipAmount
        )
    {
        return _prepareAccount(myStaker, myStakeAmount, true, true, true);
    }


    function _prepareAccount(
        address myStaker, 
        uint256 myStakeAmount,
        bool reset,
        bool withFunding,
        bool withApproval
    )
        internal
        returns(
            TokenHandler tokenHandler,
            Amount dipAmount
        )
    {
        tokenHandler = stakingService.getTokenHandler();
        dipAmount = AmountLib.toAmount(myStakeAmount * 10 ** dip.decimals());

        // return existing dip balance back to registry owner
        if (reset) {
            vm.startPrank(myStaker);
            dip.transfer(registryOwner, dip.balanceOf(myStaker));
            vm.stopPrank();
        }

        if (withFunding) {
            vm.startPrank(registryOwner);
            dip.transfer(myStaker, dipAmount.toInt());
            vm.stopPrank();
        }

        if (withApproval) {
            vm.startPrank(myStaker);
            dip.approve(address(tokenHandler), dipAmount.toInt());
            vm.stopPrank();
        }
    }


    function _times1000(UFixed value) internal pure returns (uint256) {
        return (UFixedLib.toUFixed(1000) * value).toInt();
    }
}