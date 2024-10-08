// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol"; 
import {Test, console} from "../../lib/forge-std/src/Test.sol";

import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {IVersionable} from "../../contracts/upgradeability/IVersionable.sol";

import {ChainNft} from "../../contracts/registry/ChainNft.sol";
import {Dip} from "../../contracts/mock/Dip.sol";
import {NftId, NftIdLib} from "../../contracts/type/NftId.sol";
import {INftOwnable} from "../../contracts/shared/INftOwnable.sol";
import {ProxyManager} from "../../contracts/upgradeability/ProxyManager.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {RegistryServiceManager} from "../../contracts/registry/RegistryServiceManager.sol";
import {RegistryAdmin} from "../../contracts/registry/RegistryAdmin.sol";
import {RegistryService} from "../../contracts/registry/RegistryService.sol";
import {Staking} from "../../contracts/staking/Staking.sol";
import {StakingManager} from "../../contracts/staking/StakingManager.sol";
import {TokenRegistry} from "../../contracts/registry/TokenRegistry.sol";
import {RegistryServiceMock} from "../mock/RegistryServiceMock.sol";
import {RegistryServiceUpgradeMock} from "../mock/RegistryServiceUpgradeMock.sol";
import {Version, VersionLib, VersionPartLib } from "../../contracts/type/Version.sol";
import {RegistryServiceTestBase} from "./RegistryServiceTestBase.sol";

