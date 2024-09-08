// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../../lib/forge-std/src/Test.sol";

import {Amount, AmountLib} from "../../contracts/type/Amount.sol";
import {Blocknumber, BlocknumberLib} from "../../contracts/type/Blocknumber.sol";
import {ChainIdLib} from "../../contracts/type/ChainId.sol";
import {ClaimId} from "../../contracts/type/ClaimId.sol";
import {GifTest} from "../base/GifTest.sol";
import {NftId} from "../../contracts/type/NftId.sol";
import {PayoutId} from "../../contracts/type/PayoutId.sol";
import {ReferralLib} from "../../contracts/type/Referral.sol";
import {RiskId, RiskIdLib} from "../../contracts/type/RiskId.sol";
import {Seconds, SecondsLib} from "../../contracts/type/Seconds.sol";
import {StakingLib} from "../../contracts/staking/StakingLib.sol";
import {Timestamp, TimestampLib} from "../../contracts/type/Timestamp.sol";
import {UFixed, UFixedLib} from "../../contracts/type/UFixed.sol";import {VersionPart} from "../../contracts/type/Version.sol";


contract TvlCalculation is GifTest {

    // TODO find better ways than to copy paste events from StakingStore contract
    event LogStakingStoreTotalValueLockedIncreased(NftId targetNftId, address token, Amount amount, Amount newBalance, Blocknumber lastUpdatedIn);
    event LogStakingStoreTotalValueLockedDecreased(NftId targetNftId, address token, Amount amount, Amount newBalance, Blocknumber lastUpdatedIn);

    uint256 public constant BUNDLE_CAPITAL = 20000;
    uint256 public constant SUM_INSURED = 1000;
    uint256 public constant LIFETIME = 365 * 24 * 3600;
    uint256 public constant CUSTOMER_FUNDS = 5000;
    
    RiskId public riskId;
    NftId public policyNftId;
    address public tokenAddress;
    address public stakingStoreAddress;
    UFixed public stakingRate;


    function test_stakingTvlCalculationInitialState() public {

        // check instance is active target
        assertTrue(stakingReader.isTarget(instanceNftId), "instance not target");

        // check token is what we think it is
        assertEq(token.symbol(), "USDC", "token symbol not USDC");
        assertEq(tokenAddress, address(token), "unexpected token address");

        // check product and link to instance
        assertEq(address(product.getToken()), tokenAddress, "product token not USDC");
        assertEq(
            registry.getObjectInfo(product.getNftId()).parentNftId.toInt(), 
            instanceNftId.toInt(),
            "product parent not instance");

        // check initial total value locked
        assertEq(
            stakingReader.getTotalValueLocked(
                instanceNftId, 
                tokenAddress).toInt(), 
            0, 
            "initial instance tvl(usdc) not zero");

        // check initial required staking balance
        assertEq(
            stakingReader.getRequiredStakeBalance(instanceNftId).toInt(),
            0, 
            "initial instance required stake balance not zero");
    }


    function test_stakingTvlCalculationCreateSinglePolicy() public {

        // GIVEN
        uint256 sumInsuredAmountInt = 1000 * 10 ** token.decimals();
        Amount sumInsuredAmount = AmountLib.toAmount(sumInsuredAmountInt);

        // WHEN creating a new application
        policyNftId = _createApplication(
            customer,
            sumInsuredAmount, // sum insured
            SecondsLib.toSeconds(60)); // lifetime

        // THEN
        // check total value locked after application
        assertEq(
            stakingReader.getTotalValueLocked(
                instanceNftId, 
                tokenAddress).toInt(), 
            0, 
            "unexpected instance tvl(usdc) (before collateralization)");

        // check required staking balance after application
        assertEq(
            stakingReader.getRequiredStakeBalance(instanceNftId).toInt(),
            0, 
            "unexpected required stake balance (before collateralization)");

        // WHEN collateralizing the application
        // check tvl log entry from staking
        Blocknumber currentBlocknumber = BlocknumberLib.currentBlocknumber();
        Timestamp currentTimestamp = TimestampLib.current();
        vm.expectEmit(stakingStoreAddress);
        emit LogStakingStoreTotalValueLockedIncreased(
            instanceNftId, 
            tokenAddress, 
            sumInsuredAmount, // amount
            sumInsuredAmount, // new balance
            currentBlocknumber);

        // collateralize application
        _collateralize(policyNftId, false, currentTimestamp);

        // THEN
        // check total value locked after collateralizaion
        assertEq(
            stakingReader.getTotalValueLocked(
                instanceNftId, 
                tokenAddress).toInt(), 
            sumInsuredAmountInt, 
            "unexpected instance tvl(usdc) (after collateralization)");

        // check required staking balance after collateralizaion
        UFixed stakingRate = stakingReader.getTokenInfo(ChainIdLib.current(), tokenAddress).stakingRate;
        Amount expectedRequiredStakeBalance = sumInsuredAmount.multiplyWith(stakingRate);

        assertTrue(stakingRate.gtz(), "staking rate zero");
        assertTrue(expectedRequiredStakeBalance.gtz(), "required staking balance zero");
        assertEq(
            stakingReader.getRequiredStakeBalance(instanceNftId).toInt(),
            expectedRequiredStakeBalance.toInt(), 
            "unexpected required stake balance (after collateralization)");
    }


    function test_stakingTvlCalculationCreateAndCloseSinglePoliciy() public {

        // GIVEN
        uint256 sumInsuredAmountInt = 1000 * 10 ** token.decimals();
        Amount sumInsuredAmount = AmountLib.toAmount(sumInsuredAmountInt);

        // WHEN create a policy
        policyNftId = _createPolicy(customer, sumInsuredAmount);

        // THEN
        // check total value locked after policy creation
        assertEq(
            stakingReader.getTotalValueLocked(
                instanceNftId, 
                tokenAddress).toInt(), 
            sumInsuredAmountInt, 
            "unexpected instance tvl(usdc) (after policy creation)");

        // check required staking balance after policy creation
        UFixed stakingRate = stakingReader.getTokenInfo(ChainIdLib.current(), tokenAddress).stakingRate;
        Amount expectedRequiredStakeBalance = sumInsuredAmount.multiplyWith(stakingRate);

        assertTrue(stakingRate.gtz(), "staking rate zero");
        assertTrue(expectedRequiredStakeBalance.gtz(), "required staking balance zero");
        assertEq(
            stakingReader.getRequiredStakeBalance(instanceNftId).toInt(),
            expectedRequiredStakeBalance.toInt(), 
            "unexpected required stake balance (after policy creation)");

        // WHEN closing that policy
        // move to policy expiry timestamp
        Timestamp policyExpiryAt = instanceReader.getPolicyInfo(policyNftId).expiredAt;
        vm.warp(policyExpiryAt.toInt());

        // check tvl decrease log emission
        Blocknumber currentBlocknumber = BlocknumberLib.currentBlocknumber();
        Amount zeroAmount = AmountLib.zero();
        vm.expectEmit(stakingStoreAddress);
        emit LogStakingStoreTotalValueLockedDecreased(
            instanceNftId, 
            tokenAddress, 
            sumInsuredAmount, // amount
            zeroAmount, // new balance
            currentBlocknumber);

        _closePolicy(policyNftId);

        // THEN
        // check total value locked after policy closing
        assertEq(
            stakingReader.getTotalValueLocked(
                instanceNftId, 
                tokenAddress).toInt(), 
            0, 
            "unexpected instance tvl(usdc) (after policy closing)");

        // check required staking balance after policy closing
        assertEq(
            stakingReader.getRequiredStakeBalance(instanceNftId).toInt(),
            0, 
            "unexpected required stake balance (after policy closing)");
    }


    function test_stakingTvlCalculationCreateAndCloseMultiplePolicies() public {

        // GIVEN
        uint256 sumInsuredAmountInt = 1000 * 10 ** token.decimals();
        Amount sumInsuredAmount = AmountLib.toAmount(sumInsuredAmountInt);

        // WHEN creating 2 policies
        _createPolicy(customer, sumInsuredAmount);
        NftId policyNftId2 = _createPolicy(customer, sumInsuredAmount);

        // THEN
        // check total value locked after 2 policies
        assertEq(
            stakingReader.getTotalValueLocked(
                instanceNftId, 
                tokenAddress).toInt(), 
            2 * sumInsuredAmountInt, 
            "unexpected instance tvl(usdc) (after collateralization)");

        // check required staking balance 2 policies
        UFixed stakingRate = stakingReader.getTokenInfo(ChainIdLib.current(), tokenAddress).stakingRate;
        Amount expectedRequiredStakeBalance = sumInsuredAmount.multiplyWith(stakingRate);

        assertTrue(stakingRate.gtz(), "staking rate zero");
        assertTrue(expectedRequiredStakeBalance.gtz(), "required staking balance zero");
        assertEq(
            stakingReader.getRequiredStakeBalance(instanceNftId).toInt(),
            2 * expectedRequiredStakeBalance.toInt(), 
            "unexpected required stake balance (after collateralization)");

        // WHEN add a new policy
        _createPolicy(customer, sumInsuredAmount);

        // THEN
        // check total value locked after 3 policies
        assertEq(
            stakingReader.getTotalValueLocked(
                instanceNftId, 
                tokenAddress).toInt(), 
            3 * sumInsuredAmountInt, 
            "unexpected instance tvl(usdc) (after collateralization)");

        // check required staking balance 3 policies
        assertEq(
            stakingReader.getRequiredStakeBalance(instanceNftId).toInt(),
            3 * expectedRequiredStakeBalance.toInt(), 
            "unexpected required stake balance (after collateralization)");


        // WHEN close one of the 3 policies
        // move to policy expiry timestamp
        Timestamp policyExpiryAt = instanceReader.getPolicyInfo(policyNftId2).expiredAt;
        vm.warp(policyExpiryAt.toInt());

        _closePolicy(policyNftId2);

        // THEN
        // check total value locked after policy closing
        assertEq(
            stakingReader.getTotalValueLocked(
                instanceNftId, 
                tokenAddress).toInt(), 
            2 * sumInsuredAmountInt, 
            "unexpected instance tvl(usdc) (after closing 2nd policy)");

        // check required staking balance after policy closing
        assertEq(
            stakingReader.getRequiredStakeBalance(instanceNftId).toInt(),
            2 * expectedRequiredStakeBalance.toInt(), 
            "unexpected required stake balance (after closing 2nd policy)");

    }


    function test_stakingTvlCalculationCreatePoliciyAndCreatePayout() public {

        // GIVEN
        uint256 sumInsuredAmountInt = 1000 * 10 ** token.decimals();
        Amount sumInsuredAmount = AmountLib.toAmount(sumInsuredAmountInt);
        policyNftId = _createPolicy(customer, sumInsuredAmount);

        // WHEN create a claim/payout
        uint256 claimAmountInt = 399 * 10 ** token.decimals();
        Amount claimAmount = AmountLib.toAmount(claimAmountInt);
        ClaimId claimId = _createClaim(policyNftId, claimAmount);

        // only create payout don't process it
        PayoutId payoutId = _createPayout(policyNftId, claimId, claimAmount);

        // THEN
        assertEq(
            stakingReader.getTotalValueLocked(
                instanceNftId, 
                tokenAddress).toInt(), 
            sumInsuredAmountInt, 
            "unexpected instance tvl(usdc) (after payout creation)");

        // check required staking balance after policy closing
        UFixed stakingRate = stakingReader.getTokenInfo(ChainIdLib.current(), tokenAddress).stakingRate;
        Amount expectedRequiredStakeBalance = sumInsuredAmount.multiplyWith(stakingRate);
        assertEq(
            stakingReader.getRequiredStakeBalance(instanceNftId).toInt(),
            expectedRequiredStakeBalance.toInt(), 
            "unexpected required stake balance (after payout creation)");

        // WHEN processing the payout (includes actual payout token flow)
        Blocknumber currentBlocknumber = BlocknumberLib.currentBlocknumber();
        Amount newBalanceAmount = sumInsuredAmount - claimAmount;
        vm.expectEmit(stakingStoreAddress);
        emit LogStakingStoreTotalValueLockedDecreased(
            instanceNftId, 
            tokenAddress, 
            claimAmount, // amount
            newBalanceAmount, // new balance
            currentBlocknumber);

        product.processPayout(policyNftId, payoutId);

        // THEN
        assertEq(
            stakingReader.getTotalValueLocked(
                instanceNftId, 
                tokenAddress).toInt(), 
            sumInsuredAmountInt - claimAmountInt, 
            "unexpected instance tvl(usdc) (after payout processing)");

        // check required staking balance after policy closing
        expectedRequiredStakeBalance = (sumInsuredAmount - claimAmount).multiplyWith(stakingRate);
        assertEq(
            stakingReader.getRequiredStakeBalance(instanceNftId).toInt(),
            expectedRequiredStakeBalance.toInt(), 
            "unexpected required stake balance (after payout processing)");

    }

    function setUp() public override {
        super.setUp();

        _prepareProduct();  

        // create risk
        vm.startPrank(productOwner);
        riskId = product.createRisk("Risk_1", "");
        vm.stopPrank();

        // fund customer
        _fundAccount(customer, CUSTOMER_FUNDS * 10 ** token.decimals());

        tokenAddress = address(token);
        stakingStoreAddress = address(staking.getStakingStore());

        // for every usdc token 10 dip tokens must be staked
        stakingRate = UFixedLib.toUFixed(1, int8(dip.decimals() - token.decimals() + 1));

        vm.startPrank(stakingOwner);
        staking.setStakingRate(ChainIdLib.current(), tokenAddress, stakingRate);
        vm.stopPrank();
    }


    function _createPayout(
        NftId nftId, // policy nft id
        ClaimId claimId,
        Amount payoutAmount
    )
        internal
        returns (
            PayoutId payoutId
        )
    {
        payoutId = product.createPayout(
            nftId, 
            claimId, 
            payoutAmount, 
            ""); // payout data
    }


    function _createClaim(
        NftId nftId, // policy nft id
        Amount claimAmount
    )
        internal
        returns (
            ClaimId claimId
        )
    {
        claimId = product.submitClaim(nftId, claimAmount, "");
        product.confirmClaim(nftId, claimId, claimAmount, ""); 
    }


    function _closePolicy(
        NftId nftId
    )
        internal
    {
        vm.startPrank(productOwner);
        product.close(nftId); 
        vm.stopPrank();
    }


    function _createPolicy(
        address policyHolder,
        Amount sumInsuredAmount
    )
        internal
        returns (NftId plicyNftId)
    {
        Seconds lifetime = SecondsLib.toSeconds(LIFETIME);
        return _createPolicy(policyHolder, sumInsuredAmount, lifetime);
    }


    function _createPolicy(
        address policyHolder,
        Amount sumInsuredAmount,
        Seconds lifetime
    )
        internal
        returns (NftId plicyNftId)
    {
        plicyNftId = _createApplication(policyHolder, sumInsuredAmount, lifetime);
        _collateralize(plicyNftId, true, TimestampLib.current());
    }


    function _collateralize(
        NftId nftId,
        bool collectPremium, 
        Timestamp activateAt
    )
        internal
    {
        vm.startPrank(productOwner);
        product.createPolicy(nftId, collectPremium, activateAt); 
        vm.stopPrank();
    }


    function _createApplication(
        address policyHolder,
        Amount sumInsuredAmount,
        Seconds lifetime
    )
        internal
        returns (NftId)
    {
        return product.createApplication(
            policyHolder,
            riskId,
            sumInsuredAmount.toInt(),
            lifetime,
            "",
            bundleNftId,
            ReferralLib.zero());
    }


    function _fundAccount(
        address recipient, 
        uint256 amount
    )
        internal
    {
        vm.startPrank(registryOwner);
        token.transfer(customer, amount);
        vm.stopPrank();

        vm.startPrank(recipient);
        token.approve(address(product.getTokenHandler()), amount);
        vm.stopPrank();
    }


    function _third() internal pure returns (UFixed third) {
        uint256 many3 = 333333333333;
        third = UFixedLib.toUFixed(many3, -12);
    }

    function _times1000(UFixed value) internal pure returns (uint256) {
        return (UFixedLib.toUFixed(1000) * value).toInt();
    }

    function _times1e9(UFixed value) internal pure returns (uint256) {
        return (UFixedLib.toUFixed(1000000000) * value).toInt();
    }

}