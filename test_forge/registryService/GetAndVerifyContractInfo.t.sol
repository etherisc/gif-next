// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Vm, console} from "../../lib/forge-std/src/Test.sol";
import {VersionLib, Version, VersionPart} from "../../contracts/types/Version.sol";
import {NftId, toNftId, zeroNftId} from "../../contracts/types/NftId.sol";
import {ObjectType, toObjectType, ObjectTypeLib} from "../../contracts/types/ObjectType.sol";

import {IService} from "../../contracts/shared/IService.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {IRegistryService} from "../../contracts/registry/IRegistryService.sol";
import {RegistryService} from "../../contracts/registry/RegistryService.sol";
import {RegistryServiceHarnessTestBase, toBool, eqObjectInfo} from "./RegistryServiceHarnessTestBase.sol";

import {RegisterableMock,
        SelfOwnedRegisterableMock,
        RegisterableMockWithFakeAddress} from "../mock/RegisterableMock.sol";


contract GetAndVerifyContractInfoTest is RegistryServiceHarnessTestBase {

    function test_withValidRegisterable() public
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
        ) = registryServiceHarness.getAndVerifyContractInfo(
                registerable,
                registerableType,
                registerableOwner);

        ( 
            IRegistry.ObjectInfo memory infoFromRegisterable,
            bytes memory dataFromRegisterable
        ) = registerable.getInitialInfo();
        
        assertTrue(eqObjectInfo(infoFromRegistryService, infoFromRegisterable), 
            "Info returned buy registry service is different from info stored in registerable");
        assertEq(dataFromRegistryService, dataFromRegisterable, 
            "Data returned buy registry service is different from data stored in registerable");
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

        registryServiceHarness.getAndVerifyContractInfo(
            registerable,
            expectedType,
            registerableOwner);
    }

    function test_withInvalidRegisterableAddress() public 
    {
        ObjectType registerableType = toObjectType(randomNumber(type(uint8).max));

        RegisterableMockWithFakeAddress registerable = new RegisterableMockWithFakeAddress(
            address(registry),
            toNftId(randomNumber(type(uint96).max)), // parentNftId
            registerableType,
            toBool(randomNumber(1)), // isInterceptor
            registerableOwner,
            "",
            address(uint160(randomNumber(type(uint160).max))) // invalid address, assume collision probability is extremelly low 
        );

        ( 
            IRegistry.ObjectInfo memory infoFromRegistryService,
            bytes memory dataFromRegistryService 
        ) = registryServiceHarness.getAndVerifyContractInfo(
                registerable,
                registerableType,
                registerableOwner);

        ( 
            IRegistry.ObjectInfo memory infoFromRegisterable,
            bytes memory dataFromRegisterable
        ) = registerable.getInitialInfo();

        infoFromRegisterable.objectAddress = address(registerable);
        
        assertTrue(eqObjectInfo(infoFromRegistryService, infoFromRegisterable), 
            "Info returned buy registry service is different from info stored in registerable");
        assertEq(dataFromRegistryService, dataFromRegisterable, 
            "Data returned buy registry service is different from data stored in registerable");
    }

    function test_withRegisterableOwnerDifferentFromExpectedOwner() public
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

        vm.expectRevert(abi.encodeWithSelector(
            IRegistryService.NotRegisterableOwner.selector,
            outsider));

        registryServiceHarness.getAndVerifyContractInfo(
            registerable,
            registerableType,
            outsider); 
    }

    function test_withZeroExpectedOwner() public
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

        vm.expectRevert(abi.encodeWithSelector(
            IRegistryService.NotRegisterableOwner.selector,
            address(0)));

        registryServiceHarness.getAndVerifyContractInfo(
            registerable,
            registerableType,
            address(0)); 
    }

    function test_withZeroRegisterableOwner() public
    {
        ObjectType registerableType = toObjectType(randomNumber(type(uint8).max));

        RegisterableMock registerable = new RegisterableMock(
            address(registry),
            toNftId(randomNumber(type(uint96).max)), // parentNftId
            registerableType,
            toBool(randomNumber(1)), // isInterceptor
            address(0),
            ""
        );

        vm.expectRevert(abi.encodeWithSelector(
            IRegistryService.NotRegisterableOwner.selector,
            registerableOwner));

        registryServiceHarness.getAndVerifyContractInfo(
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
            address(0),
            ""
        );

        vm.expectRevert(abi.encodeWithSelector(
            IRegistryService.RegisterableOwnerIsZero.selector));

        registryServiceHarness.getAndVerifyContractInfo(
            registerable,
            registerableType,
            address(0)); 
    }

    function test_withRegisteredRegisterableOwner() public
    {
        ObjectType registerableType = toObjectType(randomNumber(type(uint8).max));
        
        RegisterableMock registerable = new RegisterableMock(
            address(registry),
            toNftId(randomNumber(type(uint96).max)), // parentNftId
            registerableType,
            toBool(randomNumber(1)), // isInterceptor
            address(registry),
            ""
        );

        vm.expectRevert(abi.encodeWithSelector(
            IRegistryService.RegisterableOwnerIsRegistered.selector));

        registryServiceHarness.getAndVerifyContractInfo(
            registerable,
            registerableType,
            address(registry));  
    }

    function test_withSelfOwnedRegisterable() public
    {
        ObjectType registerableType = toObjectType(randomNumber(type(uint8).max));
        
        SelfOwnedRegisterableMock registerable = new SelfOwnedRegisterableMock(
            address(registry),
            toNftId(randomNumber(type(uint96).max)), // parentNftId
            registerableType,
            toBool(randomNumber(1)), // isInterceptor
            ""
        );     

        vm.expectRevert(abi.encodeWithSelector(
            IRegistryService.SelfRegistration.selector)); 

        registryServiceHarness.getAndVerifyContractInfo(
            registerable,
            registerableType,
            address(registerable)); 
    }
}