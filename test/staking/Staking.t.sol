// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {console} from "../../lib/forge-std/src/Test.sol";

import {Amount, AmountLib} from "../../contracts/type/Amount.sol";
import {GifTest} from "../base/GifTest.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {IStaking} from "../../contracts/staking/IStaking.sol";
import {IStakingService} from "../../contracts/staking/IStakingService.sol";
import {NftId} from "../../contracts/type/NftId.sol";
import {ObjectType, INSTANCE, PROTOCOL, SERVICE, STAKE, STAKING} from "../../contracts/type/ObjectType.sol";
import {Seconds, SecondsLib} from "../../contracts/type/Seconds.sol";
import {StakeManagerLib} from "../../contracts/staking/StakeManagerLib.sol";
import {TargetManagerLib} from "../../contracts/staking/TargetManagerLib.sol";
import {Timestamp, TimestampLib} from "../../contracts/type/Timestamp.sol";
import {TokenHandler} from "../../contracts/shared/TokenHandler.sol";
import {UFixed, UFixedLib} from "../../contracts/type/UFixed.sol";
import {VersionPart} from "../../contracts/type/Version.sol";


contract Staking is GifTest {

    function test_stakingInfoToConsole() public {
        // solhint-disable
        console.log("staking address:", address(staking));
        console.log("staking nft id:", staking.getNftId().toInt());
        console.log("staking name:", staking.getName());

        console.log("staking reader:", address(stakingReader));
        console.log("staking reader address (via staking):", address(staking.getStakingReader()));
        console.log("staking address (via reader):", address(stakingReader.getStaking()));

        (VersionPart major, VersionPart minor, VersionPart patch) = staking.getVersion().toVersionParts();
        console.log("staking version (major):", major.toInt());
        console.log("staking version (minor):", minor.toInt());
        console.log("staking version (patch):", patch.toInt());

        console.log("staking wallet:", staking.getWallet());
        console.log("staking token handler:", address(staking.getTokenHandler()));
        console.log("staking token handler token:", address(staking.getTokenHandler().getToken()));

        console.log("staking token address:", address(staking.getToken()));
        console.log("staking token symbol:", staking.getToken().symbol());
        console.log("staking token decimals:", staking.getToken().decimals());

        console.log("staking targets:", stakingReader.targets());
        console.log("staking target nft [0]:", stakingReader.getTargetNftId(0).toInt());
        console.log("staking targets (active):", stakingReader.activeTargets());
        console.log("staking target nft (active) [0]:", stakingReader.getActiveTargetNftId(0).toInt());
        // solhint-enable
    }


    function test_stakingVersionWalletAndTokenSetup() public {
        // check link to registry
        assertEq(address(staking.getRegistry()), address(registry), "unexpected registry address");

        // check link to registry
        assertEq(staking.getTokenRegistryAddress(), registry.getTokenRegistryAddress(), "unexpected token registry address");

        // check version
        (VersionPart major, VersionPart minor, VersionPart patch) = staking.getVersion().toVersionParts();
        assertEq(major.toInt(), 3, "unexpected staking major version");
        assertEq(minor.toInt(), 0, "unexpected staking minor version");
        assertEq(patch.toInt(), 0, "unexpected staking patch version");

        // check wallet and (dip) token handler
        assertEq(staking.getWallet(), address(staking), "unexpected staking wallet");
        assertEq(address(staking.getToken()), address(dip), "unexpected staking token");
        assertEq(address(staking.getTokenHandler().getToken()), address(dip), "unexpected staking token handler token");
    }


    function test_stakingInitialTargetSetup() public {
        // check protocol target
        uint256 protocolNftIdInt = 1101;
        assertEq(stakingReader.targets(), 2, "unexpected number of initial targets");
        assertEq(stakingReader.activeTargets(), 2, "unexpected number of initial active targets");
        assertEq(stakingReader.getTargetNftId(0).toInt(), protocolNftIdInt, "unexpected protocol nft id (all)");
        assertEq(stakingReader.getActiveTargetNftId(0).toInt(), protocolNftIdInt, "unexpected protocol nft id (active)");

        // check protocol target
        NftId protocolNftId = stakingReader.getTargetNftId(0);
        assertTrue(stakingReader.isTarget(protocolNftId), "protocol not target");
        assertTrue(stakingReader.isActive(protocolNftId), "protocol target not active");

        IStaking.TargetInfo memory targetInfo = stakingReader.getTargetInfo(protocolNftId);
        assertEq(targetInfo.objectType.toInt(), PROTOCOL().toInt(), "unexpected protocol object type");
        assertEq(targetInfo.chainId, 1, "unexpected protocol chain id");
        assertEq(targetInfo.lockingPeriod.toInt(), TargetManagerLib.getDefaultLockingPeriod().toInt(), "unexpected locking period");

        // check instance target
        assertEq(stakingReader.getTargetNftId(1).toInt(), instanceNftId.toInt(), "unexpected instance nft id (all)");
        assertEq(stakingReader.getActiveTargetNftId(1).toInt(), instanceNftId.toInt(), "unexpected instance nft id (active)");
        assertTrue(stakingReader.isTarget(instanceNftId), "instance not target");
        assertTrue(stakingReader.isActive(instanceNftId), "instance target not active");

        IStaking.TargetInfo memory instanceTargetInfo = stakingReader.getTargetInfo(instanceNftId);
        assertEq(instanceTargetInfo.objectType.toInt(), INSTANCE().toInt(), "unexpected instance object type");
        assertEq(instanceTargetInfo.chainId, block.chainid, "unexpected instance chain id");
        assertEq(instanceTargetInfo.lockingPeriod.toInt(), TargetManagerLib.getDefaultLockingPeriod().toInt(), "unexpected locking period");
    }


    function test_stakingSetup() public {
        // staking manager
        assertEq(stakingManager.getOwner(), staking.getOwner(), "unexpected staking manager owner");
        assertEq(address(stakingManager.getStaking()), address(staking), "unexpected staking address");

        // staking
        assertTrue(staking.supportsInterface(type(IStaking).interfaceId), "not supportint expected interface");
        assertTrue(registry.getNftId(address(staking)).gtz(), "staking nft id zero");
        assertEq(staking.getNftId().toInt(), stakingNftId.toInt(), "unexpected staking nft id (1)");
        assertEq(staking.getNftId().toInt(), registry.getNftId(address(staking)).toInt(), "unexpected staking nft id (2)");

        // staking registry entry
        IRegistry.ObjectInfo memory stakingInfo = registry.getObjectInfo(staking.getNftId());
        assertEq(stakingInfo.nftId.toInt(), stakingNftId.toInt(), "unexpected staking nft id (3)");
        assertEq(stakingInfo.parentNftId.toInt(), registryNftId.toInt(), "unexpected parent nft id");
        assertEq(stakingInfo.objectType.toInt(), STAKING().toInt(), "unexpected object type");
        assertFalse(stakingInfo.isInterceptor, "staking should not be interceptor");
        assertEq(stakingInfo.objectAddress, address(staking), "unexpected contract address");
        assertEq(stakingInfo.initialOwner, registryOwner, "unexpected initial owner");

        // staking service manager
        assertEq(stakingServiceManager.getOwner(), stakingService.getOwner(), "unexpected staking service manager owner");
        assertEq(address(stakingServiceManager.getStakingService()), address(stakingService), "unexpected staking service address");

        // staking service
        assertTrue(stakingService.supportsInterface(type(IStakingService).interfaceId), "not supportint expected interface");
        assertTrue(registry.getNftId(address(stakingService)).gtz(), "staking service nft id zero");
        assertEq(stakingService.getNftId().toInt(), stakingServiceNftId.toInt(), "unexpected staking service nft id (1)");
        assertEq(stakingService.getNftId().toInt(), registry.getNftId(address(stakingService)).toInt(), "unexpected staking service nft id (2)");

        IRegistry.ObjectInfo memory serviceInfo = registry.getObjectInfo(stakingService.getNftId());
        assertEq(serviceInfo.nftId.toInt(), stakingServiceNftId.toInt(), "unexpected staking service nft id (3)");
        assertEq(serviceInfo.parentNftId.toInt(), registryNftId.toInt(), "unexpected parent nft id");
        assertEq(serviceInfo.objectType.toInt(), SERVICE().toInt(), "unexpected object type");
        assertFalse(serviceInfo.isInterceptor, "staking service should not be interceptor");
        assertEq(serviceInfo.objectAddress, address(stakingService), "unexpected contract address");
        assertEq(serviceInfo.initialOwner, registryOwner, "unexpected initial owner");
    }


    function test_stakingCreateProtocolStake() public {

        NftId protocolNftId = stakingReader.getTargetNftId(0);
        (TokenHandler tokenHandler, Amount dipAmount) = _prepareStaker(staker, 5000);

        // check balances before staking
        assertTrue(staker != staking.getWallet(), "staker and staking wallet the same");
        assertEq(dip.balanceOf(staker), dipAmount.toInt(), "staker: unexpected dip balance");
        assertEq(dip.balanceOf(staking.getWallet()), 0, "staking wallet: unexpected dip balance");

        vm.startPrank(staker);

        // create stake
        NftId stakeNftId = stakingService.create(
            protocolNftId, 
            dipAmount);

        vm.stopPrank();

        // check balances after staking
        assertEq(dip.balanceOf(staker), 0, "staker: unexpected dip balance (after staking)");
        assertEq(dip.balanceOf(staking.getWallet()), dipAmount.toInt(), "staking wallet: unexpected dip balance (after staking)");

        // check ownership
        assertTrue(stakeNftId.gtz(), "stake nft id zero");
        assertEq(registry.ownerOf(stakeNftId), staker, "unexpected stake nft owner");
        
        // check object info (registry entry)
        IRegistry.ObjectInfo memory objectInfo = registry.getObjectInfo(stakeNftId);
        assertEq(objectInfo.nftId.toInt(), stakeNftId.toInt(), "unexpected stake nft id");
        assertEq(objectInfo.parentNftId.toInt(), protocolNftId.toInt(), "unexpected parent nft id");
        assertEq(objectInfo.objectType.toInt(), STAKE().toInt(), "unexpected object type");
        assertFalse(objectInfo.isInterceptor, "stake as interceptor");
        assertEq(objectInfo.objectAddress, address(0), "stake object address non zero");
        assertEq(objectInfo.initialOwner, staker, "unexpected initial stake owner");
        assertEq(bytes(objectInfo.data).length, 0, "unexpected data size");

        Seconds lockingPeriod = stakingReader.getTargetInfo(protocolNftId).lockingPeriod;
        assertEq(lockingPeriod.toInt(), TargetManagerLib.getDefaultLockingPeriod().toInt(), "unexpected locking period");

        // check stake balance
        assertEq(stakingReader.getStakeBalance(stakeNftId).toInt(), dipAmount.toInt(), "unexpected stake amount");
        assertEq(stakingReader.getRewardBalance(stakeNftId).toInt(), 0, "unexpected reward amount");
        assertEq(stakingReader.getBalanceUpdatedAt(stakeNftId).toInt(), block.timestamp, "unexpected last updated at");

        // check state info
        IStaking.StakeInfo memory stakeInfo = stakingReader.getStakeInfo(stakeNftId);
        assertTrue(stakeInfo.lockedUntil.gtz(), "locked until zero");
        assertEq(stakeInfo.lockedUntil.toInt(), TimestampLib.blockTimestamp().toInt() + lockingPeriod.toInt(), "unexpected locked until");
    }


    function test_stakingCreateInstanceStake() public {

        (TokenHandler tokenHandler, Amount dipAmount) = _prepareStaker(staker2, 3000);

        // check balances after staking
        assertEq(dip.balanceOf(staker2), dipAmount.toInt(), "staker2: unexpected dip balance (before staking)");
        assertEq(dip.balanceOf(staking.getWallet()), 0, "staking wallet: unexpected dip balance (before staking)");

        vm.startPrank(staker2);

        // create instance stake
        NftId stakeNftId = stakingService.create(
            instanceNftId, 
            dipAmount);

        vm.stopPrank();

        // check balances after staking
        assertEq(dip.balanceOf(staker2), 0, "staker: unexpected dip balance (after staking)");
        assertEq(dip.balanceOf(staking.getWallet()), dipAmount.toInt(), "staking wallet: unexpected dip balance (after staking)");

        // check ownership
        assertTrue(stakeNftId.gtz(), "stake nft id zero");
        assertEq(registry.ownerOf(stakeNftId), staker2, "unexpected stake nft owner");
        
        // check object info (registry entry)
        IRegistry.ObjectInfo memory objectInfo = registry.getObjectInfo(stakeNftId);
        assertEq(objectInfo.nftId.toInt(), stakeNftId.toInt(), "unexpected stake nft id");
        assertEq(objectInfo.parentNftId.toInt(), instanceNftId.toInt(), "unexpected parent nft id");
        assertEq(objectInfo.objectType.toInt(), STAKE().toInt(), "unexpected object type");
        assertFalse(objectInfo.isInterceptor, "stake as interceptor");
        assertEq(objectInfo.objectAddress, address(0), "stake object address non zero");
        assertEq(objectInfo.initialOwner, staker2, "unexpected initial stake owner");
        assertEq(bytes(objectInfo.data).length, 0, "unexpected data size");

        Seconds lockingPeriod = stakingReader.getTargetInfo(instanceNftId).lockingPeriod;
        assertEq(lockingPeriod.toInt(), TargetManagerLib.getDefaultLockingPeriod().toInt(), "unexpected locking period");

        // check stake balance
        assertEq(stakingReader.getStakeBalance(stakeNftId).toInt(), dipAmount.toInt(), "unexpected stake amount");
        assertEq(stakingReader.getRewardBalance(stakeNftId).toInt(), 0, "unexpected reward amount");
        assertEq(stakingReader.getBalanceUpdatedAt(stakeNftId).toInt(), block.timestamp, "unexpected last updated at");

        // check state info
        IStaking.StakeInfo memory stakeInfo = stakingReader.getStakeInfo(stakeNftId);
        assertTrue(stakeInfo.lockedUntil.gtz(), "locked until zero");
        assertEq(stakeInfo.lockedUntil.toInt(), TimestampLib.blockTimestamp().toInt() + lockingPeriod.toInt(), "unexpected locked until");
    }


    function test_stakingSetLockingPeriodHappyCase() public {
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


    function test_stakingSetLockingPeriodNotTargetOwner() public {
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


    function test_stakingSetRewardRateHappyCase() public {
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


    function test_stakingSetRewardRateNotTargetOwner() public {
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

    function test_stakingUpdateRewardsAfterOneYear() public {

        (
            TokenHandler tokenHandler,
            Amount dipAmount,
            NftId stakeNftId
        ) = _prepareStake(staker, instanceNftId, 1000);

        // record time at stake creation
        uint256 lastUpdateAt = block.timestamp;

        // wait a year
        _wait(SecondsLib.oneYear());

        // check one year passed
        assertEq(block.timestamp - SecondsLib.oneYear().toInt(), lastUpdateAt, "unexpected year duration");

        // check reward calculations after one year
        UFixed rewardRate = stakingReader.getTargetInfo(instanceNftId).rewardRate;
        Amount rewardIncrease = StakeManagerLib.calculateRewardIncrease(
            stakingReader,
            stakeNftId);
        
        Amount expectedRewardIncrease = StakeManagerLib.calculateRewardAmount(
            rewardRate,
            SecondsLib.oneYear(),
            dipAmount);

        assertEq(expectedRewardIncrease.toInt(), 50 * 10**dip.decimals(), "unexpected 'expected' reward increase");
        assertTrue(rewardIncrease.gtz(), "reward increase zero");
        assertEq(rewardIncrease.toInt(), expectedRewardIncrease.toInt(), "unexpected rewared increase");

        // check stake/rewards balance (before calling update rewards)
        assertEq(stakingReader.getStakeBalance(stakeNftId).toInt(), dipAmount.toInt(), "unexpected stake amount (before)");
        assertEq(stakingReader.getRewardBalance(stakeNftId).toInt(), 0, "unexpected reward amount (before)");
        assertEq(stakingReader.getBalanceUpdatedAt(stakeNftId).toInt(), lastUpdateAt, "unexpected last updated at (before)");

        // update rewards (unpermissioned)
        stakingService.updateRewards(stakeNftId);

        // check stake/rewards balance (after calling update rewards)
        uint256 lastUpdateNow = block.timestamp;
        assertEq(stakingReader.getStakeBalance(stakeNftId).toInt(), dipAmount.toInt(), "unexpected stake amount (after)");
        assertEq(stakingReader.getRewardBalance(stakeNftId).toInt(), expectedRewardIncrease.toInt(), "unexpected reward amount (after)");
        assertEq(stakingReader.getBalanceUpdatedAt(stakeNftId).toInt(), block.timestamp, "unexpected last updated at (after)");
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
        (tokenHandler, dipAmount) = _prepareStaker(myStaker, myStakeAmount);

        vm.startPrank(myStaker);
        stakeNftId = stakingService.create(
            myTargetNftId, 
            dipAmount);
        vm.stopPrank();
    }


    function _prepareStaker(
        address myStaker, 
        uint256 myStakeAmount
    )
        internal
        returns(
            TokenHandler tokenHandler,
            Amount dipAmount
        )
    {
        return _prepareStaker(myStaker, myStakeAmount, true, true);
    }


    function _prepareStaker(
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
        TokenHandler tokenHandler = stakingService.getTokenHandler();
        dipAmount = AmountLib.toAmount(myStakeAmount * 10**dip.decimals());

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


    function _wait(Seconds secondsToWait) internal {
        vm.warp(block.timestamp + secondsToWait.toInt());
    }

}