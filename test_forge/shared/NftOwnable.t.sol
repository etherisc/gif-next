// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "../../lib/forge-std/src/Test.sol";

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol"; 

import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {IRegistryLinked} from "../../contracts/shared/IRegistryLinked.sol";
import {INftOwnable} from "../../contracts/shared/INftOwnable.sol";
import {NftId} from "../../contracts/types/NftId.sol";
import {VersionPart, VersionPartLib } from "../../contracts/types/Version.sol";
import {RegistryService} from "../../contracts/registry/RegistryService.sol";
import {RegistryServiceManager} from "../../contracts/registry/RegistryServiceManager.sol";
import {ReleaseManager} from "../../contracts/registry/ReleaseManager.sol";
import {RegistryAccessManager} from "../../contracts/registry/RegistryAccessManager.sol";
import {DIP} from "../mock/Dip.sol";
import {NftOwnableMock, NftOwnableMockUninitialized} from "../mock/NftOwnableMock.sol";

contract NftOwnableTest is Test {

    address public registryOwner = makeAddr("registryOwner");
    address public mockOwner = makeAddr("mockOwner");
    address public outsider = makeAddr("outsider");

    NftOwnableMockUninitialized public mockUninitialized;
    NftOwnableMock public mock;
    IRegistry public registry;
    RegistryService public registryService;

    function setUp() public {

        vm.startPrank(registryOwner);

        RegistryAccessManager accessManager = new RegistryAccessManager(registryOwner);

        ReleaseManager releaseManager = new ReleaseManager(
            accessManager,
            VersionPartLib.toVersionPart(3));

        registry = IRegistry(releaseManager.getRegistry());

        RegistryServiceManager registryServiceManager = new RegistryServiceManager(
            accessManager.authority(),
            address(registry)
        );        
        
        registryService = registryServiceManager.getRegistryService();

        accessManager.initialize(address(releaseManager), address(0x1));

        releaseManager.createNextRelease();

        releaseManager.registerRegistryService(registryService);

        registryServiceManager.linkToNftOwnable(address(registry));// links to registry service

        vm.stopPrank();

        vm.startPrank(mockOwner);
        mock = new NftOwnableMock();
        mockUninitialized = new NftOwnableMockUninitialized();
        vm.stopPrank();
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
                IRegistryLinked.ErrorRegistryNotInitialized.selector));
        mock.linkToRegisteredNftId();
    }

    function test_NftOwnableLinkToRegNftIdWithUnregisteredContract() public {
        mockUninitialized.initialize(mockOwner, address(registry));

        vm.expectRevert(
            abi.encodeWithSelector(
                INftOwnable.ErrorContractNotRegistered.selector,
                address(mockUninitialized)));
        mockUninitialized.linkToRegisteredNftId();
    }

    //--- initializeNftOwnable(address initialOwner, address registryAddress) tests

    function test_NftOwnableInitializeTwice() public {

        address fakeOwner = makeAddr("fakeOwner");
        address fakeRegistry = makeAddr("fakeRegistry");

        // attempt to reinitialize with new initial owner
        // this initialization has already happened when constructing the mock
        vm.expectRevert(
            abi.encodeWithSelector(
                Initializable.InvalidInitialization.selector));

        mock.initializeOwner(fakeOwner);

        // attempt to reinitialize with new initial owner and registry
        // initializeNftOwnable is not an initializer (and can only be called in the context of an initializer)
        vm.expectRevert(
            abi.encodeWithSelector(
                Initializable.NotInitializing.selector));

        mock.initializeNftOwnable(fakeOwner, fakeRegistry);
    }

    function test_NftOwnableInitializeNftOwnableInitializeWithZeroRegistry() public {
        // attempt to initialize with zero registry address
        vm.expectRevert(
            abi.encodeWithSelector(
                IRegistryLinked.ErrorRegistryAddressZero.selector));
        mockUninitialized.initialize(mockOwner, address(0));
    }

    function test_NftOwnableInitializeNftOwnableInitializeWithNonContract() public {
        // attempt to initialize with non-registry
        vm.expectRevert(
            abi.encodeWithSelector(
                IRegistryLinked.ErrorNotRegistry.selector,
                address(1)));
        mockUninitialized.initialize(mockOwner, address(1));
    }

    function test_NftOwnableInitializeNftOwnableInitializeWithNonRegistry() public {
        DIP dip = new DIP();
        address fakeRegistryAddress = address(dip);

        // attempt to initialize with non-registry
        vm.expectRevert(
            abi.encodeWithSelector(
                IRegistryLinked.ErrorNotRegistry.selector,
                fakeRegistryAddress));
        mockUninitialized.initialize(mockOwner, fakeRegistryAddress);
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
        mock.linkToNftOwnable(address(registry), address(registryService));
        NftId mockNftId = mock.getNftId();

        vm.expectRevert(
            abi.encodeWithSelector(
                INftOwnable.ErrorAlreadyLinked.selector,
                registryAddress,
                mockNftId));
        vm.prank(registryOwner);
        mock.linkToNftOwnable(address(registry), address(registryService));
    }
}