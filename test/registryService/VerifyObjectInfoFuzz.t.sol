// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Vm, console} from "../../lib/forge-std/src/Test.sol";
import {NftId} from "../../contracts/type/NftId.sol";
import {ObjectType, ObjectTypeLib} from "../../contracts/type/ObjectType.sol";

import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {RegistryServiceHarnessTestBase} from "./RegistryServiceHarnessTestBase.sol";
import {RegisterableMock} from "../mock/RegisterableMock.sol";


contract VerifyObjectInfo_Fuzz_Test is RegistryServiceHarnessTestBase {

    function testFuzz_withValidObjectAddress(
        ObjectType expectedType,
        NftId nftId,
        NftId parentNftId,
        ObjectType objectType,
        bool isInterceptor,
        address initialOwner,
        bytes memory data) public 
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId, 
            parentNftId,
            objectType,
            isInterceptor, 
            address(0), // objectAddress
            initialOwner,
            data
        );

        _assert_verifyObjectInfo(info, expectedType);
    }

    function testFuzz_withAllRandomArguments(
        ObjectType expectedType,
        NftId nftId,
        NftId parentNftId,
        ObjectType objectType,
        bool isInterceptor,
        address objectAddress,
        address initialOwner,
        bytes memory data) public 
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId, 
            parentNftId,
            objectType,
            isInterceptor, 
            objectAddress,
            initialOwner,
            data
        );

        _assert_verifyObjectInfo(info, expectedType);
    }
}