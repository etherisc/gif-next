// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { FoundryRandom } from "foundry-random/FoundryRandom.sol";

import {Vm, console} from "../../lib/forge-std/src/Test.sol";
import {NftId, NftIdLib} from "../../contracts/type/NftId.sol";
import {ObjectType, ObjectTypeLib, COMPONENT, DISTRIBUTION, POOL, ORACLE} from "../../contracts/type/ObjectType.sol";

import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {RegistryService} from "../../contracts/registry/RegistryService.sol";
import {IRegistryService} from "../../contracts/registry/RegistryService.sol";
import {RegistryServiceHarnessTestBase} from "./RegistryServiceHarnessTestBase.sol";

import {RegisterableMock,
        SelfOwnedRegisterableMock,
        RegisterableMockWithInvalidAddress} from "../mock/RegisterableMock.sol";

// !!! TODO add info.release check tests
contract GetAndVerifyContractInfoTest is RegistryServiceHarnessTestBase {

    function test_withValidRegisterableHappyCase() public
    {
        ObjectType registerableType = ObjectTypeLib.toObjectType(randomNumber(type(uint8).max));
        NftId parentNftId = NftIdLib.toNftId(randomNumber(type(uint96).max));
        
        RegisterableMock registerable = new RegisterableMock(
            NftIdLib.toNftId(randomNumber(type(uint96).max)), // nftId
            parentNftId,
            registerableType,
            toBool(randomNumber(1)), // isInterceptor
            registerableOwner,
            ""
        );

        (
            IRegistry.ObjectInfo memory info,
            address owner,
            bytes memory data
        ) = registryServiceHarness.exposed_getAndVerifyContractInfo(
                registerable,
                parentNftId,
                registerableType,
                registerableOwner);

        assertTrue(eqObjectInfo(info, registerable.getInitialInfo()), "Info returned by getAndVerifyContractInfo() is different from info stored in registerable");
        assertEq(owner, registerable.getOwner(), "Owner returned by getAndVerifyContractInfo() is different from owner stored in registerable");
        assertTrue(eqBytes(data, registerable.getInitialData()), "Data returned by getAndVerifyContractInfo() is different from data stored in registerable");
    } 

    function test_withInvalidRegisterableAddress() public 
    {
        ObjectType registerableType = ObjectTypeLib.toObjectType(randomNumber(type(uint8).max));
        NftId parentNftId = NftIdLib.toNftId(randomNumber(type(uint96).max));

        RegisterableMockWithInvalidAddress registerable = new RegisterableMockWithInvalidAddress(
            NftIdLib.toNftId(randomNumber(type(uint96).max)), // nftId
            parentNftId,
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

        registryServiceHarness.exposed_getAndVerifyContractInfo(
                registerable,
                parentNftId,
                registerableType,
                registerableOwner);
    }

    function test_withRegisterableParentDifferentFromExpectedParent() public
    {
        ObjectType registerableType = ObjectTypeLib.toObjectType(randomNumber(type(uint8).max));
        NftId parentNftId = NftIdLib.toNftId(randomNumber(type(uint96).max));
        NftId expectedParentNftId = NftIdLib.toNftId(randomNumber(type(uint96).max));

        if(parentNftId == expectedParentNftId) {
            expectedParentNftId = NftIdLib.toNftId(expectedParentNftId.toInt() + 1);
        }

        RegisterableMock registerable = new RegisterableMock(
            NftIdLib.toNftId(randomNumber(type(uint96).max)), // nftId
            parentNftId,
            registerableType,
            toBool(randomNumber(1)), // isInterceptor
            registerableOwner, 
            ""
        );

        vm.expectRevert(abi.encodeWithSelector(
            IRegistryService.ErrorRegistryServiceRegisterableParentInvalid.selector,
            address(registerable),
            expectedParentNftId,
            parentNftId));

        registryServiceHarness.exposed_getAndVerifyContractInfo(
            registerable,
            expectedParentNftId,
            registerableType,
            registerableOwner);
    }

    function test_withZeroRegisterableParent() public
    {
        ObjectType registerableType = ObjectTypeLib.toObjectType(randomNumber(type(uint8).max));
        NftId parentNftId = NftIdLib.zero();
        NftId expectedParentNftId = NftIdLib.toNftId(randomNumber(1, type(uint96).max));

        RegisterableMock registerable = new RegisterableMock(
            NftIdLib.toNftId(randomNumber(type(uint96).max)), // nftId
            parentNftId,
            registerableType,
            toBool(randomNumber(1)), // isInterceptor
            registerableOwner, 
            ""
        );

        vm.expectRevert(abi.encodeWithSelector(
            IRegistryService.ErrorRegistryServiceRegisterableParentInvalid.selector,
            address(registerable),
            expectedParentNftId,
            parentNftId));

        registryServiceHarness.exposed_getAndVerifyContractInfo(
            registerable,
            expectedParentNftId,
            registerableType,
            registerableOwner);
    }

    function test_whenExpectedParentIsZeroHappyCase() public
    {
        ObjectType registerableType = ObjectTypeLib.toObjectType(randomNumber(type(uint8).max));
        NftId parentNftId = NftIdLib.toNftId(randomNumber(1, type(uint96).max));
        NftId expectedParentNftId = NftIdLib.zero();

        RegisterableMock registerable = new RegisterableMock(
            NftIdLib.toNftId(randomNumber(type(uint96).max)), // nftId
            parentNftId,
            registerableType,
            toBool(randomNumber(1)), // isInterceptor
            registerableOwner, 
            ""
        );

        registryServiceHarness.exposed_getAndVerifyContractInfo(
            registerable,
            expectedParentNftId,
            registerableType,
            registerableOwner);
    }

    function test_withZeroRegisterableAndZeroExpectedParentHappyCase() public
    {
        ObjectType registerableType = ObjectTypeLib.toObjectType(randomNumber(type(uint8).max));
        NftId parentNftId = NftIdLib.zero();
        NftId expectedParentNftId = NftIdLib.zero();

        RegisterableMock registerable = new RegisterableMock(
            NftIdLib.toNftId(randomNumber(type(uint96).max)), // nftId
            parentNftId,
            registerableType,
            toBool(randomNumber(1)), // isInterceptor
            registerableOwner, 
            ""
        );

        registryServiceHarness.exposed_getAndVerifyContractInfo(
            registerable,
            expectedParentNftId,
            registerableType,
            registerableOwner);
    }

    function test_withRegisterableTypeDifferentFromExpectedType() public 
    {
        ObjectType registerableType = ObjectTypeLib.toObjectType(randomNumber(type(uint8).max));
        ObjectType expectedType = ObjectTypeLib.toObjectType(randomNumber(type(uint8).max));
        NftId parentNftId = NftIdLib.toNftId(randomNumber(type(uint96).max));

        if(registerableType == expectedType) {
            expectedType = ObjectTypeLib.toObjectType(expectedType.toInt() + 1);
        }

        RegisterableMock registerable = new RegisterableMock(
            NftIdLib.toNftId(randomNumber(type(uint96).max)), // nftId
            parentNftId,
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
            parentNftId,
            expectedType,
            registerableOwner);
    }

    function test_withZeroRegisterableType() public
    {
        ObjectType registerableType = ObjectTypeLib.zero();
        ObjectType expectedType = ObjectTypeLib.toObjectType(randomNumber(type(uint8).max));
        NftId parentNftId = NftIdLib.toNftId(randomNumber(type(uint96).max));

        if(registerableType == expectedType) {
            expectedType = ObjectTypeLib.toObjectType(expectedType.toInt() + 1);
        }

        RegisterableMock registerable = new RegisterableMock(
            NftIdLib.toNftId(randomNumber(type(uint96).max)), // nftId
            parentNftId,
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
            parentNftId,
            expectedType,
            registerableOwner);
    }

    function test_whenExpectedTypeIsZero() public
    {
        ObjectType registerableType = ObjectTypeLib.toObjectType(randomNumber(type(uint8).max));
        ObjectType expectedType = ObjectTypeLib.zero();
        NftId parentNftId = NftIdLib.toNftId(randomNumber(type(uint96).max));

        if(registerableType == expectedType) {
            registerableType = ObjectTypeLib.toObjectType(registerableType.toInt() + 1);
        } 

        RegisterableMock registerable = new RegisterableMock(
            NftIdLib.toNftId(randomNumber(type(uint96).max)), // nftId
            parentNftId,
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
            parentNftId,
            expectedType,
            registerableOwner);       
    }

    function test_withRegisterableTypeDifferentFromExpectedTypeWhenExpectedTypeIsCOMPONENT() public
    {
        ObjectType registerableType = ObjectTypeLib.toObjectType(randomNumber(type(uint8).max));
        ObjectType expectedType = COMPONENT();
        NftId parentNftId = NftIdLib.toNftId(randomNumber(type(uint96).max));

        // registerable is not COMPONENT
        if(registerableType == DISTRIBUTION() || registerableType == POOL() || registerableType == ORACLE()) {
            registerableType = ObjectTypeLib.toObjectType(registerableType.toInt() + 1);
        } 

        RegisterableMock registerable = new RegisterableMock(
            NftIdLib.toNftId(randomNumber(type(uint96).max)), // nftId
            parentNftId,
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
            parentNftId,
            expectedType,
            registerableOwner);       
    }

    function test_whenExpectedTypeIsCOMPONENTHappyCase() public
    {
        // with DISTRIBUTION
        ObjectType registerableType = DISTRIBUTION();
        ObjectType expectedType = COMPONENT();
        NftId parentNftId = NftIdLib.toNftId(randomNumber(type(uint96).max));

        RegisterableMock registerable = new RegisterableMock(
            NftIdLib.toNftId(randomNumber(type(uint96).max)), // nftId
            parentNftId,
            registerableType,
            toBool(randomNumber(1)), // isInterceptor
            registerableOwner, 
            ""
        );

        registryServiceHarness.exposed_getAndVerifyContractInfo(
            registerable,
            parentNftId,
            expectedType,
            registerableOwner);  

        // with POOL
        registerableType = POOL();

        registerable = new RegisterableMock(
            NftIdLib.toNftId(randomNumber(type(uint96).max)), // nftId
            parentNftId,
            registerableType,
            toBool(randomNumber(1)), // isInterceptor
            registerableOwner, 
            ""
        );

        registryServiceHarness.exposed_getAndVerifyContractInfo(
            registerable,
            parentNftId,
            expectedType,
            registerableOwner);

        // with ORACLE
        registerableType = ORACLE();

        registerable = new RegisterableMock(
            NftIdLib.toNftId(randomNumber(type(uint96).max)), // nftId
            parentNftId,
            registerableType,
            toBool(randomNumber(1)), // isInterceptor
            registerableOwner, 
            ""
        );

        registryServiceHarness.exposed_getAndVerifyContractInfo(
            registerable,
            parentNftId,
            expectedType,
            registerableOwner);
    }

    function test_withRegisterableOwnerDifferentFromExpectedOwner() public
    {
        ObjectType registerableType = ObjectTypeLib.toObjectType(randomNumber(type(uint8).max));
        NftId parentNftId = NftIdLib.toNftId(randomNumber(type(uint96).max));

        RegisterableMock registerable = new RegisterableMock(
            NftIdLib.toNftId(randomNumber(type(uint96).max)), // nftId
            parentNftId,
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
            parentNftId,
            registerableType,
            outsider); // expectedOwner
    }

    function test_whenExpectedOwnerIsZeroHappyCase() public
    {
        ObjectType registerableType = ObjectTypeLib.toObjectType(randomNumber(type(uint8).max));
        NftId parentNftId = NftIdLib.toNftId(randomNumber(type(uint96).max));

        RegisterableMock registerable = new RegisterableMock(
            NftIdLib.toNftId(randomNumber(type(uint96).max)), // nftId
            parentNftId,
            registerableType,
            toBool(randomNumber(1)), // isInterceptor
            registerableOwner, // initialOwner
            ""
        );

        registryServiceHarness.exposed_getAndVerifyContractInfo(
            registerable,
            parentNftId,
            registerableType,
            address(0)); // expectedOwner
    }

    function test_withZeroRegisterableOwner() public
    {
        ObjectType registerableType = ObjectTypeLib.toObjectType(randomNumber(type(uint8).max));
        NftId parentNftId = NftIdLib.toNftId(randomNumber(type(uint96).max));

        RegisterableMock registerable = new RegisterableMock(
            NftIdLib.toNftId(randomNumber(type(uint96).max)), // nftId
            parentNftId,
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
            parentNftId,
            registerableType,
            registerableOwner); 
    }

    function test_withZeroRegisterableOwnerAndZeroExpectedOwner() public
    {
        ObjectType registerableType = ObjectTypeLib.toObjectType(randomNumber(type(uint8).max));
        NftId parentNftId = NftIdLib.toNftId(randomNumber(type(uint96).max));

        RegisterableMock registerable = new RegisterableMock(
            NftIdLib.toNftId(randomNumber(type(uint96).max)), // nftId
            parentNftId,
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
            parentNftId,
            registerableType,
            address(0)); // expectedOwner
    }

    function test_withRegisteredRegisterableOwner() public
    {
        ObjectType registerableType = ObjectTypeLib.toObjectType(randomNumber(type(uint8).max));
        NftId parentNftId = NftIdLib.toNftId(randomNumber(type(uint96).max));
        
        RegisterableMock registerable = new RegisterableMock(
            NftIdLib.toNftId(randomNumber(type(uint96).max)), // nftId
            parentNftId,
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
            parentNftId,
            registerableType,
            address(registry)); // expectedOwner 
    }

    function test_withSelfOwnedRegisterable() public
    {
        ObjectType registerableType = ObjectTypeLib.toObjectType(randomNumber(type(uint8).max));
        NftId parentNftId = NftIdLib.toNftId(randomNumber(type(uint96).max));

        SelfOwnedRegisterableMock selfOwnedRegisterable = new SelfOwnedRegisterableMock(
            NftIdLib.toNftId(randomNumber(type(uint96).max)), // nftId
            parentNftId,
            registerableType,
            toBool(randomNumber(1)), // isInterceptor
            ""
        );     

        vm.expectRevert(abi.encodeWithSelector(
            IRegistryService.ErrorRegistryServiceRegisterableSelfRegistration.selector,
            address(selfOwnedRegisterable)));

        registryServiceHarness.exposed_getAndVerifyContractInfo(
            selfOwnedRegisterable,
            parentNftId,
            registerableType,
            address(selfOwnedRegisterable)); // expectedOwner
    }
}