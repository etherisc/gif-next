// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../../lib/forge-std/src/Test.sol";

import {IComponents} from "../../contracts/instance/module/IComponents.sol";
import {IInstance} from "../../contracts/instance/IInstance.sol";
import {INftOwnable} from "../../contracts/shared/INftOwnable.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {IStaking} from "../../contracts/staking/IStaking.sol";
import {IStakingService} from "../../contracts/staking/IStakingService.sol";

import {Amount, AmountLib} from "../../contracts/type/Amount.sol";
import {BlocknumberLib} from "../../contracts/type/Blocknumber.sol";
import {ChainId, ChainIdLib} from "../../contracts/type/ChainId.sol";
import {Fee, FeeLib} from "../../contracts/type/Fee.sol";
import {GifTest} from "../base/GifTest.sol";
import {NftId, NftIdLib} from "../../contracts/type/NftId.sol";
import {STAKE} from "../../contracts/type/ObjectType.sol";
import {ReferralId, ReferralLib} from "../../contracts/type/Referral.sol";
import {RiskId, RiskIdLib} from "../../contracts/type/RiskId.sol";
import {Seconds, SecondsLib} from "../../contracts/type/Seconds.sol";
import {StakingLib} from "../../contracts/staking/StakingLib.sol";
import {StakingStore} from "../../contracts/staking/StakingStore.sol";
import {TargetManagerLib} from "../../contracts/staking/TargetManagerLib.sol";
import {Timestamp, TimestampLib} from "../../contracts/type/Timestamp.sol";
import {TokenHandler} from "../../contracts/shared/TokenHandler.sol";
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

        _prepareProduct();
        _configureProduct(1000000 * 10 ** token.decimals());

        // fund customer
        vm.startPrank(registryOwner);
        token.transfer(customer, 100000 * 10 ** token.decimals());
        vm.stopPrank();

        // approve token handler
        vm.startPrank(customer);
        token.approve(
            address(product.getTokenHandler()),
            token.balanceOf(customer));
        vm.stopPrank();

        // set staking rate
        // for every usdc token 10 dip tokens must be staked
        chainId = ChainIdLib.current();
        stakingRate = UFixedLib.toUFixed(1, int8(dip.decimals() - token.decimals() + 1));

        vm.startPrank(stakingOwner);
        staking.setStakingRate(
            chainId, 
            address(token), 
            stakingRate);
        vm.stopPrank();

        // needs component service to be registered
        // can therefore only be called after service registration
        vm.startPrank(staking.getOwner());
        staking.approveTokenHandler(dip, AmountLib.max());
        vm.stopPrank();
    }


    function test_stakingRequiredStakingSetup() public {
        // check if staking rate is set correctly
        assertTrue(
            stakingReader.getTokenInfo(chainId, address(token)).stakingRate == stakingRate,
            "unexpected staking rate");

        console.log("required stakes (dip)", stakingReader.getRequiredStakeBalance(instanceNftId).toInt());
    }

    function _printRequiredStakes(string memory postfix) internal {
        console.log(
            "required dip stakes", 
            postfix, 
            stakingReader.getRequiredStakeBalance(instanceNftId).toInt()/10**18);
    }


    function test_stakingRequiredStakingConsole() public {

        Amount sumInsured = AmountLib.toAmount(100 * 10 ** token.decimals());

        _printRequiredStakes("(before)");
        NftId policyNftId1 = _createPolicy(sumInsured);
        _printRequiredStakes("(after 1 policy /w 100 usdc)");
        _closePolicy(policyNftId1);
        _printRequiredStakes("(after closing policy)");
    }


    function _closePolicy(NftId policyNftId) internal {
        _wait(policyLifetime);
        product.close(policyNftId);
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
