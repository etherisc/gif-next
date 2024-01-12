// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Vm, console} from "../../lib/forge-std/src/Test.sol";
import {VersionLib, Version, VersionPart} from "../../contracts/types/Version.sol";
import {NftId, toNftId, zeroNftId} from "../../contracts/types/NftId.sol";
import {ObjectType, toObjectType, ObjectTypeLib, zeroObjectType, SERVICE, INSTANCE} from "../../contracts/types/ObjectType.sol";

import {IService} from "../../contracts/shared/IService.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {IRegistryService} from "../../contracts/registry/IRegistryService.sol";
import {RegistryService} from "../../contracts/registry/RegistryService.sol";
import {RegistryServiceHarnessTestBase, toBool, eqObjectInfo} from "./RegistryServiceHarnessTestBase.sol";

import {RegisterableMock, RegisterableMockWithFakeAddress} from "../mock/RegisterableMock.sol";


contract GetAndVerifyContractInfo_Fuzz_Test is RegistryServiceHarnessTestBase {

    function testFuzz_getAndVerifyContractInfo(
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
}