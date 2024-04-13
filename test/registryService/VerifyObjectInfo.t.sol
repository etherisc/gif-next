// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Vm, console} from "../../lib/forge-std/src/Test.sol";
import {NftId, toNftId, zeroNftId} from "../../contracts/type/NftId.sol";
import {ObjectType, toObjectType, ObjectTypeLib, zeroObjectType} from "../../contracts/type/ObjectType.sol";

import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {IRegistryService} from "../../contracts/registry/IRegistryService.sol";
import {RegistryService} from "../../contracts/registry/RegistryService.sol";
import {RegistryServiceHarnessTestBase, toBool} from "./RegistryServiceHarnessTestBase.sol";

contract VerifyObjectInfoTest is RegistryServiceHarnessTestBase {

    function test_withValidObjectHappyCase() public
    {
        ObjectType objectType = toObjectType(randomNumber(type(uint8).max));
        
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo({
            nftId: toNftId(randomNumber(type(uint96).max)),
            parentNftId: toNftId(randomNumber(type(uint96).max)), 
            objectType: objectType,
            isInterceptor: toBool(randomNumber(1)), 
            objectAddress: address(0), 
            initialOwner: registerableOwner,
            data: ""
        });

        registryServiceHarness.exposed_verifyObjectInfo(
                info,
                objectType); // expectedType
    } 

    function test_withObjectTypeDifferentFromExpectedType() public 
    {
        ObjectType objectType = toObjectType(randomNumber(type(uint8).max));
        ObjectType expectedType = toObjectType(randomNumber(type(uint8).max));

        if(objectType == expectedType) {
            expectedType = toObjectType(expectedType.toInt() + 1);
        }

        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo({
            nftId: toNftId(randomNumber(type(uint96).max)),
            parentNftId: toNftId(randomNumber(type(uint96).max)),
            objectType: objectType,
            isInterceptor: toBool(randomNumber(1)), 
            objectAddress: address(0), 
            initialOwner: registerableOwner,
            data: ""
        });

        vm.expectRevert(abi.encodeWithSelector(
            IRegistryService.UnexpectedRegisterableType.selector,
            expectedType,
            objectType));

        registryServiceHarness.exposed_verifyObjectInfo(
            info,
            expectedType);
    }

    function test_withZeroObjectType() public 
    {
        ObjectType objectType = zeroObjectType();
        ObjectType expectedType = toObjectType(randomNumber(type(uint8).max));

        if(objectType == expectedType) {
            expectedType = toObjectType(expectedType.toInt() + 1);
        }

        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo({
            nftId: toNftId(randomNumber(type(uint96).max)), 
            parentNftId: toNftId(randomNumber(type(uint96).max)),
            objectType: objectType,
            isInterceptor: toBool(randomNumber(1)),
            objectAddress: address(0),
            initialOwner: registerableOwner,
            data: ""
        });

        vm.expectRevert(abi.encodeWithSelector(
            IRegistryService.UnexpectedRegisterableType.selector,
            expectedType,
            objectType));

        registryServiceHarness.exposed_verifyObjectInfo(
            info,
            expectedType);
    }

    function test_whenExpectedTypeIsZero() public 
    {
        ObjectType objectType = toObjectType(randomNumber(type(uint8).max));
        ObjectType expectedType = zeroObjectType();

        if(objectType == expectedType) {
            objectType = toObjectType(objectType.toInt() + 1);
        }

        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo({
            nftId: toNftId(randomNumber(type(uint96).max)),
            parentNftId: toNftId(randomNumber(type(uint96).max)),
            objectType: objectType,
            isInterceptor: toBool(randomNumber(1)),
            objectAddress: address(0),
            initialOwner: registerableOwner,
            data: ""
        });

        vm.expectRevert(abi.encodeWithSelector(
            IRegistryService.UnexpectedRegisterableType.selector,
            expectedType,
            objectType));

        registryServiceHarness.exposed_verifyObjectInfo(
            info,
            expectedType);
    }

    /* 0 object address is enforced
    function test_withNonZeroObjectAddress() public 
    {
        ObjectType objectType = toObjectType(randomNumber(type(uint8).max));

        address nonZeroObjectAddress = address(uint160(randomNumber(type(uint160).max)));
        if(nonZeroObjectAddress == address(0)) {
            nonZeroObjectAddress = address(uint160(nonZeroObjectAddress) + 1);
        }

        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo({
            nftId: toNftId(randomNumber(type(uint96).max)),
            parentNftId: toNftId(randomNumber(type(uint96).max)),
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
        ObjectType objectType = toObjectType(randomNumber(type(uint8).max));

        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo({
            nftId: toNftId(randomNumber(type(uint96).max)),
            parentNftId: toNftId(randomNumber(type(uint96).max)),
            objectType: objectType,
            isInterceptor: toBool(randomNumber(1)),
            objectAddress: address(0),
            initialOwner: address(0),
            data: ""
        });

        vm.expectRevert(abi.encodeWithSelector(
            IRegistryService.RegisterableOwnerIsZero.selector));

        registryServiceHarness.exposed_verifyObjectInfo(
            info,
            objectType); // expectedType
    }

    function test_withRegisteredObjectOwner() public
    {
        ObjectType objectType = toObjectType(randomNumber(type(uint8).max));

        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo({
            nftId: toNftId(randomNumber(type(uint96).max)),
            parentNftId: toNftId(randomNumber(type(uint96).max)),
            objectType: objectType,
            isInterceptor: toBool(randomNumber(1)),
            objectAddress: address(0),
            initialOwner: address(registry), // any registered address
            data: ""
        });

        vm.expectRevert(abi.encodeWithSelector(
            IRegistryService.RegisterableOwnerIsRegistered.selector));

        registryServiceHarness.exposed_verifyObjectInfo(
            info,
            objectType); // expectedType
    }
}