// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../../lib/forge-std/src/Test.sol";

import {IInstance} from "../../contracts/instance/IInstance.sol";
import {INftOwnable} from "../../contracts/shared/INftOwnable.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {IStaking} from "../../contracts/staking/IStaking.sol";
import {IStakingService} from "../../contracts/staking/IStakingService.sol";

import {Amount, AmountLib} from "../../contracts/type/Amount.sol";
import {BlocknumberLib} from "../../contracts/type/Blocknumber.sol";
import {GifTest} from "../base/GifTest.sol";
import {NftId, NftIdLib} from "../../contracts/type/NftId.sol";
import {STAKE} from "../../contracts/type/ObjectType.sol";
import {Seconds, SecondsLib} from "../../contracts/type/Seconds.sol";
import {StakingLib} from "../../contracts/staking/StakingLib.sol";
import {StakingStore} from "../../contracts/staking/StakingStore.sol";
import {TargetManagerLib} from "../../contracts/staking/TargetManagerLib.sol";
import {Timestamp, TimestampLib} from "../../contracts/type/Timestamp.sol";
import {TokenHandler} from "../../contracts/shared/TokenHandler.sol";
import {UFixed, UFixedLib} from "../../contracts/type/UFixed.sol";


contract StakingProtocolTargetTest is GifTest {

    uint256 public constant STAKING_PROTOCOL_REWARD_BALANCE = 5000;
    NftId public protocolNftId;
    UFixed public protocolRewardRate;
    Amount public initialProtocolRewardAmount;

    function setUp() public override {
        super.setUp();

        protocolNftId = registry.getProtocolNftId();
        protocolRewardRate = stakingReader.getRewardRate(protocolNftId);

        // fund staking owner with DIPs
        _prepareAccount(stakingOwner, STAKING_PROTOCOL_REWARD_BALANCE);

        vm.startPrank(stakingOwner);

        // needs staking service to be registered
        // can therefore only be called after service registration
        staking.approveTokenHandler(dip, AmountLib.max());

        // approve token handler to pull dips from staking owner
        Amount refillAmount = AmountLib.toAmount(STAKING_PROTOCOL_REWARD_BALANCE * 10 ** dip.decimals());
        dip.approve(
            address(staking.getTokenHandler()),
            refillAmount.toInt());

        // refill protocol reward reserves
        staking.refillRewardReserves(protocolNftId, refillAmount);
        initialProtocolRewardAmount = stakingReader.getReserveBalance(protocolNftId);

        vm.stopPrank();
    }


    function test_stakingProtocolTargetSetUp() public {
        _printAuthz(registryAdmin, "registry setup");

        assertEq(protocolNftId.toInt(), 1101, "unexpected protocol nft id");
        assertTrue(protocolRewardRate == UFixedLib.toUFixed(5, -2), "unexpected protocol reward rate");
        assertEq(staking.getWallet(), address(staking.getTokenHandler()), "unexpected staking wallet");
        assertEq(staking.getOwner(), stakingOwner, "unexpected staking owner");
        assertEq(dip.allowance(staking.getWallet(), address(staking.getTokenHandler())), type(uint256).max, "unexpected allowance for staking token handler");

        // solhint-disable
        console.log("registry owner:", registryOwner);
        console.log("staking owner:", staking.getOwner());
        console.log("staking nft id:", staking.getNftId().toInt());
        console.log("staking address:", address(staking));
        console.log("staking token handler address:", address(staking.getTokenHandler()));
        console.log("staking wallet address:", address(staking.getWallet()));
        console.log("protocol nft id:", protocolNftId.toInt());
        console.log("protocol reward rate [%]:", stakingReader.getRewardRate(protocolNftId).toInt1000()/10);
        // solhint-enable
    }


    function test_stakingProtocolTargetCreateStake() public {
        // GIVEN
        uint256 fullDipsAmount = 3000;
        address stakingWallet = staking.getWallet();
        assertEq(dip.balanceOf(stakingWallet), initialProtocolRewardAmount.toInt(), "unexpected balance for staking wallet (before)");

        // WHEN
        (, Amount dipAmount, NftId stakeNftId) = _prepareStake(outsider, protocolNftId, fullDipsAmount);

        // THEN
        assertEq(registry.ownerOf(stakeNftId), outsider, "unexpected owner for stake nft");

        IStaking.StakeInfo memory stakeInfo = stakingReader.getStakeInfo(stakeNftId);
        assertEq(stakeInfo.stakedAmount.toInt(), dipAmount.toInt(), "unexpected stake amount");
        assertEq(stakeInfo.rewardAmount.toInt(), 0, "unexpected reward amount");
        assertEq(stakeInfo.targetNftId.toInt(), protocolNftId.toInt(), "unexpected stake parent nft id");

        assertEq(dip.balanceOf(stakingWallet), (initialProtocolRewardAmount + dipAmount).toInt(), "unexpected balance for staking wallet (after)");
        assertEq(dip.balanceOf(outsider), 0, "unexpected balance for staker");
    }


    function test_stakingProtocolTargetUpdateRewards() public {
        // GIVEN
        uint256 fullDipsAmount = 3000;
        address stakingWallet = staking.getWallet();
        (, Amount dipAmount, NftId stakeNftId) = _prepareStake(outsider, protocolNftId, fullDipsAmount);
        assertEq(dip.balanceOf(stakingWallet), (initialProtocolRewardAmount + dipAmount).toInt(), "unexpected balance for staking wallet (before)");
        assertEq(dip.balanceOf(outsider), 0, "unexpected balance for staker (before)");

        // WHEN
        _wait(SecondsLib.oneYear());

        vm.prank(outsider);
        staking.updateRewards(stakeNftId);

        // THEN
        Amount expectedRewardAmount = dipAmount.multiplyWith(protocolRewardRate);
        assertEq(expectedRewardAmount.toInt(), dipAmount.toInt() / 20, "unexpected expected reward amount");

        IStaking.StakeInfo memory stakeInfo = stakingReader.getStakeInfo(stakeNftId);
        assertEq(stakeInfo.stakedAmount.toInt(), dipAmount.toInt(), "unexpected staked amount (after)");
        assertEq(stakeInfo.rewardAmount.toInt(), expectedRewardAmount.toInt(), "unexpected reward amount (after)");
        assertEq(dip.balanceOf(stakingWallet), (initialProtocolRewardAmount + dipAmount).toInt(), "unexpected balance for staking wallet (after)");
        assertEq(dip.balanceOf(outsider), 0, "unexpected balance for staker (after)");
    }


    function test_stakingProtocolTargetClaimRewards() public {
        // GIVEN
        uint256 fullDipsAmount = 3000;
        address stakingWallet = staking.getWallet();
        (, Amount dipAmount, NftId stakeNftId) = _prepareStake(outsider, protocolNftId, fullDipsAmount);
        assertEq(dip.balanceOf(stakingWallet), (initialProtocolRewardAmount + dipAmount).toInt(), "unexpected balance for staking wallet (before)");
        assertEq(dip.balanceOf(outsider), 0, "unexpected balance for staker (before)");

        // WHEN
        _wait(SecondsLib.oneYear());

        vm.prank(outsider);
        staking.claimRewards(stakeNftId);

        // THEN
        Amount expectedRewardAmount = dipAmount.multiplyWith(protocolRewardRate);
        assertEq(expectedRewardAmount.toInt(), dipAmount.toInt() / 20, "unexpected expected reward amount");
        assertEq(dip.balanceOf(stakingWallet), (initialProtocolRewardAmount + dipAmount - expectedRewardAmount).toInt(), "unexpected balance for staking wallet (after claimRewards)");
        assertEq(dip.balanceOf(outsider), expectedRewardAmount.toInt(), "unexpected balance for staker (after claimRewards)");
    }


    function test_stakingProtocolTargetStake() public {
        // GIVEN
        uint256 fullDipsAmount = 3000;
        address stakingWallet = staking.getWallet();
        (, Amount dipAmount, NftId stakeNftId) = _prepareStake(outsider, protocolNftId, fullDipsAmount);
        assertEq(dip.balanceOf(stakingWallet), (initialProtocolRewardAmount + dipAmount).toInt(), "unexpected balance for staking wallet (before)");
        assertEq(dip.balanceOf(outsider), 0, "unexpected balance for staker (before)");

        // WHEN
        uint256 additionalFullDipAmount = 1000;
        (, Amount additionalDipAmount) = _prepareAccount(outsider, additionalFullDipAmount);

        _wait(SecondsLib.oneYear());

        vm.prank(outsider);
        staking.stake(stakeNftId, additionalDipAmount);

        // THEN
        Amount expectedRewardAmount = dipAmount.multiplyWith(protocolRewardRate);

        IStaking.StakeInfo memory stakeInfo = stakingReader.getStakeInfo(stakeNftId);
        assertEq(stakeInfo.stakedAmount.toInt(), (dipAmount + expectedRewardAmount + additionalDipAmount).toInt(), "unexpected staked amount (after stake)");
        assertEq(stakeInfo.rewardAmount.toInt(), 0, "unexpected reward amount (after stake)");

        assertEq(dip.balanceOf(stakingWallet), (initialProtocolRewardAmount + dipAmount + additionalDipAmount).toInt(), "unexpected balance for staking wallet (after stake)");
        assertEq(dip.balanceOf(outsider), 0, "unexpected balance for staker (after stake)");
    }


    function test_stakingProtocolTargetUnstake() public {
        // GIVEN
        uint256 fullDipsAmount = 3000;
        address stakingWallet = staking.getWallet();
        (, Amount dipAmount, NftId stakeNftId) = _prepareStake(outsider, protocolNftId, fullDipsAmount);
        assertEq(dip.balanceOf(stakingWallet), (initialProtocolRewardAmount + dipAmount).toInt(), "unexpected balance for staking wallet (before)");
        assertEq(dip.balanceOf(outsider), 0, "unexpected balance for staker (before)");

        // WHEN
        _wait(SecondsLib.oneYear());

        // THEN
        vm.prank(outsider);
        Amount unstakedAmount = staking.unstake(stakeNftId);

        IStaking.StakeInfo memory stakeInfo = stakingReader.getStakeInfo(stakeNftId);
        assertEq(stakeInfo.stakedAmount.toInt(), 0, "unexpected staked amount (after unstake)");
        assertEq(stakeInfo.rewardAmount.toInt(), 0, "unexpected reward amount (after unstake)");

        Amount expectedRewardAmount = dipAmount.multiplyWith(protocolRewardRate);
        assertEq(unstakedAmount.toInt(), (dipAmount + expectedRewardAmount).toInt(), "unexpected unstaked amount");
        assertEq(dip.balanceOf(stakingWallet), (initialProtocolRewardAmount - expectedRewardAmount).toInt(), "unexpected balance for staking wallet (after unstake)");
        assertEq(dip.balanceOf(outsider), (dipAmount + expectedRewardAmount).toInt(), "unexpected balance for staker (after unstake)");
    }


    function _prepareStake(
        address myStaker, 
        NftId myTargetNftId,
        uint256 myStakeAmount
    )
        internal
        returns(
            TokenHandler tokenHandler,
            Amount dipAmount,
            NftId stakeNftId
        )
    {
        (tokenHandler, dipAmount) = _prepareAccount(myStaker, myStakeAmount);

        vm.prank(myStaker);
        stakeNftId = staking.createStake(
            myTargetNftId, 
            dipAmount,
            myStaker); // stake owner
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
        return _prepareAccount(myStaker, myStakeAmount, true, true);
    }


    function _prepareAccount(
        address myStaker, 
        uint256 myStakeAmount,
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

        if (withFunding) {
            vm.startPrank(tokenIssuer);
            dip.transfer(myStaker, dipAmount.toInt());
            vm.stopPrank();
        }

        if (withApproval) {
            vm.startPrank(myStaker);
            dip.approve(address(tokenHandler), dipAmount.toInt());
            vm.stopPrank();
        }
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