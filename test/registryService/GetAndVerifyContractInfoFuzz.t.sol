// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Vm, console} from "../../lib/forge-std/src/Test.sol";
import {NftId, toNftId, zeroNftId} from "../../contracts/type/NftId.sol";
import {ObjectType, toObjectType, ObjectTypeLib} from "../../contracts/type/ObjectType.sol";

import {RegistryServiceHarnessTestBase} from "./RegistryServiceHarnessTestBase.sol";

import {RegisterableMock,
        RegisterableMockWithInvalidAddress} from "../mock/RegisterableMock.sol";


contract GetAndVerifyContractInfo_Fuzz_Test is RegistryServiceHarnessTestBase {

    function testFuzz_withValidRegisterableAddress(
        ObjectType expectedType,
        address expectedOwner,
        NftId nftId, 
        NftId parentNftId,
        ObjectType objectType,
        bool isInterceptor,
        address initialOwner,
        bytes memory data) public 
    {
        RegisterableMock registerable = new RegisterableMock(
            nftId,
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
        NftId nftId,
        NftId parentNftId,
        ObjectType objectType,
        bool isInterceptor,
        address objectAddress,
        address initialOwner,
        bytes memory data) public 
    {
        RegisterableMockWithInvalidAddress registerable = new RegisterableMockWithInvalidAddress(
            nftId,
            parentNftId,
            objectType,
            isInterceptor,
            objectAddress,
            initialOwner,
            data
        );

        _assert_getAndVerifyContractInfo(registerable, expectedType, expectedOwner);
    }
}