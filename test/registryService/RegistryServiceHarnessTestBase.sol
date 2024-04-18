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
import {RegistryAccessManager} from "../../contracts/registry/RegistryAccessManager.sol";
import {ReleaseManager} from "../../contracts/registry/ReleaseManager.sol";
import {RegistryServiceManagerMockWithHarness} from "../mock/RegistryServiceManagerMock.sol";
import {RegistryServiceHarness} from "./RegistryServiceHarness.sol";

import {TestGifBase} from "../base/TestGifBase.sol";


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

    function _deployRegistryServiceHarness() internal {
    {
        bytes32 salt = "0x2222";
        bytes32 releaseSalt = keccak256(
            bytes.concat(
                bytes32(uint(3)),
                salt));

        IRegistry.ConfigStruct[] memory config = new IRegistry.ConfigStruct[](1);
        config[0] = IRegistry.ConfigStruct(
            address(0), // TODO calculate
            new RoleId[](0),
            new bytes4[][](0),
            new RoleId[](0));

        releaseManager.createNextRelease();

        (
            address releaseAccessManager,
            VersionPart releaseVersion,
            bytes32 releaseSalt2
        ) = releaseManager.prepareNextRelease(config, salt);

        registryServiceManager = new RegistryServiceManagerMockWithHarness{salt: releaseSalt}(
            releaseAccessManager,
            registryAddress,
            salt);
        registryServiceHarness = RegistryServiceHarness(address(registryServiceManager.getRegistryService()));
        releaseManager.registerService(registryServiceHarness);
    }
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
