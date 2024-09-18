// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {FoundryRandom} from "foundry-random/FoundryRandom.sol";

import {Vm, console} from "../../lib/forge-std/src/Test.sol";

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {NftId, NftIdLib} from "../../contracts/type/NftId.sol";
import {ObjectType} from "../../contracts/type/ObjectType.sol";
import {VersionPartLib, VersionPart} from "../../contracts/type/Version.sol";
import {RoleId} from "../../contracts/type/RoleId.sol";

import {IAccessAdmin} from "../../contracts/authorization/IAccessAdmin.sol";

import {Dip} from "../../contracts/mock/Dip.sol";
import {IRegisterable} from "../../contracts/shared/IRegisterable.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {IRegistryService} from "../../contracts/registry/IRegistryService.sol";
import {RegistryService} from "../../contracts/registry/RegistryService.sol";
import {RegistryAdmin} from "../../contracts/registry/RegistryAdmin.sol";
import {ReleaseRegistry} from "../../contracts/registry/ReleaseRegistry.sol";
import {RegistryServiceManagerMockWithHarness} from "../mock/RegistryServiceManagerMock.sol";
import {RegistryServiceHarness} from "./RegistryServiceHarness.sol";
import {ServiceAuthorizationMockWithRegistryService} from "../mock/ServiceAuthorizationMock.sol";

import {GifDeployer} from "../base/GifDeployer.sol";
import {GifTest} from "../base/GifTest.sol";


contract RegistryServiceHarnessTestBase is GifDeployer, FoundryRandom {

    address public registerableOwner = makeAddr("registerableOwner");
    address public outsider = makeAddr("outsider");

    RegistryServiceManagerMockWithHarness public registryServiceManagerWithHarness;
    RegistryServiceHarness public registryServiceHarness;


    function setUp() public virtual
    {
        globalRegistry = makeAddr("globalRegistry");
        registryOwner = makeAddr("registryOwner");

        // solhint-disable-next-line
        console.log("tx origin", tx.origin);

        address gifAdmin = registryOwner;
        address gifManager = registryOwner;
        address stakingOwner = registryOwner;

        (
            , // dip,
            registry,
            , // tokenRegistry,
            releaseRegistry,
            , // registryAdmin,
            , // stakingManager,
            // staking
        ) = deployCore(
            globalRegistry,
            gifAdmin,
            gifManager,
            stakingOwner);

        registryAddress = address(registry);

        vm.startPrank(registryOwner);
        _deployRegistryServiceHarness();
        vm.stopPrank();
    }

    function _deployRegistryServiceHarness() internal 
    {
        bytes32 salt = "0x2222";

        releaseRegistry.createNextRelease();

        (
            IAccessAdmin releaseAdmin,
            VersionPart releaseVersion,
            bytes32 releaseSalt
        ) = releaseRegistry.prepareNextRelease(
            new ServiceAuthorizationMockWithRegistryService(VersionPartLib.toVersionPart(3)),
            salt);

        registryServiceManagerWithHarness = new RegistryServiceManagerMockWithHarness{salt: releaseSalt}(
            releaseAdmin.authority(),
            registryAddress,
            releaseSalt);

        registryServiceHarness = RegistryServiceHarness(address(registryServiceManagerWithHarness.getRegistryService()));
        releaseRegistry.registerService(registryServiceHarness);
        registryServiceManagerWithHarness.linkToProxy();

        // TODO check if this nees to be re-enabled
        // assertEq(serviceAddresses[0], address(registryServiceHarness), "error: registry service address mismatch");

        releaseRegistry.activateNextRelease();

    }

    function _assert_getAndVerifyContractInfo(
        IRegisterable registerable, 
        ObjectType expectedType, 
        address expectedOwner)
        internal
    {
        IRegistry.ObjectInfo memory info;
        address initialOwner;
        (info, initialOwner, /*data*/) = registerable.getInitialInfo();
        bool expectRevert = false;

        if(info.objectAddress != address(registerable)) {
            vm.expectRevert(abi.encodeWithSelector(
                IRegistryService.ErrorRegistryServiceRegisterableAddressInvalid.selector,
                address(registerable), 
                info.objectAddress));
            expectRevert = true;
        } else if(info.objectType != expectedType) {
            vm.expectRevert(abi.encodeWithSelector(
                IRegistryService.ErrorRegistryServiceRegisterableTypeInvalid.selector,
                info.objectAddress,
                expectedType,
                info.objectType));
            expectRevert = true;
        } else if(initialOwner != expectedOwner) { 
            vm.expectRevert(abi.encodeWithSelector(
                IRegistryService.ErrorRegistryServiceRegisterableOwnerInvalid.selector,
                info.objectAddress,
                expectedOwner,
                initialOwner));
            expectRevert = true;
        } else if(initialOwner == address(registerable)) {
            vm.expectRevert(abi.encodeWithSelector(
                IRegistryService.ErrorRegistryServiceRegisterableSelfRegistration.selector,
                info.objectAddress));
            expectRevert = true;
        } else if(initialOwner == address(0)) {
            vm.expectRevert(abi.encodeWithSelector(IRegistryService.ErrorRegistryServiceRegisterableOwnerZero.selector,
            info.objectAddress));
            expectRevert = true;
        }else if(registry.isRegistered(initialOwner)) { 
            vm.expectRevert(abi.encodeWithSelector(IRegistryService.ErrorRegistryServiceRegisterableOwnerRegistered.selector,
            info.objectAddress,
            initialOwner));
            expectRevert = true;
        }

        if(expectRevert) {
            registryServiceHarness.exposed_getAndVerifyContractInfo(
                registerable,
                expectedType,
                expectedOwner);
        } else {
            IRegistry.ObjectInfo memory infoFromRegistryService = registryServiceHarness.exposed_getAndVerifyContractInfo(
                registerable,
                expectedType,
                expectedOwner);  

            IRegistry.ObjectInfo memory infoFromRegistry = registry.getObjectInfo(address(registerable));

            eqObjectInfo(info, infoFromRegistryService);
            eqObjectInfo(infoFromRegistry, infoFromRegistryService);
        }
    }

    function _assert_verifyObjectInfo(
        IRegistry.ObjectInfo memory info,
        address initialOwner, 
        ObjectType expectedType)
        internal
    {
        if(info.objectAddress > address(0)) {
            vm.expectRevert(abi.encodeWithSelector(
                IRegistryService.ErrorRegistryServiceObjectAddressNotZero.selector,
                info.objectType));
        } else if(info.objectType != expectedType) {
            vm.expectRevert(abi.encodeWithSelector(
                IRegistryService.ErrorRegistryServiceObjectTypeInvalid.selector,
                expectedType,
                info.objectType));
        } else if(initialOwner == address(0)) {
            vm.expectRevert(abi.encodeWithSelector(
                IRegistryService.ErrorRegistryServiceObjectOwnerZero.selector,
                info.objectType));
        } else if(registry.isRegistered(initialOwner)) { 
            vm.expectRevert(abi.encodeWithSelector(
                IRegistryService.ErrorRegistryServiceObjectOwnerRegistered.selector,
                info.objectType, 
                initialOwner));
        }

        registryServiceHarness.exposed_verifyObjectInfo(
            info, 
            initialOwner,
            expectedType);
    }
}
