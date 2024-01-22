// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Vm, console} from "../../lib/forge-std/src/Test.sol";
import {NftId, toNftId, zeroNftId} from "../../contracts/types/NftId.sol";
import {ObjectType, toObjectType, ObjectTypeLib} from "../../contracts/types/ObjectType.sol";

import {RegistryServiceHarnessTestBase} from "./RegistryServiceHarnessTestBase.sol";

import {RegisterableMock,
        RegisterableMockWithRandomInvalidAddress} from "../mock/RegisterableMock.sol";


contract GetAndVerifyContractInfo_Fuzz_Test is RegistryServiceHarnessTestBase {

    function testFuzz_withValidRegisterableAddress(
        ObjectType expectedType,
        address expectedOwner, 
        NftId parentNftId,
        ObjectType objectType,
        bool isInterceptor,
        address initialOwner,
        bytes memory data) public 
    {
        RegisterableMock registerable = new RegisterableMock(
            address(registry),
            parentNftId,
            objectType,
            isInterceptor, 
            initialOwner,
            data
        );

        _assert_getAndVerifyContractInfo(registerable, expectedType, expectedOwner);
    }

    function testFuzz_withInvalidRegisterableAddress(
        ObjectType expectedType,
        address expectedOwner, 
        NftId parentNftId,
        ObjectType objectType,
        bool isInterceptor,
        address initialOwner,
        bytes memory data) public 
    {
        RegisterableMockWithRandomInvalidAddress registerable = new RegisterableMockWithRandomInvalidAddress(
            address(registry),
            parentNftId,
            objectType,
            isInterceptor, 
            initialOwner,
            data
        );

        _assert_getAndVerifyContractInfo(registerable, expectedType, expectedOwner);
    }
}