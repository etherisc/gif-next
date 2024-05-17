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


contract StakingSetupTest is GifTest {

    uint256 public constant STAKING_WALLET_APPROVAL = 5000;

    function test_stakingSetupConsoleInfo() public {
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


    function test_stakingSetupContracts() public {
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


    function test_stakingSetupVersionWalletAndToken() public {
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


    function test_stakingSetupInitialTarges() public {

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
}