contract RegistryServiceManagerTest is RegistryServiceTestBase {

    address public registryOwnerNew = makeAddr("registryOwnerNew");

    // function setUp() public virtual override {

    //     vm.startPrank(registryOwner);

    //     _deployRegistry();

    //     _deployRegistryService();

    //     // deploy staking contract
    //     address stakingOwner = registryOwner;
    //     stakingManager = new StakingManager(
    //         registryAccessManager.authority(),
    //         address(registry));
    //     staking = stakingManager.getStaking();

    //     vm.stopPrank();
    // }

    function test_deployedRegistryAndRegistryService() public {

        // solhint-disable no-console
        console.log("registry owner", address(registryOwner));
        console.log("registry service manager", address(registryServiceManager));
        console.log("registry service manager linked to nft", registryServiceManager.getNftId().toInt());
        console.log("registry service manager owner", registryServiceManager.getOwner());
        console.log("registry service", address(registryService));
        console.log("registry service nft", registryService.getNftId().toInt());
        console.log("registry service owner", registryService.getOwner());
        console.log("registry service authority", registryService.authority());
        console.log("registry", address(registry));
        console.log("registry nft", registry.getNftIdForAddress(address(registry)).toInt());
        console.log("registry owner (opt 1)", registry.ownerOf(address(registry)));
        console.log("registry owner (opt 2)", registry.getOwner());
        // solhint-enable

        console.log("registered objects", registry.getObjectCount());
        _logObject("protocol", NftIdLib.toNftId(1101));
        _logObject("globalRegistry", NftIdLib.toNftId(2101));
        _logObject("chainRegistry", address(registry));
        _logObject("registryService", address(registryService));

        // check for zero addresses
        assertTrue(address(registryServiceManager) != address(0), "registry installer zero");
        assertTrue(address(registryService) != address(0), "registry service zero");
        assertTrue(address(registry) != address(0), "registry zero");
        assertTrue(address(chainNft) != address(0), "chain nft zero");

        // check contract links
        assertEq(address(registryService.getRegistry()), address(registry), "unexpected registry address");
        assertEq(registry.getChainNftAddress(), address(chainNft), "unexpected chain nft address");

        // check nft ids
        assertTrue(registry.getNftIdForAddress(address(registryService)).gtz(), "registry service nft id (option 1) zero");
        assertTrue(registryService.getNftId().gtz(), "registry service nft id (option 2) zero");
        assertEq(registryService.getNftId().toInt(), registry.getNftIdForAddress(address(registryService)).toInt(), "registry service nft id mismatch");
        
        // check ownership
        assertEq(registryServiceManager.getOwner(), address(registryOwner), "service manager owner not registry owner");
        assertEq(registryService.getOwner(), address(registryOwner), "registry owner not owner of registry");
        assertEq(registry.getOwner(), address(0x1), "registry owner not owner of registry");
        assertEq(registry.getOwner(), registry.ownerOf(address(registry)), "non matching registry owners");

        // check registered objects
        assertTrue(registry.isRegistered(address(registry)), "registry itself not registered");
        assertTrue(registry.isRegistered(address(registryService)), "registry service not registered");
    }

    function test_attemptsToRedeployedRegistryServiceNotOwner() public {
        address mockImplementation = address(new RegistryServiceMock());
        bytes memory emptyInitializationData;

        // check ownership
        assertEq(registryServiceManager.getOwner(), address(registryOwner), "service manager owner not registry owner");

        // attempt to redeploy with non-owner account
        vm.expectRevert(
            abi.encodeWithSelector(
                Initializable.InvalidInitialization.selector));

        vm.prank(registryOwnerNew);
        registryServiceManager.initialize(
            address(registry),
            mockImplementation,
            emptyInitializationData,
            bytes32(""));
    }

    function test_attemptsToRedeployedRegistryServiceOwner() public {
        address mockImplementation = address(new RegistryServiceMock());
        bytes memory emptyInitializationData;

        // check ownership
        assertEq(registryServiceManager.getOwner(), address(registryOwner), "service manager owner not registry owner");

        // attempt to redeploy with owner account
        vm.expectRevert(
            abi.encodeWithSelector(
                Initializable.InvalidInitialization.selector));

        vm.prank(registryOwner);
        registryServiceManager.initialize(
            address(registry),
            mockImplementation,
            emptyInitializationData,
            bytes32(""));
    }

    function test_attemptsToUpgradeRegistryService() public {
        address upgradeMockImplementation = address(new RegistryServiceUpgradeMock());
        bytes memory emptyUpgradeData;

        // check ownership
        assertEq(registryServiceManager.getOwner(), address(registryOwner), "service manager owner not registry owner");

        // attempt to upgrade with non-owner account
        vm.expectRevert(
            abi.encodeWithSelector(
                INftOwnable.ErrorNftOwnableNotOwner.selector,
                registryOwnerNew));
        vm.prank(registryOwnerNew);
        registryServiceManager.upgrade(
            upgradeMockImplementation,
            emptyUpgradeData);

        assertEq(registryService.getVersion().toInt(), VersionLib.toVersion(3, 0, 0).toInt(), "unexpected registry service before upgrad");
        assertEq(registryServiceManager.getVersionCount(), 1, "version count not 1 before upgrade");

        // attempt to upgrade with owner account
        vm.prank(registryOwner);
        registryServiceManager.upgrade(
            upgradeMockImplementation,
            emptyUpgradeData);

        RegistryServiceUpgradeMock registryServiceUpgraded = RegistryServiceUpgradeMock(
            address(registryService));

        assertEq(registryServiceUpgraded.getVersion().toInt(), VersionLib.toVersion(3, 0, 1).toInt(), "unexpected registry service after upgrad");
        assertEq(registryServiceManager.getVersionCount(), 2, "version count not 2 after upgrade");

        assertEq(registryServiceUpgraded.getMessage(), "hi from upgrade mock", "unexpected message from upgraded registry service");
    }

// TODO refactor
/*
    function test_transferAndUpgradeRegistryService() public {
        address upgradeMockImplementation = address(new RegistryServiceUpgradeMock());
        address registryServiceAddress = address(registryService);
        bytes memory emptyUpgradeData;

        // check initial ownership
        assertEq(registry.ownerOf(registryServiceAddress), registryOwner, "registry service owner not registry owner");
        assertEq(registryServiceManager.getOwner(), registryOwner, "registry service manager owner not registry owner");

        // transfer ownership by transferring nft
        NftId registryServiceNft = registry.getNftIdForAddress(registryServiceAddress);

        vm.startPrank(registryOwner);
        chainNft.approve(registryOwnerNew, registryServiceNft.toInt());
        chainNft.safeTransferFrom(registryOwner, registryOwnerNew, registryServiceNft.toInt(), "");
        vm.stopPrank();

        // check ownership after transfer
        assertEq(registry.ownerOf(registryServiceAddress), registryOwnerNew, "registry service owner not registry owner");
        assertEq(registryServiceManager.getOwner(), registryOwnerNew, "registry service manager owner not registry owner");

        // attempt to upgrade with old owner
        vm.expectRevert(
            abi.encodeWithSelector(
                INftOwnable.ErrorNotOwner.selector,
                registryOwner));
        vm.prank(registryOwner);
        registryServiceManager.upgrade(
            upgradeMockImplementation,
            emptyUpgradeData);

        // attempt to upgrade with new owner
        vm.prank(registryOwnerNew);
        registryServiceManager.upgrade(
            upgradeMockImplementation,
            emptyUpgradeData);

        RegistryServiceUpgradeMock registryServiceUpgraded = RegistryServiceUpgradeMock(
            address(registryService));

        assertEq(registryServiceUpgraded.getVersion().toInt(), VersionLib.toVersion(3, 0, 1).toInt(), "unexpected registry service after upgrad");
        assertEq(registryServiceUpgraded.getVersionCount(), 2, "version count not 2 after upgrade");

        assertEq(registryServiceUpgraded.getMessage(), "hi from upgrade mock", "unexpected message from upgraded registry service");
    }
*/


    function _logObject(string memory prefix, address object) internal view {
        NftId nftId = registry.getNftIdForAddress(object);
        _logObject(prefix, nftId);
    }

    function _logObject(string memory prefix, NftId nftId) internal view {
        IRegistry.ObjectInfo memory info = registry.getObjectInfo(nftId);

        // solhint-disable no-console
        console.log(prefix, "nftId", nftId.toInt());
        console.log(prefix, "parentNftId", info.parentNftId.toInt());
        console.log(prefix, "type", info.objectType.toInt());
        console.log(prefix, "address", info.objectAddress);
        console.log(prefix, "owner", registry.ownerOf(nftId));
        // solhint-enable
    }

}