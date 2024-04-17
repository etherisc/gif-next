// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {console} from "../../lib/forge-std/src/Test.sol";

import {GifTest} from "../base/GifTest.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {IStaking} from "../../contracts/staking/IStaking.sol";
import {IStakingService} from "../../contracts/staking/IStakingService.sol";
import {ObjectType, SERVICE, STAKING} from "../../contracts/type/ObjectType.sol";
import {VersionPart} from "../../contracts/type/Version.sol";

contract Staking is GifTest {

    function test_stakingInfoToConsole() public {
        // solhint-disable
        console.log("staking address: ", address(staking));
        console.log("staking nft id: ", staking.getNftId().toInt());
        console.log("staking name: ", staking.getName());

        (VersionPart major, VersionPart minor, VersionPart patch) = staking.getVersion().toVersionParts();
        console.log("staking version (major): ", major.toInt());
        console.log("staking version (minor): ", minor.toInt());
        console.log("staking version (patch): ", patch.toInt());

        console.log("staking wallet: ", staking.getWallet());
        console.log("staking token handler: ", address(staking.getTokenHandler()));
        console.log("staking token handler token: ", address(staking.getTokenHandler().getToken()));

        console.log("staking token address: ", address(staking.getToken()));
        console.log("staking token symbol: ", staking.getToken().symbol());
        console.log("staking token decimals: ", staking.getToken().decimals());
        // solhint-enable
    }


    function test_stakingComponentSetup() public {
        (VersionPart major, VersionPart minor, VersionPart patch) = staking.getVersion().toVersionParts();
        assertEq(major.toInt(), 3, "unexpected staking major version");
        assertEq(minor.toInt(), 0, "unexpected staking minor version");
        assertEq(patch.toInt(), 0, "unexpected staking patch version");

        assertEq(staking.getWallet(), address(staking), "unexpected staking wallet");
        assertEq(address(staking.getToken()), address(dip), "unexpected staking token");
        assertEq(address(staking.getTokenHandler().getToken()), address(dip), "unexpected staking token handler token");
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

}