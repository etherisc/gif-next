// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { FoundryRandom } from "foundry-random/FoundryRandom.sol";

import {Vm, console} from "../../lib/forge-std/src/Test.sol";
import {NftId, NftIdLib} from "../../contracts/type/NftId.sol";
import {ObjectType, ObjectTypeLib} from "../../contracts/type/ObjectType.sol";

import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {RegistryService} from "../../contracts/registry/RegistryService.sol";
import {IRegistryService} from "../../contracts/registry/RegistryService.sol";
import {RegistryServiceHarnessTestBase} from "./RegistryServiceHarnessTestBase.sol";

import {RegisterableMock,
        SelfOwnedRegisterableMock,
        RegisterableMockWithInvalidAddress} from "../mock/RegisterableMock.sol";


contract GetAndVerifyContractInfoTest is RegistryServiceHarnessTestBase {

    function test_withValidRegisterableHappyCase() public
    {
        ObjectType registerableType = ObjectTypeLib.toObjectType(randomNumber(type(uint8).max));
        
        RegisterableMock registerable = new RegisterableMock(
            NftIdLib.toNftId(randomNumber(type(uint96).max)), // nftId
            NftIdLib.toNftId(randomNumber(type(uint96).max)), // parentNftId
            registerableType,
            toBool(randomNumber(1)), // isInterceptor
            registerableOwner,
            ""
        );

        IRegistry.ObjectInfo memory infoFromRegistryService = registryServiceHarness.exposed_getAndVerifyContractInfo(
                registerable,
                registerableType,
                registerableOwner);

        eqObjectInfo(infoFromRegistryService, registerable.getInitialInfo());//, "Info returned by registry service is different from info stored in registerable");
    } 

    function test_withInvalidRegisterableAddress() public 
    {
        ObjectType registerableType = ObjectTypeLib.toObjectType(randomNumber(type(uint8).max));

        RegisterableMockWithInvalidAddress registerable = new RegisterableMockWithInvalidAddress(
            NftIdLib.toNftId(randomNumber(type(uint96).max)), // nftId
            NftIdLib.toNftId(randomNumber(type(uint96).max)), // parentNftId
            registerableType,
            toBool(randomNumber(1)), // isInterceptor
            address(uint160(randomNumber(type(uint160).max))),
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
        ObjectType registerableType = ObjectTypeLib.toObjectType(randomNumber(type(uint8).max));
        ObjectType expectedType = ObjectTypeLib.toObjectType(randomNumber(type(uint8).max));

        if(registerableType == expectedType) {
            expectedType = ObjectTypeLib.toObjectType(expectedType.toInt() + 1);
        }

        RegisterableMock registerable = new RegisterableMock(
            NftIdLib.toNftId(randomNumber(type(uint96).max)), // nftId
            NftIdLib.toNftId(randomNumber(type(uint96).max)), // parentNftId
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
        ObjectType registerableType = ObjectTypeLib.zero();
        ObjectType expectedType = ObjectTypeLib.toObjectType(randomNumber(type(uint8).max));

        if(registerableType == expectedType) {
            expectedType = ObjectTypeLib.toObjectType(expectedType.toInt() + 1);
        }

        RegisterableMock registerable = new RegisterableMock(
            NftIdLib.toNftId(randomNumber(type(uint96).max)), // nftId
            NftIdLib.toNftId(randomNumber(type(uint96).max)), // parentNftId
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
        ObjectType registerableType = ObjectTypeLib.toObjectType(randomNumber(type(uint8).max));
        ObjectType expectedType = ObjectTypeLib.zero();

        if(registerableType == expectedType) {
            registerableType = ObjectTypeLib.toObjectType(registerableType.toInt() + 1);
        } 

        RegisterableMock registerable = new RegisterableMock(
            NftIdLib.toNftId(randomNumber(type(uint96).max)), // nftId
            NftIdLib.toNftId(randomNumber(type(uint96).max)), // parentNftId
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
        ObjectType registerableType = ObjectTypeLib.toObjectType(randomNumber(type(uint8).max));

        RegisterableMock registerable = new RegisterableMock(
            NftIdLib.toNftId(randomNumber(type(uint96).max)), // nftId
            NftIdLib.toNftId(randomNumber(type(uint96).max)), // parentNftId
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
        ObjectType registerableType = ObjectTypeLib.toObjectType(randomNumber(type(uint8).max));

        RegisterableMock registerable = new RegisterableMock(
            NftIdLib.toNftId(randomNumber(type(uint96).max)), // nftId
            NftIdLib.toNftId(randomNumber(type(uint96).max)), // parentNftId
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
        ObjectType registerableType = ObjectTypeLib.toObjectType(randomNumber(type(uint8).max));

        RegisterableMock registerable = new RegisterableMock(
            NftIdLib.toNftId(randomNumber(type(uint96).max)), // nftId
            NftIdLib.toNftId(randomNumber(type(uint96).max)), // parentNftId
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
        ObjectType registerableType = ObjectTypeLib.toObjectType(randomNumber(type(uint8).max));

        RegisterableMock registerable = new RegisterableMock(
            NftIdLib.toNftId(randomNumber(type(uint96).max)), // nftId
            NftIdLib.toNftId(randomNumber(type(uint96).max)), // parentNftId
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
        ObjectType registerableType = ObjectTypeLib.toObjectType(randomNumber(type(uint8).max));
        
        RegisterableMock registerable = new RegisterableMock(
            NftIdLib.toNftId(randomNumber(type(uint96).max)), // nftId
            NftIdLib.toNftId(randomNumber(type(uint96).max)), // parentNftId
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
        ObjectType registerableType = ObjectTypeLib.toObjectType(randomNumber(type(uint8).max));
        
        SelfOwnedRegisterableMock selfOwnedRegisterable = new SelfOwnedRegisterableMock(
            NftIdLib.toNftId(randomNumber(type(uint96).max)), // nftId
            NftIdLib.toNftId(randomNumber(type(uint96).max)), // parentNftId
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