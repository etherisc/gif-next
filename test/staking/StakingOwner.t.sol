// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {console} from "../../lib/forge-std/src/Test.sol";

import {IInstance} from "../../contracts/instance/IInstance.sol";
import {INftOwnable} from "../../contracts/shared/INftOwnable.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {IStaking} from "../../contracts/staking/IStaking.sol";
import {IStakingService} from "../../contracts/staking/IStakingService.sol";

import {Amount, AmountLib} from "../../contracts/type/Amount.sol";
import {BlocknumberLib} from "../../contracts/type/Blocknumber.sol";
import {ChainIdLib} from "../../contracts/type/ChainId.sol";
import {GifTest} from "../base/GifTest.sol";
import {NftId, NftIdLib} from "../../contracts/type/NftId.sol";
import {PROTOCOL, STAKE, STAKING} from "../../contracts/type/ObjectType.sol";
import {Seconds, SecondsLib} from "../../contracts/type/Seconds.sol";
import {StakingLib} from "../../contracts/staking/StakingLib.sol";
import {StakingReader} from "../../contracts/staking/StakingReader.sol";
import {StakingStore} from "../../contracts/staking/StakingStore.sol";
import {TargetManagerLib} from "../../contracts/staking/TargetManagerLib.sol";
import {Timestamp, TimestampLib} from "../../contracts/type/Timestamp.sol";
import {TokenHandler} from "../../contracts/shared/TokenHandler.sol";
import {UFixed, UFixedLib} from "../../contracts/type/UFixed.sol";


