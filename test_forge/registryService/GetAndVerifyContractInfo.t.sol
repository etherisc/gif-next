// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Vm, console} from "../../lib/forge-std/src/Test.sol";
import {NftId, toNftId, zeroNftId} from "../../contracts/types/NftId.sol";
import {ObjectType, toObjectType, ObjectTypeLib, zeroObjectType} from "../../contracts/types/ObjectType.sol";

import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {RegistryService} from "../../contracts/registry/RegistryService.sol";
import {IRegistryService} from "../../contracts/registry/RegistryService.sol";
import {RegistryServiceHarnessTestBase, toBool, eqObjectInfo} from "./RegistryServiceHarnessTestBase.sol";

import {RegisterableMock,
        SelfOwnedRegisterableMock,
        RegisterableMockWithRandomInvalidAddress} from "../mock/RegisterableMock.sol";


contract GetAndVerifyContractInfoTest is RegistryServiceHarnessTestBase {

    function test_withValidRegisterableHappyCase() public
    {
        ObjectType registerableType = toObjectType(randomNumber(type(uint8).max));
        
        RegisterableMock registerable = new RegisterableMock(
            address(registry),
            toNftId(randomNumber(type(uint96).max)), // parentNftId
            registerableType,
            toBool(randomNumber(1)), // isInterceptor
            registerableOwner,
            ""
        );

        ( 
            IRegistry.ObjectInfo memory infoFromRegistryService,
            bytes memory dataFromRegistryService 
        ) = registryServiceHarness.exposed_getAndVerifyContractInfo(
                registerable,
                registerableType,
                registerableOwner);

        ( 
            IRegistry.ObjectInfo memory infoFromRegisterable,
            bytes memory dataFromRegisterable
        ) = registerable.getInitialInfo();
        
        assertTrue(eqObjectInfo(infoFromRegistryService, infoFromRegisterable), 
            "Info returned by registry service is different from info stored in registerable");
        assertEq(dataFromRegistryService, dataFromRegisterable, 
            "Data returned by registry service is different from data stored in registerable");
    } 

    function test_withRegisterableTypeDifferentFromExpectedType() public 
    {
        ObjectType registerableType = toObjectType(randomNumber(type(uint8).max));
        ObjectType expectedType = toObjectType(randomNumber(type(uint8).max));

        if(registerableType == expectedType) {
            expectedType = toObjectType(expectedType.toInt() + 1);
        }

        RegisterableMock registerable = new RegisterableMock(
            address(registry),
            toNftId(randomNumber(type(uint96).max)), // parentNftId
            registerableType,
            toBool(randomNumber(1)), // isInterceptor
            registerableOwner, 
            ""
        );

        vm.expectRevert(abi.encodeWithSelector(
            IRegistryService.UnexpectedRegisterableType.selector,
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
            address(registry),
            toNftId(randomNumber(type(uint96).max)), // parentNftId
            registerableType,
            toBool(randomNumber(1)), // isInterceptor
            registerableOwner, 
            ""
        );

        vm.expectRevert(abi.encodeWithSelector(
            IRegistryService.UnexpectedRegisterableType.selector,
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
            address(registry),
            toNftId(randomNumber(type(uint96).max)), // parentNftId
            registerableType,
            toBool(randomNumber(1)), // isInterceptor
            registerableOwner, 
            ""
        );

        vm.expectRevert(abi.encodeWithSelector(
            IRegistryService.UnexpectedRegisterableType.selector,
            expectedType,
            registerableType));

        registryServiceHarness.exposed_getAndVerifyContractInfo(
            registerable,
            expectedType,
            registerableOwner);       
    }

    function test_withInvalidRegisterableAddressHappyCase() public 
    {
        ObjectType registerableType = toObjectType(randomNumber(type(uint8).max));

        RegisterableMockWithRandomInvalidAddress registerable = new RegisterableMockWithRandomInvalidAddress(
            address(registry),
            toNftId(randomNumber(type(uint96).max)), // parentNftId
            registerableType,
            toBool(randomNumber(1)), // isInterceptor
            registerableOwner, // initialOwner
            ""
        );

        ( 
            IRegistry.ObjectInfo memory infoFromRegistryService,
            bytes memory dataFromRegistryService 
        ) = registryServiceHarness.exposed_getAndVerifyContractInfo(
                registerable,
                registerableType,
                registerableOwner);

        ( 
            IRegistry.ObjectInfo memory infoFromRegisterable,
            bytes memory dataFromRegisterable
        ) = registerable.getInitialInfo();

        infoFromRegisterable.objectAddress = address(registerable);
        
        assertTrue(eqObjectInfo(infoFromRegistryService, infoFromRegisterable), 
            "Info returned by registry service is different from info stored in registerable");
        assertEq(dataFromRegistryService, dataFromRegisterable, 
            "Data returned by registry service is different from data stored in registerable");
    }

    function test_withRegisterableOwnerDifferentFromExpectedOwner() public
    {
        ObjectType registerableType = toObjectType(randomNumber(type(uint8).max));

        RegisterableMock registerable = new RegisterableMock(
            address(registry),
            toNftId(randomNumber(type(uint96).max)), // parentNftId
            registerableType,
            toBool(randomNumber(1)), // isInterceptor
            registerableOwner, // initialOwner
            ""
        );

        vm.expectRevert(abi.encodeWithSelector(
            IRegistryService.NotRegisterableOwner.selector,
            outsider));

        registryServiceHarness.exposed_getAndVerifyContractInfo(
            registerable,
            registerableType,
            outsider); // expectedOwner
    }

    function test_whenExpectedOwnerIsZero() public
    {
        ObjectType registerableType = toObjectType(randomNumber(type(uint8).max));

        RegisterableMock registerable = new RegisterableMock(
            address(registry),
            toNftId(randomNumber(type(uint96).max)), // parentNftId
            registerableType,
            toBool(randomNumber(1)), // isInterceptor
            registerableOwner, // initialOwner
            ""
        );

        vm.expectRevert(abi.encodeWithSelector(
            IRegistryService.NotRegisterableOwner.selector,
            address(0)));

        registryServiceHarness.exposed_getAndVerifyContractInfo(
            registerable,
            registerableType,
            address(0)); // expectedOwner
    }

    function test_withZeroRegisterableOwner() public
    {
        ObjectType registerableType = toObjectType(randomNumber(type(uint8).max));

        RegisterableMock registerable = new RegisterableMock(
            address(registry),
            toNftId(randomNumber(type(uint96).max)), // parentNftId
            registerableType,
            toBool(randomNumber(1)), // isInterceptor
            address(0), // initialOwner
            ""
        );

        vm.expectRevert(abi.encodeWithSelector(
            IRegistryService.NotRegisterableOwner.selector,
            registerableOwner));

        registryServiceHarness.exposed_getAndVerifyContractInfo(
            registerable,
            registerableType,
            registerableOwner); 
    }

    function test_withZeroRegisterableOwnerAndZeroExpectedOwner() public
    {
        ObjectType registerableType = toObjectType(randomNumber(type(uint8).max));

        RegisterableMock registerable = new RegisterableMock(
            address(registry),
            toNftId(randomNumber(type(uint96).max)), // parentNftId
            registerableType,
            toBool(randomNumber(1)), // isInterceptor
            address(0), // initialOwner
            ""
        );

        vm.expectRevert(abi.encodeWithSelector(
            IRegistryService.RegisterableOwnerIsZero.selector));

        registryServiceHarness.exposed_getAndVerifyContractInfo(
            registerable,
            registerableType,
            address(0)); // expectedOwner
    }

    function test_withRegisteredRegisterableOwner() public
    {
        ObjectType registerableType = toObjectType(randomNumber(type(uint8).max));
        
        RegisterableMock registerable = new RegisterableMock(
            address(registry),
            toNftId(randomNumber(type(uint96).max)), // parentNftId
            registerableType,
            toBool(randomNumber(1)), // isInterceptor
            address(registry), // initialOwner
            ""
        );

        vm.expectRevert(abi.encodeWithSelector(
            IRegistryService.RegisterableOwnerIsRegistered.selector));

        registryServiceHarness.exposed_getAndVerifyContractInfo(
            registerable,
            registerableType,
            address(registry)); // expectedOwner 
    }

    function test_withSelfOwnedRegisterable() public
    {
        ObjectType registerableType = toObjectType(randomNumber(type(uint8).max));
        
        SelfOwnedRegisterableMock selfOwnedRegisterable = new SelfOwnedRegisterableMock(
            address(registry),
            toNftId(randomNumber(type(uint96).max)), // parentNftId
            registerableType,
            toBool(randomNumber(1)), // isInterceptor
            ""
        );     

        vm.expectRevert(abi.encodeWithSelector(
            IRegistryService.SelfRegistration.selector)); 

        registryServiceHarness.exposed_getAndVerifyContractInfo(
            selfOwnedRegisterable,
            registerableType,
            address(selfOwnedRegisterable)); // expectedOwner
    }
}