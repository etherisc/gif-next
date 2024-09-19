// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Vm, console} from "../../lib/forge-std/src/Test.sol";
import {NftId, NftIdLib} from "../../contracts/type/NftId.sol";
import {ObjectType, ObjectTypeLib} from "../../contracts/type/ObjectType.sol";
import {VersionPartLib} from "../../contracts/type/Version.sol";

import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {IRegistryService} from "../../contracts/registry/IRegistryService.sol";
import {RegistryService} from "../../contracts/registry/RegistryService.sol";
import {RegistryServiceHarnessTestBase} from "./RegistryServiceHarnessTestBase.sol";

contract VerifyObjectInfoTest is RegistryServiceHarnessTestBase {

    function test_withValidObjectHappyCase() public
    {
        ObjectType objectType = ObjectTypeLib.toObjectType(randomNumber(type(uint8).max));
        
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo({
            nftId: NftIdLib.toNftId(randomNumber(type(uint96).max)),
            parentNftId: NftIdLib.toNftId(randomNumber(type(uint96).max)), 
            objectType: objectType,
            release: VersionPartLib.toVersionPart(uint8(randomNumber(type(uint8).max))),
            isInterceptor: toBool(randomNumber(1)), 
            objectAddress: address(0)
        });

        registryServiceHarness.exposed_verifyObjectInfo(
                info,
                registerableOwner,
                objectType); // expectedType
    } 

    function test_withObjectTypeDifferentFromExpectedType() public 
    {
        ObjectType objectType = ObjectTypeLib.toObjectType(randomNumber(type(uint8).max));
        ObjectType expectedType = ObjectTypeLib.toObjectType(randomNumber(type(uint8).max));

        if(objectType == expectedType) {
            expectedType = ObjectTypeLib.toObjectType(expectedType.toInt() + 1);
        }

        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo({
            nftId: NftIdLib.toNftId(randomNumber(type(uint96).max)),
            parentNftId: NftIdLib.toNftId(randomNumber(type(uint96).max)),
            objectType: objectType,
            release: VersionPartLib.toVersionPart(uint8(randomNumber(type(uint8).max))),
            isInterceptor: toBool(randomNumber(1)), 
            objectAddress: address(0)
        });

        vm.expectRevert(abi.encodeWithSelector(
            IRegistryService.ErrorRegistryServiceObjectTypeInvalid.selector,
            expectedType,
            objectType));

        registryServiceHarness.exposed_verifyObjectInfo(
            info,
            registerableOwner,
            expectedType);
    }

    function test_withZeroObjectType() public 
    {
        ObjectType objectType = ObjectTypeLib.zero();
        ObjectType expectedType = ObjectTypeLib.toObjectType(randomNumber(type(uint8).max));

        if(objectType == expectedType) {
            expectedType = ObjectTypeLib.toObjectType(expectedType.toInt() + 1);
        }

        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo({
            nftId: NftIdLib.toNftId(randomNumber(type(uint96).max)), 
            parentNftId: NftIdLib.toNftId(randomNumber(type(uint96).max)),
            objectType: objectType,
            release: VersionPartLib.toVersionPart(uint8(randomNumber(type(uint8).max))),
            isInterceptor: toBool(randomNumber(1)),
            objectAddress: address(0)
        });

        vm.expectRevert(abi.encodeWithSelector(
            IRegistryService.ErrorRegistryServiceObjectTypeInvalid.selector,
            expectedType,
            objectType));

        registryServiceHarness.exposed_verifyObjectInfo(
            info,
            registerableOwner,
            expectedType);
    }

    function test_whenExpectedTypeIsZero() public 
    {
        ObjectType objectType = ObjectTypeLib.toObjectType(randomNumber(type(uint8).max));
        ObjectType expectedType = ObjectTypeLib.zero();

        if(objectType == expectedType) {
            objectType = ObjectTypeLib.toObjectType(objectType.toInt() + 1);
        }

        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo({
            nftId: NftIdLib.toNftId(randomNumber(type(uint96).max)),
            parentNftId: NftIdLib.toNftId(randomNumber(type(uint96).max)),
            objectType: objectType,
            release: VersionPartLib.toVersionPart(uint8(randomNumber(type(uint8).max))),
            isInterceptor: toBool(randomNumber(1)),
            objectAddress: address(0)
        });

        vm.expectRevert(abi.encodeWithSelector(
            IRegistryService.ErrorRegistryServiceObjectTypeInvalid.selector,
            expectedType,
            objectType));

        registryServiceHarness.exposed_verifyObjectInfo(
            info,
            registerableOwner,
            expectedType);
    }

    /* 0 object address is enforced
    function test_withNonZeroObjectAddress() public 
    {
        ObjectType objectType = ObjectTypeLib.toObjectType(randomNumber(type(uint8).max));

        address nonZeroObjectAddress = address(uint160(randomNumber(type(uint160).max)));
        if(nonZeroObjectAddress == address(0)) {
            nonZeroObjectAddress = address(uint160(nonZeroObjectAddress) + 1);
        }

        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo({
            nftId: NftIdLib.toNftId(randomNumber(type(uint96).max)),
            parentNftId: NftIdLib.toNftId(randomNumber(type(uint96).max)),
            objectType: objectType,
            isInterceptor: toBool(randomNumber(1)),
            objectAddress: nonZeroObjectAddress,
            initialOwner: registerableOwner,
            data: ""
        });

        vm.expectRevert(abi.encodeWithSelector(
            IRegistryService.UnexpectedRegisterableAddress.selector,
            address(0),
            nonZeroObjectAddress));

        registryServiceHarness.exposed_verifyObjectInfo(
            info,
            objectType); // expectedType
    }*/

    function test_withZeroObjectOwner() public
    {
        ObjectType objectType = ObjectTypeLib.toObjectType(randomNumber(type(uint8).max));

        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo({
            nftId: NftIdLib.toNftId(randomNumber(type(uint96).max)),
            parentNftId: NftIdLib.toNftId(randomNumber(type(uint96).max)),
            objectType: objectType,
            release: VersionPartLib.toVersionPart(uint8(randomNumber(type(uint8).max))),
            isInterceptor: toBool(randomNumber(1)),
            objectAddress: address(0)
        });

        vm.expectRevert(abi.encodeWithSelector(
            IRegistryService.ErrorRegistryServiceObjectOwnerZero.selector,
            objectType));

        registryServiceHarness.exposed_verifyObjectInfo(
            info,
            address(0), // zero owner
            objectType); // expectedType
    }

    function test_withRegisteredObjectOwner() public
    {
        ObjectType objectType = ObjectTypeLib.toObjectType(randomNumber(type(uint8).max));

        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo({
            nftId: NftIdLib.toNftId(randomNumber(type(uint96).max)),
            parentNftId: NftIdLib.toNftId(randomNumber(type(uint96).max)),
            objectType: objectType,
            release: VersionPartLib.toVersionPart(uint8(randomNumber(type(uint8).max))),
            isInterceptor: toBool(randomNumber(1)),
            objectAddress: address(0)
        });

        vm.expectRevert(abi.encodeWithSelector(
            IRegistryService.ErrorRegistryServiceObjectOwnerRegistered.selector,
            objectType,
            address(registry)));

        registryServiceHarness.exposed_verifyObjectInfo(
            info,
            address(registry), // any registered address
            objectType); // expectedType
    }
}