contract StakingOwnerTest is GifTest {

    uint256 public stakingNftIdInt;
    NftId public expectedStakingNftId;

    UFixed public protocolRewardRate = TargetManagerLib.getDefaultRewardRate();
    UFixed public newProtocolRewardRate = UFixedLib.toUFixed(75, -3);

    Seconds public protocolLockingPeriod = TargetManagerLib.getDefaultLockingPeriod();
    Seconds public newProtocolLockingPeriod = SecondsLib.fromDays(365);

    // 10 dip for 1 token
    uint256 dipTokenPerToken = 10;
    uint256 newDipTokenPerToken = 12;
    UFixed public tokenStakingRate = UFixedLib.toUFixed(dipTokenPerToken);
    UFixed public newTokenStakingRate = UFixedLib.toUFixed(newDipTokenPerToken);


    function setUp() public override {
        super.setUp();

        stakingNftIdInt = chainNft.calculateTokenId(registry.STAKING_TOKEN_SEQUENCE_ID(), block.chainid);
        expectedStakingNftId = NftIdLib.toNftId(stakingNftIdInt);
    }

    function test_stakingOwnerSetup() public {
        _printAuthz(registryAdmin, "registry setup");

        // solhint-disable
        console.log("staking seq", registry.STAKING_TOKEN_SEQUENCE_ID());
        console.log("chain id", ChainIdLib.current().toInt());
        console.log("staking id (expected)", chainNft.calculateTokenId(registry.STAKING_TOKEN_SEQUENCE_ID(), block.chainid));
        console.log("staking nft id (actual)", staking.getNftId().toInt());

        // check staking owner
        assertEq(stakingOwner, registryOwner, "staking owner not registry owner");
        assertTrue(stakingOwner != outsider, "staking owner not outsider");
        assertEq(staking.getOwner(), stakingOwner, "unexpected staking owner");

        // check staking NFT ID
        assertTrue(stakingNftId.gtz(), "staking NFT ID not set");
        assertEq(stakingNftId.toInt(), expectedStakingNftId.toInt(), "unexpected staking NFT ID");

        // check initial staking setup
        assertEq(stakingReader.targets(), 2, "unexpected initial staking targets");
        assertTrue(stakingReader.isTarget(registry.getProtocolNftId()), "protocol not target");
        assertTrue(stakingReader.isTarget(instanceNftId), "instance not target");

        console.log("initial staking targets", stakingReader.targets());
        IStaking.TargetInfo memory protocolTarget = stakingReader.getTargetInfo(registry.getProtocolNftId());
        console.log(
            "protocol target (lockingPeriod, rewardRate, maxStaking)", 
            protocolTarget.lockingPeriod.toInt(),
            (UFixedLib.toUFixed(1000) * protocolTarget.rewardRate).toInt(),
            protocolTarget.maxStakedAmount.toInt());

        assertEq(protocolTarget.objectType.toInt(), PROTOCOL().toInt(), "unexpected protocol object type");
        assertEq(protocolTarget.lockingPeriod.toInt(), TargetManagerLib.getDefaultLockingPeriod().toInt(), "unexpected protocol locking period");
        assertTrue(protocolTarget.rewardRate == TargetManagerLib.getDefaultRewardRate(), "unexpected protocol reward rate");
        assertEq(protocolTarget.maxStakedAmount.toInt(), AmountLib.max().toInt(), "unexpected protocol max staking amount");

        // check wallet is set to token handler (default)
        assertEq(staking.getWallet(), address(staking.getTokenHandler()), "unexpected staking wallet");
        // check token handler dip allowance is set to max
        assertEq(dip.allowance(staking.getWallet(), address(staking.getTokenHandler())), type(uint256).max, "unexpected allowance for staking token handler");
        // check token handler token allowance is set to 0
        assertEq(token.allowance(staking.getWallet(), address(staking.getTokenHandler())), 0, "unexpected allowance for staking token handler");

        assertTrue(newProtocolRewardRate > protocolRewardRate, "new protocol reward rate not greater than default protocol reward rate");
        assertTrue(protocolRewardRate > UFixedLib.zero(), "default protocol reward rate not greater than zero");
        assertTrue(newProtocolLockingPeriod > protocolLockingPeriod, "locking period not smaller than new locking period");
        assertTrue(newProtocolLockingPeriod > SecondsLib.zero(), "new locking period not greater than zero");

        // solhint-enable
    }

    /// @dev check that the staking owner can transfer the onwership of the staking contract
    /// to a new account that can then act as the staking owner.
    function test_stakingOwnerTransferOwnershipHappyCase() public {
        // GIVEN
        address newStakingOwner = makeAddr("newStakingOwner");
        assertTrue(newStakingOwner != stakingOwner, "new staking owner same as current staking owner");
        assertEq(staking.getOwner(), stakingOwner, "unexpected staking owner");

        // WHEN
        vm.startPrank(stakingOwner);
        chainNft.transferFrom(stakingOwner, newStakingOwner, stakingNftId.toInt());
        vm.stopPrank();

        // THEN
        assertEq(staking.getOwner(), newStakingOwner, "unexpected new staking owner");
        assertTrue(stakingReader.getRewardRate(registry.PROTOCOL_NFT_ID()) == protocolRewardRate, "protocol reward rate not default");

        // WHEN new owner sets protocol reward rate
        vm.startPrank(newStakingOwner);
        staking.setProtocolRewardRate(newProtocolRewardRate);
        vm.stopPrank();

        // THEN check protocol reward rate is updated
        assertTrue(stakingReader.getRewardRate(registry.PROTOCOL_NFT_ID()) == newProtocolRewardRate, "protocol reward rate not updated");
    }


    /// @dev check that an ousider cannot transfer ownership of the 
    /// staking contract to another acccount.
    function test_stakingOwnerTransferOwnershipNotOwner() public {
        // GIVEN
        address newStakingOwner = makeAddr("newStakingOwner");
        assertTrue(newStakingOwner != stakingOwner, "new staking owner same as current staking owner");
        assertEq(staking.getOwner(), stakingOwner, "unexpected staking owner");

        uint256 stakingNftIdInt = staking.getNftId().toInt();

        // WHEN + THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC721Errors.ERC721InsufficientApproval.selector,
                newStakingOwner, 
                stakingNftIdInt));

        vm.startPrank(newStakingOwner);
        chainNft.transferFrom(stakingOwner, newStakingOwner, stakingNftIdInt);
        vm.stopPrank();
    }


    /// @dev Check that the staking owner can set the protocol locking period.
    function test_stakingOwnerSetProtocolLockingPeriodHappyCase() public {
        // GIVEN
        assertEq(stakingReader.getLockingPeriod(registry.getProtocolNftId()).toInt(), protocolLockingPeriod.toInt(), "unexpected initial protocol locking period");
        assertTrue(newProtocolLockingPeriod > protocolLockingPeriod, "new locking period not greater than default locking period");

        // WHEN
        vm.expectEmit(address(staking));
        emit IStaking.LogStakingProtocolLockingPeriodSet(
            registry.getProtocolNftId(),
            newProtocolLockingPeriod,
            protocolLockingPeriod,
            BlocknumberLib.current());

        vm.startPrank(stakingOwner);
        staking.setProtocolLockingPeriod(newProtocolLockingPeriod);

        // THEN
        assertEq(stakingReader.getLockingPeriod(registry.getProtocolNftId()).toInt(), newProtocolLockingPeriod.toInt(), "unexpected new protocol locking period");
    }


    /// @dev Check that the staking owner can set the protocol reward rate.
    function test_stakingOwnerSetProtocolRewardRateHappyCase() public {
        // GIVEN
        assertTrue(stakingReader.getRewardRate(registry.getProtocolNftId()) == protocolRewardRate, "unexpected initial protocol reward rate");
        assertTrue(newProtocolRewardRate > protocolRewardRate, "new reward rate not greater than default reward rate");

        // WHEN
        vm.expectEmit(address(staking));
        emit IStaking.LogStakingProtocolRewardRateSet(
            registry.getProtocolNftId(),
            newProtocolRewardRate,
            protocolRewardRate,
            BlocknumberLib.current());

        vm.startPrank(stakingOwner);
        staking.setProtocolRewardRate(newProtocolRewardRate);

        // THEN
        assertTrue(stakingReader.getRewardRate(registry.getProtocolNftId()) == newProtocolRewardRate, "unexpected new protocol reward rate");
    }


    function test_stakingOwnerApproveTokenHandlerHappyCase() public {
    }

    function test_stakingOwnerApproveTokenHandlerStakingLocked() public {
    }


    /// @dev check that all staking functions reserved for the staking owner
    /// are blocking unauthorized access.
    function test_stakingOwnerNotOwner() public {
        // GIVEN
        vm.startPrank(outsider);

        // WHEN + THEN attempt to set protocol locking period
        vm.expectRevert(
            abi.encodeWithSelector(
                INftOwnable.ErrorNftOwnableNotOwner.selector, outsider));

        staking.setProtocolLockingPeriod(newProtocolLockingPeriod);

        // WHEN + THEN attempt to set protocol reward rate
        vm.expectRevert(
            abi.encodeWithSelector(
                INftOwnable.ErrorNftOwnableNotOwner.selector, outsider));

        staking.setProtocolRewardRate(newProtocolRewardRate);

        // WHEN + THEN attempt to set staking rate
        vm.expectRevert(
            abi.encodeWithSelector(
                INftOwnable.ErrorNftOwnableNotOwner.selector, outsider));

        staking.setStakingRate(ChainIdLib.current(), address(token), newTokenStakingRate);

        // WHEN + THEN attempt to set staking reader
        StakingReader newStakingReader = new StakingReader(registry);
        vm.expectRevert(
            abi.encodeWithSelector(
                INftOwnable.ErrorNftOwnableNotOwner.selector, outsider));

        staking.setStakingReader(newStakingReader);

        // WHEN + THEN attempt to approve token handler
        Amount newApproveAmount = AmountLib.toAmount(100);
        vm.expectRevert(
            abi.encodeWithSelector(
                INftOwnable.ErrorNftOwnableNotOwner.selector, outsider));

        staking.approveTokenHandler(token, newApproveAmount);

        vm.stopPrank();
    }
}