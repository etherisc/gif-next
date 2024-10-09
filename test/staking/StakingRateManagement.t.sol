// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../../lib/forge-std/src/Test.sol";

import {IStaking} from "../../contracts/staking/IStaking.sol";

import {Amount, AmountLib} from "../../contracts/type/Amount.sol";
import {Blocknumber, BlocknumberLib} from "../../contracts/type/Blocknumber.sol";
import {ChainId, ChainIdLib} from "../../contracts/type/ChainId.sol";
import {ClaimId} from "../../contracts/type/ClaimId.sol";
import {GifTest} from "../base/GifTest.sol";
import {NftId} from "../../contracts/type/NftId.sol";
import {PayoutId} from "../../contracts/type/PayoutId.sol";
import {ReferralLib} from "../../contracts/type/Referral.sol";
import {RiskId, RiskIdLib} from "../../contracts/type/RiskId.sol";
import {Seconds, SecondsLib} from "../../contracts/type/Seconds.sol";
import {StakingLib} from "../../contracts/staking/StakingLib.sol";
import {TargetManagerLib} from "../../contracts/staking/TargetManagerLib.sol";
import {Timestamp, TimestampLib} from "../../contracts/type/Timestamp.sol";
import {UFixed, UFixedLib} from "../../contracts/type/UFixed.sol";import {VersionPart} from "../../contracts/type/Version.sol";


contract StakingRateManagement is GifTest {

    // TODO find better solution than copying event from IStaking
    event LogStakingProtocolLockingPeriodSet(NftId targetNftId, Seconds newLockingPeriod, Seconds oldLockingPeriod, Blocknumber lastUpdatedIn);
    event LogStakingProtocolRewardRateSet(NftId targetNftId, UFixed newRewardRate, UFixed oldRewardRate, Blocknumber lastUpdatedIn);
    event LogStakingStakingRateSet(ChainId chainId, address token, UFixed newStakingRate, UFixed oldStakingRate, Blocknumber lastUpdatedIn);
    event LogStakingStakingServiceSet(address stakingService, VersionPart release, address oldStakingService);
    event LogStakingStakingReaderSet(address stakingReader, address oldStakingReader);
    event LogStakingTokenHandlerApproved(address token, Amount approvalAmount, Amount oldApprovalAmount);

    address public tokenAddress;
    address public stakingStoreAddress;
    UFixed public tokenStakingRate;


    function setUp() public override {
        super.setUp();

        tokenAddress = address(token);
        stakingStoreAddress = address(staking.getStakingStore());

        // 10 dips per usdc
        tokenStakingRate = TargetManagerLib.calculateStakingRate(
            dip,
            token,
            UFixedLib.toUFixed(10)); // 10 dips required per usdc token
        
        vm.startPrank(stakingOwner);
        staking.addToken(ChainIdLib.current(), tokenAddress);
        staking.setStakingRate(ChainIdLib.current(), tokenAddress, tokenStakingRate);
        vm.stopPrank();
    }


    function test_stakingRateSetup() public view {

        // check token is what we think it is
        assertEq(token.symbol(), "USDC", "token symbol not USDC");
        assertEq(tokenAddress, address(token), "unexpected token address");

        // check instance is active target
        UFixed stakingRate = stakingReader.getTokenInfo(ChainIdLib.current(), tokenAddress).stakingRate;
        assertTrue(stakingRate.gtz(), "staking rate 0");
        assertTrue(stakingRate == tokenStakingRate, "unexpected token staking rate");
    }


    function test_stakingRateSetRateHappyCase() public {

        // GIVEN
        uint256 dipTokenPerToken = 7;

        // calculate new staking rate
        UFixed newStakingRate = TargetManagerLib.calculateStakingRate(
            dip,
            token,
            UFixedLib.toUFixed(dipTokenPerToken)); // required dip token per token

        assertTrue(newStakingRate.gtz(), "new staking rate 0");

        // WHEN
        ChainId currentChainId = ChainIdLib.current();
        Blocknumber currentBlock = BlocknumberLib.current();
        vm.expectEmit(address(staking));
        emit LogStakingStakingRateSet(
            currentChainId, 
            tokenAddress, 
            newStakingRate, // new staking rate
            tokenStakingRate, // old stakig rate
            currentBlock);

        vm.startPrank(stakingOwner);
        staking.setStakingRate(currentChainId, tokenAddress, newStakingRate);
        vm.stopPrank();

        // THEN
        UFixed stakingRateFromReader = stakingReader.getTokenInfo(ChainIdLib.current(), tokenAddress).stakingRate;
        assertTrue(stakingRateFromReader.gtz(), "staking rate (from reader) 0");
        assertTrue(stakingRateFromReader == newStakingRate, "unexpected token staking rate (from reader)");
    }


    function test_stakingRateCalculation10X() public {

        uint256 dipTokenPerToken = 10;

        // calculate staking rate
        UFixed stakingRate = TargetManagerLib.calculateStakingRate(
            dip,
            token,
            UFixedLib.toUFixed(dipTokenPerToken)); // required dip token per token

        assertTrue(stakingRate.gtz(), "staking rate 0");

        // define token amount
        uint256 tokenAmountInt = 42;
        Amount tokenAmount = AmountLib.toAmount(tokenAmountInt * 10 ** token.decimals());
        assertTrue(tokenAmount.gtz(), "token amount is 0");

        // define expected dip amount using staking rate
        uint256 expectedRequiredDipAmountInt = dipTokenPerToken * tokenAmountInt;
        Amount expectedRequiredDipAmount = AmountLib.toAmount(expectedRequiredDipAmountInt * 10 ** dip.decimals());
        assertTrue(expectedRequiredDipAmount.gtz(), "required expected dip amount is 0");

        // get required dip amount from library
        Amount requiredDipAmount = TargetManagerLib.calculateRequiredDipAmount(
            tokenAmount,
            stakingRate);

        // check
        assertEq(requiredDipAmount.toInt(), expectedRequiredDipAmount.toInt(), "unexpected required dip amount");
    }


    function test_stakingRateCalculationHalf() public {

        UFixed dipTokenPerToken = UFixedLib.toUFixed(5, -1);

        // calculate staking rate
        UFixed stakingRate = TargetManagerLib.calculateStakingRate(
            dip,
            token,
            dipTokenPerToken); // required dip token per token

        assertTrue(stakingRate.gtz(), "staking rate 0");

        // define token amount
        uint256 tokenAmountInt = 42;
        Amount tokenAmount = AmountLib.toAmount(tokenAmountInt * 10 ** token.decimals());
        assertTrue(tokenAmount.gtz(), "token amount is 0");

        // define expected dip amount using staking rate
        uint256 expectedRequiredDipAmountInt = tokenAmountInt / 2;
        Amount expectedRequiredDipAmount = AmountLib.toAmount(expectedRequiredDipAmountInt * 10 ** dip.decimals());
        assertTrue(expectedRequiredDipAmount.gtz(), "required expected dip amount is 0");

        // get required dip amount from library
        Amount requiredDipAmount = TargetManagerLib.calculateRequiredDipAmount(
            tokenAmount,
            stakingRate);

        // check
        assertEq(requiredDipAmount.toInt(), expectedRequiredDipAmount.toInt(), "unexpected required dip amount");
    }
}