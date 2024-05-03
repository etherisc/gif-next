// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { FoundryRandom } from "foundry-random/FoundryRandom.sol";

import {Vm, console} from "../../lib/forge-std/src/Test.sol";

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {NftId, toNftId, zeroNftId} from "../../contracts/type/NftId.sol";
import {ObjectType, toObjectType} from "../../contracts/type/ObjectType.sol";
import {VersionPartLib, VersionPart} from "../../contracts/type/Version.sol";
import {RoleId} from "../../contracts/type/RoleId.sol";

import {IRegisterable} from "../../contracts/shared/IRegisterable.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {IRegistryService} from "../../contracts/registry/IRegistryService.sol";
import {RegistryService} from "../../contracts/registry/RegistryService.sol";
import {RegistryAdmin} from "../../contracts/registry/RegistryAdmin.sol";
import {ReleaseManager} from "../../contracts/registry/ReleaseManager.sol";
import {RegistryServiceManagerMockWithHarness} from "../mock/RegistryServiceManagerMock.sol";
import {RegistryServiceHarness} from "./RegistryServiceHarness.sol";

import {TestGifBase} from "../base/TestGifBase.sol";
import {RegistryServiceTestConfig} from "./RegistryServiceTestConfig.sol";


contract RegistryServiceHarnessTestBase is TestGifBase, FoundryRandom {

    address public registerableOwner = makeAddr("registerableOwner");

    RegistryServiceManagerMockWithHarness public registryServiceManagerWithHarness;
    RegistryServiceHarness public registryServiceHarness;

    function setUp() public virtual override
    {
        vm.startPrank(registryOwner);

        _deployRegistry();

        _deployRegistryServiceHarness();
    }

    function _deployRegistryServiceHarness() internal 
    {
        //bytes32 salt = "0x2222";

        // RegistryServiceManagerMockWithHarness first deploys RegistryService and then upgrades to RegistryServiceHarness
        // thus address is computed with RegistryService bytecode instead of RegistryServiceHarness...
        RegistryServiceTestConfig config = new RegistryServiceTestConfig(
            releaseManager,
            type(RegistryServiceManagerMockWithHarness).creationCode, // proxy manager
            type(RegistryService).creationCode, // implementation
            registryOwner,
            VersionPartLib.toVersionPart(3),
            "0x2222");

        (
            address[] memory serviceAddresses,
            string[] memory serviceNames,
            RoleId[][] memory serviceRoles,
            string[][] memory serviceRoleNames,
            RoleId[][] memory functionRoles,
            string[][] memory functionRoleNames,
            bytes4[][][] memory selectors
        ) = config.getConfig();

        releaseManager.createNextRelease();

        (
            address releaseAccessManager,
            VersionPart releaseVersion,
            bytes32 releaseSalt
        ) = releaseManager.prepareNextRelease(
            serviceAddresses, 
            serviceNames, 
            serviceRoles, 
            serviceRoleNames, 
            functionRoles, 
            functionRoleNames,
            selectors, 
            "0x2222");//salt);

        assertEq(config._accessManager(), releaseAccessManager, "error: access manager mismatch");

        registryServiceManagerWithHarness = new RegistryServiceManagerMockWithHarness{salt: releaseSalt}(
            releaseAccessManager,
            registryAddress,
            releaseSalt);
        registryServiceHarness = RegistryServiceHarness(address(registryServiceManagerWithHarness.getRegistryService()));

        assertEq(serviceAddresses[0], address(registryServiceHarness), "error: registry service address mismatch");
        releaseManager.registerService(registryServiceHarness);

        releaseManager.activateNextRelease();

        registryServiceManagerWithHarness.linkToProxy();
    }

    function _assert_getAndVerifyContractInfo(
        IRegisterable registerable, 
        ObjectType expectedType, 
        address expectedOwner)
        internal
    {
        IRegistry.ObjectInfo memory info = registerable.getInitialInfo();
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
        } else if(info.initialOwner != expectedOwner) { 
            vm.expectRevert(abi.encodeWithSelector(
                IRegistryService.ErrorRegistryServiceRegisterableOwnerInvalid.selector,
                info.objectAddress,
                expectedOwner,
                info.initialOwner));
            expectRevert = true;
        } else if(info.initialOwner == address(registerable)) {
            vm.expectRevert(abi.encodeWithSelector(
                IRegistryService.ErrorRegistryServiceRegisterableSelfRegistration.selector,
                info.objectAddress));
            expectRevert = true;
        } else if(info.initialOwner == address(0)) {
            vm.expectRevert(abi.encodeWithSelector(IRegistryService.ErrorRegistryServiceRegisterableOwnerZero.selector,
            info.objectAddress));
            expectRevert = true;
        }else if(registry.isRegistered(info.initialOwner)) { 
            vm.expectRevert(abi.encodeWithSelector(IRegistryService.ErrorRegistryServiceRegisterableOwnerRegistered.selector,
            info.objectAddress,
            info.initialOwner));
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
        } else if(info.initialOwner == address(0)) {
            vm.expectRevert(abi.encodeWithSelector(
                IRegistryService.ErrorRegistryServiceObjectOwnerZero.selector,
                info.objectType));
        } else if(registry.isRegistered(info.initialOwner)) { 
            vm.expectRevert(abi.encodeWithSelector(
                IRegistryService.ErrorRegistryServiceObjectOwnerRegistered.selector,
                info.objectType, 
                info.initialOwner));
        }

        registryServiceHarness.exposed_verifyObjectInfo(
            info, 
            expectedType);
    }
}
