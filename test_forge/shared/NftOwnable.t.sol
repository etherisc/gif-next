// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "../../lib/forge-std/src/Test.sol";

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {INftOwnable} from "../../contracts/shared/INftOwnable.sol";
import {NftId} from "../../contracts/types/NftId.sol";
import {RegistryService} from "../../contracts/registry/RegistryService.sol";
import {RegistryServiceManager} from "../../contracts/registry/RegistryServiceManager.sol";
import {RegistryServiceReleaseManager} from "../../contracts/registry/RegistryServiceReleaseManager.sol";
import {RegistryServiceAccessManager} from "../../contracts/registry/RegistryServiceAccessManager.sol";
import {DIP} from "../mock/Dip.sol";
import {NftOwnableMock} from "../mock/NftOwnableMock.sol";

contract NftOwnableTest is Test {

    address public registryOwner = makeAddr("registryOwner");
    address public mockOwner = makeAddr("mockOwner");
    address public outsider = makeAddr("outsider");

    NftOwnableMock public mock;
    IRegistry public registry;
    RegistryService public registryService;

    function setUp() public {

        vm.startPrank(registryOwner);
        RegistryServiceAccessManager accessManager = new RegistryServiceAccessManager(registryOwner);
        RegistryServiceReleaseManager releaseManager = new RegistryServiceReleaseManager(accessManager);
        RegistryServiceManager registryServiceManager = releaseManager.getProxyManager();
        vm.stopPrank();

        registryService = registryServiceManager.getRegistryService();
        registry = registryServiceManager.getRegistry();

        vm.prank(mockOwner);
        mock = new NftOwnableMock();
    }

    function test_NftOwnableMockSimple() public {
        // solhint-disable no-console
        console.log("registryOwner", registryOwner);
        console.log("registry address", address(registry));
        console.log("registry nft id", registry.getNftId(address(registry)).toInt());
        console.log("registry owner", registry.ownerOf(address(registry)));
        console.log("mockOwner", mockOwner);
        console.log("mock address", address(mock));
        console.log("mock registry address", address(mock.getRegistry()));
        console.log("mock nft id", mock.getNftId().toInt());
        console.log("mock owner", mock.getOwner());
        // solhint-enable

        assertTrue(registryOwner != mockOwner, "registry and mock owner the same");
        assertEq(mock.getOwner(), mockOwner, "unexpected initial mock owner");
    }

    //--- linkToRegisteredNftId() tests

    function test_NftOwnableLinkToRegNftIdTwice() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                INftOwnable.ErrorAlreadyLinked.selector,
                address(registry),
                registryService.getNftId()));
        registryService.linkToRegisteredNftId();
    }

    function test_NftOwnableLinkToRegNftIdWithUninitializedRegistry() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                INftOwnable.ErrorRegistryNotInitialized.selector));
        mock.linkToRegisteredNftId();
    }

    function test_NftOwnableLinkToRegNftIdWithUnregisteredContract() public {

        mock.initializeNftOwnable(mockOwner, address(registry));

        vm.expectRevert(
            abi.encodeWithSelector(
                INftOwnable.ErrorContractNotRegistered.selector,
                address(mock)));
        mock.linkToRegisteredNftId();
    }

    //--- initializeNftOwnable(address initialOwner, address registryAddress) tests

    function test_NftOwnableInitializeNftOwnableInitializeTwice() public {

        // attempt to override initial regisry address
        mock.initializeNftOwnable(mockOwner, address(registry));

        vm.expectRevert(
            abi.encodeWithSelector(
                INftOwnable.ErrorRegistryAlreadyInitialized.selector,
                address(registry)));
        mock.initializeNftOwnable(mockOwner, address(1));
    }

    function test_NftOwnableInitializeNftOwnableInitializeWithZeroRegistry() public {
        // attempt to initialize with zero registry address
        vm.expectRevert(
            abi.encodeWithSelector(
                INftOwnable.ErrorRegistryAddressZero.selector));
        mock.initializeNftOwnable(mockOwner, address(0));
    }

    function test_NftOwnableInitializeNftOwnableInitializeWithNonContract() public {
        // attempt to initialize with non-registry
        vm.expectRevert(
            abi.encodeWithSelector(
                INftOwnable.ErrorNotRegistry.selector,
                address(1)));
        mock.initializeNftOwnable(mockOwner, address(1));
    }

    function test_NftOwnableInitializeNftOwnableInitializeWithNonRegistry() public {
        DIP dip = new DIP();
        address fakeRegistryAddress = address(dip);

        // attempt to initialize with non-registry
        vm.expectRevert(
            abi.encodeWithSelector(
                INftOwnable.ErrorNotRegistry.selector,
                fakeRegistryAddress));
        mock.initializeNftOwnable(mockOwner, fakeRegistryAddress);
    }

    //--- linkToNftOwnable(address registryAddress, address nftOwnableAddress) tests

    function test_NftOwnableLinkToNftOwnableNotOwner() public {
        // attempt to initialize with non-registry
        vm.expectRevert(
            abi.encodeWithSelector(
                INftOwnable.ErrorNotOwner.selector,
                outsider));
        vm.prank(outsider);
        mock.linkToNftOwnable(address(registry), address(mock));
    }

    function test_NftOwnableLinkToNftOwnableContractNotRegistered() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                INftOwnable.ErrorContractNotRegistered.selector,
                address(mock)));
        vm.prank(mockOwner);
        mock.linkToNftOwnable(address(registry), address(mock));
    }

    function test_NftOwnableLinkToNftOwnableHappyCase() public {
        address registryAddress = address(registry);

        assertEq(mock.getOwner(), mockOwner, "mock owner not initial mock owner before linking");

        // NFT_LOCK_ADDRESS becomes owner of mock
        vm.prank(mockOwner);
        mock.linkToNftOwnable(address(registry), address(registry));

        assertEq(mock.getNftId().toInt(), registry.getNftId(registryAddress).toInt(), "mock nft id not registry nft id");
        assertEq(mock.getOwner(), address(0x1), "mock owner not registry owner after linking");
    }

    function test_NftOwnableLinkToNftOwnableLinkTwice() public {
        address registryAddress = address(registry);

        // NFT_LOCK_ADDRESS becomes owner of mock
        vm.prank(mockOwner);
        mock.linkToNftOwnable(address(registry), address(registry));
        NftId mockNftId = mock.getNftId();

        vm.expectRevert(
            abi.encodeWithSelector(
                INftOwnable.ErrorAlreadyLinked.selector,
                registryAddress,
                mockNftId));
        vm.prank(address(0x1));
        mock.linkToNftOwnable(address(registry), address(1));
    }
}