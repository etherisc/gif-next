// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { FoundryRandom } from "foundry-random/FoundryRandom.sol";

import {Vm, console} from "../../lib/forge-std/src/Test.sol";
import {NftId, toNftId, zeroNftId} from "../../contracts/type/NftId.sol";
import {ObjectType, toObjectType, ObjectTypeLib, zeroObjectType} from "../../contracts/type/ObjectType.sol";

import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {RegistryService} from "../../contracts/registry/RegistryService.sol";
import {IRegistryService} from "../../contracts/registry/RegistryService.sol";
import {RegistryServiceHarnessTestBase} from "./RegistryServiceHarnessTestBase.sol";

import {RegisterableMock,
        SelfOwnedRegisterableMock,
        RegisterableMockWithRandomInvalidAddress} from "../mock/RegisterableMock.sol";


contract GetAndVerifyContractInfoTest is RegistryServiceHarnessTestBase {

    function test_withValidRegisterableHappyCase() public
    {
        ObjectType registerableType = toObjectType(randomNumber(type(uint8).max));
        
        RegisterableMock registerable = new RegisterableMock(
            toNftId(randomNumber(type(uint96).max)), // nftId
            toNftId(randomNumber(type(uint96).max)), // parentNftId
            registerableType,
            toBool(randomNumber(1)), // isInterceptor
            registerableOwner,
            ""
        );

        IRegistry.ObjectInfo memory infoFromRegistryService = registryServiceHarness.exposed_getAndVerifyContractInfo(
                registerable,
                registerableType,
                registerableOwner);

        assertTrue(eqObjectInfo(infoFromRegistryService, registerable.getInitialInfo()), 
            "Info returned by registry service is different from info stored in registerable");
    } 

    function test_withInvalidRegisterableAddress() public 
    {
        ObjectType registerableType = toObjectType(randomNumber(type(uint8).max));

        RegisterableMockWithRandomInvalidAddress registerable = new RegisterableMockWithRandomInvalidAddress(
            toNftId(randomNumber(type(uint96).max)), // nftId
            toNftId(randomNumber(type(uint96).max)), // parentNftId
            registerableType,
            toBool(randomNumber(1)), // isInterceptor
            registerableOwner, // initialOwner
            ""
        );

        vm.expectRevert(abi.encodeWithSelector(
            IRegistryService.ErrorRegistryServiceRegisterableAddressInvalid.selector,
            address(registerable),
            registerable.getInitialInfo().objectAddress));

        IRegistry.ObjectInfo memory infoFromRegistryService = registryServiceHarness.exposed_getAndVerifyContractInfo(
                registerable,
                registerableType,
                registerableOwner);
    }

    function test_withRegisterableTypeDifferentFromExpectedType() public 
    {
        ObjectType registerableType = toObjectType(randomNumber(type(uint8).max));
        ObjectType expectedType = toObjectType(randomNumber(type(uint8).max));

        if(registerableType == expectedType) {
            expectedType = toObjectType(expectedType.toInt() + 1);
        }

        RegisterableMock registerable = new RegisterableMock(
            toNftId(randomNumber(type(uint96).max)), // nftId
            toNftId(randomNumber(type(uint96).max)), // parentNftId
            registerableType,
            toBool(randomNumber(1)), // isInterceptor
            registerableOwner, 
            ""
        );

        vm.expectRevert(abi.encodeWithSelector(
            IRegistryService.ErrorRegistryServiceRegisterableTypeInvalid.selector,
            address(registerable),
            expectedType,
            registerableType));

        registryServiceHarness.exposed_getAndVerifyContractInfo(
            registerable,
            expectedType,
            registerableOwner);
    }

    function test_withZeroRegisterableType() public
    {
        ObjectType registerableType = zeroObjectType();
        ObjectType expectedType = toObjectType(randomNumber(type(uint8).max));

        if(registerableType == expectedType) {
            expectedType = toObjectType(expectedType.toInt() + 1);
        }

        RegisterableMock registerable = new RegisterableMock(
            toNftId(randomNumber(type(uint96).max)), // nftId
            toNftId(randomNumber(type(uint96).max)), // parentNftId
            registerableType,
            toBool(randomNumber(1)), // isInterceptor
            registerableOwner, 
            ""
        );

        vm.expectRevert(abi.encodeWithSelector(
            IRegistryService.ErrorRegistryServiceRegisterableTypeInvalid.selector,
            address(registerable),
            expectedType,
            registerableType));

        registryServiceHarness.exposed_getAndVerifyContractInfo(
            registerable,
            expectedType,
            registerableOwner);
    }

    function test_whenExpectedTypeIsZero() public
    {
        ObjectType registerableType = toObjectType(randomNumber(type(uint8).max));
        ObjectType expectedType = zeroObjectType();

        if(registerableType == expectedType) {
            registerableType = toObjectType(registerableType.toInt() + 1);
        } 

        RegisterableMock registerable = new RegisterableMock(
            toNftId(randomNumber(type(uint96).max)), // nftId
            toNftId(randomNumber(type(uint96).max)), // parentNftId
            registerableType,
            toBool(randomNumber(1)), // isInterceptor
            registerableOwner, 
            ""
        );

        vm.expectRevert(abi.encodeWithSelector(
            IRegistryService.ErrorRegistryServiceRegisterableTypeInvalid.selector,
            address(registerable),
            expectedType,
            registerableType));

        registryServiceHarness.exposed_getAndVerifyContractInfo(
            registerable,
            expectedType,
            registerableOwner);       
    }

    function test_withRegisterableOwnerDifferentFromExpectedOwner() public
    {
        ObjectType registerableType = toObjectType(randomNumber(type(uint8).max));

        RegisterableMock registerable = new RegisterableMock(
            toNftId(randomNumber(type(uint96).max)), // nftId
            toNftId(randomNumber(type(uint96).max)), // parentNftId
            registerableType,
            toBool(randomNumber(1)), // isInterceptor
            registerableOwner, // initialOwner
            ""
        );

        vm.expectRevert(abi.encodeWithSelector(
            IRegistryService.ErrorRegistryServiceRegisterableOwnerInvalid.selector,
            address(registerable),
            outsider,
            registerableOwner));

        registryServiceHarness.exposed_getAndVerifyContractInfo(
            registerable,
            registerableType,
            outsider); // expectedOwner
    }

    function test_whenExpectedOwnerIsZero() public
    {
        ObjectType registerableType = toObjectType(randomNumber(type(uint8).max));

        RegisterableMock registerable = new RegisterableMock(
            toNftId(randomNumber(type(uint96).max)), // nftId
            toNftId(randomNumber(type(uint96).max)), // parentNftId
            registerableType,
            toBool(randomNumber(1)), // isInterceptor
            registerableOwner, // initialOwner
            ""
        );

        vm.expectRevert(abi.encodeWithSelector(
            IRegistryService.ErrorRegistryServiceRegisterableOwnerInvalid.selector,
            address(registerable),
            address(0),
            registerableOwner));

        registryServiceHarness.exposed_getAndVerifyContractInfo(
            registerable,
            registerableType,
            address(0)); // expectedOwner
    }

    function test_withZeroRegisterableOwner() public
    {
        ObjectType registerableType = toObjectType(randomNumber(type(uint8).max));

        RegisterableMock registerable = new RegisterableMock(
            toNftId(randomNumber(type(uint96).max)), // nftId
            toNftId(randomNumber(type(uint96).max)), // parentNftId
            registerableType,
            toBool(randomNumber(1)), // isInterceptor
            address(0), // initialOwner
            ""
        );

        vm.expectRevert(abi.encodeWithSelector(
            IRegistryService.ErrorRegistryServiceRegisterableOwnerInvalid.selector,
            address(registerable),
            registerableOwner,
            address(0)));

        registryServiceHarness.exposed_getAndVerifyContractInfo(
            registerable,
            registerableType,
            registerableOwner); 
    }

    function test_withZeroRegisterableOwnerAndZeroExpectedOwner() public
    {
        ObjectType registerableType = toObjectType(randomNumber(type(uint8).max));

        RegisterableMock registerable = new RegisterableMock(
            toNftId(randomNumber(type(uint96).max)), // nftId
            toNftId(randomNumber(type(uint96).max)), // parentNftId
            registerableType,
            toBool(randomNumber(1)), // isInterceptor
            address(0), // initialOwner
            ""
        );

        vm.expectRevert(abi.encodeWithSelector(
            IRegistryService.ErrorRegistryServiceRegisterableOwnerZero.selector,
            address(registerable)));

        registryServiceHarness.exposed_getAndVerifyContractInfo(
            registerable,
            registerableType,
            address(0)); // expectedOwner
    }

    function test_withRegisteredRegisterableOwner() public
    {
        ObjectType registerableType = toObjectType(randomNumber(type(uint8).max));
        
        RegisterableMock registerable = new RegisterableMock(
            toNftId(randomNumber(type(uint96).max)), // nftId
            toNftId(randomNumber(type(uint96).max)), // parentNftId
            registerableType,
            toBool(randomNumber(1)), // isInterceptor
            address(registry), // initialOwner
            ""
        );

        vm.expectRevert(abi.encodeWithSelector(
            IRegistryService.ErrorRegistryServiceRegisterableOwnerRegistered.selector,
            address(registerable),
            address(registry)));

        registryServiceHarness.exposed_getAndVerifyContractInfo(
            registerable,
            registerableType,
            address(registry)); // expectedOwner 
    }

    function test_withSelfOwnedRegisterable() public
    {
        ObjectType registerableType = toObjectType(randomNumber(type(uint8).max));
        
        SelfOwnedRegisterableMock selfOwnedRegisterable = new SelfOwnedRegisterableMock(
            toNftId(randomNumber(type(uint96).max)), // nftId
            toNftId(randomNumber(type(uint96).max)), // parentNftId
            registerableType,
            toBool(randomNumber(1)), // isInterceptor
            ""
        );     

        vm.expectRevert(abi.encodeWithSelector(
            IRegistryService.ErrorRegistryServiceRegisterableSelfRegistration.selector,
            address(selfOwnedRegisterable)));

        registryServiceHarness.exposed_getAndVerifyContractInfo(
            selfOwnedRegisterable,
            registerableType,
            address(selfOwnedRegisterable)); // expectedOwner
    }
}