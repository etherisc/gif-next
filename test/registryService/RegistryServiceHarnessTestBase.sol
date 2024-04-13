// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { FoundryRandom } from "foundry-random/FoundryRandom.sol";

import {Test, Vm, console} from "../../lib/forge-std/src/Test.sol";

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {NftId, toNftId, zeroNftId} from "../../contracts/type/NftId.sol";
import {ObjectType, toObjectType} from "../../contracts/type/ObjectType.sol";
import {VersionPartLib} from "../../contracts/type/Version.sol";

import {IRegisterable} from "../../contracts/shared/IRegisterable.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {IRegistryService} from "../../contracts/registry/IRegistryService.sol";
import {RegistryService} from "../../contracts/registry/RegistryService.sol";
import {RegistryAccessManager} from "../../contracts/registry/RegistryAccessManager.sol";
import {ReleaseManager} from "../../contracts/registry/ReleaseManager.sol";
import {RegistryServiceManagerMockWithHarness} from "../mock/RegistryServiceManagerMock.sol";
import {RegistryServiceHarness} from "./RegistryServiceHarness.sol";


// Helper functions to test IRegistry.ObjectInfo structs 
function eqObjectInfo(IRegistry.ObjectInfo memory a, IRegistry.ObjectInfo memory b) pure returns (bool isSame) {
    return (
        (a.nftId == b.nftId) &&
        (a.parentNftId == b.parentNftId) &&
        (a.objectType == b.objectType) &&
        (a.objectAddress == b.objectAddress) &&
        (a.initialOwner == b.initialOwner) &&
        (a.data.length == b.data.length) &&
        keccak256(a.data) == keccak256(b.data)
    );
}

function toBool(uint256 uintVal) pure returns (bool boolVal)
{
    assembly {
        boolVal := uintVal
    }
}

contract RegistryServiceHarnessTestBase is Test, FoundryRandom {

    address public registryOwner = makeAddr("registryOwner");
    address public registerableOwner = makeAddr("registerableOwner");
    address public outsider = makeAddr("outsider");

    RegistryServiceManagerMockWithHarness public registryServiceManager;
    RegistryServiceHarness public registryServiceHarness;
    IRegistry public registry;

    function setUp() public virtual
    {
        vm.startPrank(registryOwner);

        RegistryAccessManager accessManager = new RegistryAccessManager(registryOwner);

        ReleaseManager releaseManager = new ReleaseManager(
            accessManager,
            VersionPartLib.toVersionPart(3));

        registry = IRegistry(releaseManager.getRegistry());

        registryServiceManager = new RegistryServiceManagerMockWithHarness(
            address(accessManager), 
            address(registry));
        vm.stopPrank();

        registryServiceHarness = RegistryServiceHarness(address(registryServiceManager.getRegistryService()));
    }

    function _assert_getAndVerifyContractInfo(
        IRegisterable registerable, 
        ObjectType expectedType, 
        address expectedOwner)
        internal
    {
        IRegistry.ObjectInfo memory info = registerable.getInitialInfo();
        info.objectAddress = address(registerable);
        bool expectRevert = false;

        if(info.objectType != expectedType) {
            vm.expectRevert(abi.encodeWithSelector(
                IRegistryService.UnexpectedRegisterableType.selector,
                expectedType,
                info.objectType));
            expectRevert = true;
        } else if(info.initialOwner != expectedOwner) { 
            vm.expectRevert(abi.encodeWithSelector(
                IRegistryService.NotRegisterableOwner.selector,
                expectedOwner));
            expectRevert = true;
        } else if(info.initialOwner == address(registerable)) {
            vm.expectRevert(abi.encodeWithSelector(IRegistryService.SelfRegistration.selector));
            expectRevert = true;
        } else if(info.initialOwner == address(0)) {
            vm.expectRevert(abi.encodeWithSelector(IRegistryService.RegisterableOwnerIsZero.selector));
            expectRevert = true;
        }else if(registry.isRegistered(info.initialOwner)) { 
            vm.expectRevert(abi.encodeWithSelector(IRegistryService.RegisterableOwnerIsRegistered.selector));
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

            assertTrue(eqObjectInfo(info, infoFromRegistryService), 
                "Info read from registerable is different from info returned by registry service");
        }
    }

    function _assert_verifyObjectInfo(
        IRegistry.ObjectInfo memory info, 
        ObjectType expectedType)
        internal
    {
        //if(info.objectAddress > address(0)) {
        //    vm.expectRevert(abi.encodeWithSelector(
        //        IRegistryService.UnexpectedRegisterableAddress.selector,
        //        address(0), 
        //        info.objectAddress));
        //} else 
        if(info.objectType != expectedType) {
            vm.expectRevert(abi.encodeWithSelector(
                IRegistryService.UnexpectedRegisterableType.selector,
                expectedType,
                info.objectType));
        } else if(info.initialOwner == address(0)) {
            vm.expectRevert(abi.encodeWithSelector(
                IRegistryService.RegisterableOwnerIsZero.selector));
        } else if(registry.isRegistered(info.initialOwner)) { 
            vm.expectRevert(abi.encodeWithSelector(
                IRegistryService.RegisterableOwnerIsRegistered.selector));
        }

        registryServiceHarness.exposed_verifyObjectInfo(
            info, 
            expectedType);
    }
}